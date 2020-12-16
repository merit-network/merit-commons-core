package MeritCommons;

#    MeritCommons Portal
#    Copyright 2013-2017 Wayne State University
#    All Rights Reserved

# "Rarely is the question asked: Is our children learning?" George W. Bush 
#                                                           43rd President of the United States

# This library is free software; you can redistribute it and/or modify it under the same terms 
# as Perl itself, either Perl version 5.28 or, at your option, any later version of Perl 5 you 
# may have available.  See doc/markdown/license.md for the current full text.

# Make sure we're using the version of MeritCommons System required for this build.
use MeritCommons::System 3.0;

use feature 'state';
use utf8;

use Carp qw/shortmess longmess/;
push(@MeritCommons::CARP_NOT, "__PACKAGE__", qw/
    Mojolicious     Mojolicious::Controller     MeritCommons::Hydrant 
/);

use Mojo::Loader qw(load_class);
use Mojo::Base 'Mojolicious';
use Mojo::Cache;
use Mojo::URL;
use Mojo::JSON qw(decode_json);
use Mojo::Home;
use Mojo::UserAgent;
use Mojo::IOLoop;
use Mojo::EventEmitter;
use Mojo::Pg;
use Mojo::File;
use Cwd qw(abs_path);

# DBIx::Class::Schema
use MeritCommons::Model;

# Base class for content ingestion
use MeritCommons::ContentDriver;
use MeritCommons::Util;
use MeritCommons::Infra::FlockVPN;
use MeritCommons::Daemons;
use MeritCommons::Routes;

use Fcntl;
use POSIX qw(mkfifo nice :sys_wait_h);
use File::Find;                  # for production build.
use File::Path qw(make_path);    # for the production build, too!
use Scalar::Util qw(weaken);
use Date::Format;

use Unix::Uptime;
use Socket;
use IO::Handle;

use DBI;
use Sphinx::Search;
use ZMQ::LibZMQ3;
use ZMQ::Constants qw(:all);
use IO::Compress::Gzip qw(gzip);
use Log::Syslog::Fast qw(:all);

use Cache::Memcached::Fast;

# we're a Mojo::EventEmitter now, too
push(@MeritCommons::ISA, "Mojo::EventEmitter");

# 0.2 = Kirby
# 0.3 = Ferry
# 0.4 = Palmer
# 0.5 = Merrick
# 0.6 = Putnam
# 0.7 = Wayne
# 0.8 = Lodge
# 0.9 = Cass
# 1.0 = Woodward

our $VERSION  = 1.01;
our $CODENAME = 'Woodward';
our $RELEASE  = 'trunk';

BEGIN: {

    # start by fixing Text::Balanced exception handling
    require Text::Balanced;
    require overload;

    local $@;

    # this is what poisons $@
    Text::Balanced::extract_bracketed('(foo', '()');

    if ($@ and overload::Overloaded($@) and !overload::Method($@, 'fallback')) {
        my $class = ref $@;
        eval "package $class; overload->import(fallback => 1);";
    }

    # optional module(s) here, skipped if not present
    eval { require Bloomd::Client; };

    # We're going to monkey patch this library, so we need it here.
    require Mojo::Util;
    require Mojolicious::Validator::Validation;
    require Fcntl;

    no strict 'refs';
    no warnings;

    #
    # Monkey Patch Justification: return even if inputs are empty
    #

    Mojo::Util::monkey_patch(
        'Mojolicious::Validator::Validation',
        optional => sub {
            my ($self, $name, @filters) = @_;

            return $self->topic($name) unless defined(my $input = $self->input->{$name});

            my @input = ref $input eq 'ARRAY' ? @$input : ($input);
            for my $cb (map { $self->validator->filters->{$_} } @filters) {
                @input = map { $self->$cb($name, $_) } @input;
            }

            $self->output->{$name} = ref $input eq 'ARRAY' ? \@input : @input > 1 ? \@input : $input[0]
              unless grep { !length } @input;

            return $self->topic($name);
        },
    );

    # while we're here, MERITCOMMONS_DEBUG being on turns on debug logging too...
    if ($ENV{MERITCOMMONS_DEBUG}) {
        $ENV{MOJO_LOG_LEVEL} = "debug";
    }
}

# path to the FIFO used to write to the ZeroMQ publisher "meritcommons_publisher"
our $publisher_fifo_path;

# path to the FIFO used to write notifications to users' inboxes via "meritcommons_notifier".
our $notifier_fifo_path;

# scalars used to store compiled javascript and css (not sure why they're scoped class-wide but okay)
our $built_js;
our $built_css;

# the PID our publisher is running as
our $publisher_pid;

# the PID our notifier is running as
our $notifier_pid;

# the PID our system_agent is running as
our $system_agent_pid;

# keep track of if this is a command or a main
our $is_manager_process;

# use this so that we only kill daemons once in the event that there are multiple MeritCommons app objects in play
our $daemons_shut_down;

# used to load content drivers meta data
our $cd_data = {};

# these class variables keep track of the publishers' addresses
our $publishers;    # URLs subscribers should subscribe to
our $publish_to;    # URLs publishers should publish to

# db is postgres?  we're going to be adding some postgres-specific features in the future, and we already check anyway.
our $db_is_postgres;

# what config file should we use (notice, it's overridable)
our $config_file = "etc/meritcommons.conf";

# are we gonna share a zmq context per process?  if we wanted to do such a thing we can put it here.
our $zmq_shared_context;

# because we can never close() the ZMQ_FD handles, we must keep a reference to them somewhere to keep Perl's garbage
# collector from close()ing them.  this is our bucket for such handles.
our $dead_zmq_handles = [];

# allow plugins to register Hydrant commands, too
our $hydrant_namespaces = [];

# allow plugins to register Content Drivers
our $contentdriver_namespaces = [];

# allow plugins to contain markdown documentation path => file
our $markdown_files = {};

# keep track of meritcommons plugins we've loaded
our $loaded_plugins = [];

# asset_base, the baseURL of our assets
our $asset_base;

# This method will run once at server start
sub startup {
    my $self = shift;

    #
    #
    # EARLY INITIALIZATION
    #
    #

    # identify MERITCOMMONS_HOME and set accordingly.
    my $home = Mojo::Home->new;
    $home->detect('MeritCommons');
    $ENV{MERITCOMMONS_HOME} = $home->rel_file('/');

    # add in our commands namespace.
    push @{ $self->commands->namespaces }, 'MeritCommons::Command';

    # add in our plugins namespace(s).
    push @{ $self->plugins->namespaces }, 'MeritCommons::Helper';

    # Configuration Hashref
    my $config = $self->plugin('MeritCommons::Config', { file => $config_file });

    # global config, for consistency with meritcommons plugins.  call this always if you want
    # the global config
    $self->helper(
        global_config => sub {
            return $config;
        }
    );

    #
    # This is used for registering deprecated helpers, wraps the subroutine call in a warning
    # either via STDERR, error log, or both (depending on MERITCOMMONS_DEBUG).  Added early so pretty
    # much any helper can be marked 'deprecated' except 'global_config'.
    #

    $self->helper(
        deprecated_helper => sub {
            my ($c, $name, $subref, $suggested_alternative, $deprecation_reason) = @_;
            my $app = $c->app;
            $app->helper($name => sub {
                my $warning = "Helper '\$c->$name' has been deprecated ";
                if ($suggested_alternative) {
                    $warning .= "in favor of '$suggested_alternative' ";
                }
                
                $warning .= "and is slated to be removed in a future release";
                
                my $sm = shortmess();
                chomp($sm);
                $warning .= $sm;
                
                # append these if we've fot em, otherwise what we have above is it.
                if ($deprecation_reason) {
                    $warning .= " -- $deprecation_reason";
                }
                
                # log (and conditionally print to STDERR) our warning
                $_[0]->app->log->warn($warning);
                if ($ENV{MERITCOMMONS_DEBUG}) {
                    warn "[debug/deprecated_helper_called] $warning\n";
                }
                
                # call the actual helper.
                $subref->(@_);
            });
        }
    );

    #
    # See if we're a flock config, and if we are load and merge the config...
    #
    my $deployment_profile = $config->{deployment_profile} // ($self->mode eq 'development' ? 'development.idp' : 'standard.idp');
    my ($deployment_type, $service_role) = split(/\./, $deployment_profile);

    print "[info] rolling with Deployment Profile '$deployment_profile':\n" if $ENV{MERITCOMMONS_DEBUG};

    my $deployment_config;
    if (-e "$ENV{MERITCOMMONS_HOME}/etc/$deployment_type.conf") {
        if (my $deployment_config = $self->plugin('MeritCommons::Config', { file => "etc/$deployment_type.conf", just_parse => 1 })) {
            # merge it in ...
            my ($clobbered, $added) = (0, 0); 
            foreach my $key (keys %$deployment_config) {
                if (exists ($config->{$key})) {
                    $config->{$key} = $deployment_config->{$key};
                    $clobbered++;
                } else { 
                    $config->{$key} = $deployment_config->{$key};
                    $added++;
                }
            }
            if ($ENV{MERITCOMMONS_DEBUG}) {
                print "[debug] config augmentation for Deployment Profile '$deployment_profile': $added options added; $clobbered options clobbered\n";
            }
            
            # why not a helper for this too?!
            $self->helper(
                'deployment_config' => sub {
                    return $deployment_config;
                }
            );
        }
    } else {
        unless ($deployment_type eq "testing") {
            print "[debug] no special config found for '$deployment_type', should you make '$ENV{MERITCOMMONS_HOME}/etc/$deployment_type.conf'?\n" if $ENV{MERITCOMMONS_DEBUG};
        }
    }

    $self->helper(
        'deployment_type' => sub {
            return $deployment_type;
        }
    );

    if ($service_role eq "idp") {
        print "[debug] IdP Role Detected - I just wanted to tell you both good luck, we're all counting on you.\n" if $ENV{MERITCOMMONS_DEBUG};
    } else {
        print "[debug] a lowly $service_role, well you gotta start somewhere.\n" if $ENV{MERITCOMMONS_DEBUG};
    }

    $self->helper(
        'service_role' => sub {
             return $service_role;
        }
    );

    # pacify Mojolicious internal message.
    $self->secrets(

        # first consult the configuration file
        $config->{cookie_secrets} //

          # if not defined in config, use this one.
          [
            "JyhBFqq8c3ZXEB5JiCXngbfTS6fpiV0gvagcMYqRdqGru3nOUatgp41jtuT0t1CZScyRjfvKBKovLwGGv8gpYHXzusX7kwp5KbCcG1FLpWAht9EuaeIRMJH3pSidzd7T"
          ]
    );

    # set log level to info if we are debugging inbound.
    if ($config->{inbound_debug}) {
        $ENV{MOJO_LOG_LEVEL} = 'info' unless $ENV{MOJO_LOG_LEVEL} && $ENV{MOJO_LOG_LEVEL} eq 'debug';
    }

    # Allow for log-level override. (ignored and set to 'default' if MERITCOMMONS_DEBUG is true)
    if (my $log_level = $config->{application_log_level}) {
        $self->log->level($log_level);
    }

    # define the version_banner helper, which might be used by plugins or other helpers.
    $self->helper(
        'version_banner' => sub {
            my ($self) = @_;
            my $debug_text = '';
            if ($ENV{MERITCOMMONS_DEBUG}) {
                $debug_text .= "; Debugging Enabled";
            }
            if ($ENV{BRUTAL_MORBO}) {
                $debug_text .= "; All PIDs are vermin in the eyes of Morbo.";
            }
            if ($ENV{MERITCOMMONS_NO_PLUGINS}) {
                $debug_text .= "; Plugins Disabled";
            }

            my $release_text = '';
            if ($RELEASE && $RELEASE ne 'trunk' && $RELEASE ne 'master') {
                $release_text = "Release $RELEASE ";
            } else {
                $release_text = "Master Branch ";
            }

            my $mode_text = ucfirst($self->app->mode);

            return "MeritCommons $release_text($MeritCommons::CODENAME) v$MeritCommons::VERSION; Deployment $deployment_profile; $mode_text Mode$debug_text";
        }
    );

    # Add our local asset path.
    my $local_asset_path =
      $config->{local_asset_path} ? $config->{local_asset_path} : "$ENV{MERITCOMMONS_HOME}/../var/public";
    push @{ $self->static->paths }, $local_asset_path;
    $ENV{MERITCOMMONS_LOCAL_ASSET_PATH} = $local_asset_path;

    # set up upload_path, and asset_base!
    my $external_asset_path = $config->{external_asset_path};
    my $external_asset_base = $config->{external_asset_base};

    my ($upload_path);
    if ($external_asset_path && $external_asset_base) {
        $asset_base  = $external_asset_base;
        $upload_path = $external_asset_path;
    } else {

        # let the default be overriden for testing...
        $asset_base = $self->url_for($config->{front_door_url})->path('/')->to_string unless $asset_base;
        $upload_path = $local_asset_path;
    }

    $ENV{MERITCOMMONS_UPLOAD_PATH} = $upload_path;
    $ENV{MERITCOMMONS_ASSET_BASE}  = $asset_base;

    my $run_as_uid;
    if (my $run_user = $config->{user}) {
        $run_as_uid = getpwnam($run_user);
        unless (defined $run_as_uid) {
            die "[fatal]: A user is defined in meritcommons.conf, but I can't find a system user by that name.";
        }
    } else {
        $run_as_uid = $<;
    }

    my $run_as_user = getpwuid($run_as_uid);

    # Configure the max message size from config file or 100MB.
    $ENV{MOJO_MAX_MESSAGE_SIZE} = $config->{max_message_size} || 1024 * 102400;

    #
    #
    # LOAD PLUGIN CLASSES (but don't initialize them yet)
    #
    #

    # also load the plugins configuration info...
    my $plugins_config = {};
    my $plugins_config_file = abs_path("$ENV{MERITCOMMONS_HOME}/../var/plugins/plugins.conf") ||
      "$ENV{MERITCOMMONS_HOME}/../var/plugins/plugins.conf";

    if (-e $plugins_config_file) {
        $plugins_config = $self->plugin('MeritCommons::Config', { file => $plugins_config_file, just_parse => 1 });

        # this doesn't happen if we're supposed to disable plugins
        unless ($ENV{MERITCOMMONS_NO_PLUGINS}) {

            # see what our schema version should be...
            if (ref $plugins_config->{schemas_deployed} eq "ARRAY") {
                my $last_deployment =
                  $plugins_config->{schemas_deployed}->[ $#{ $plugins_config->{schemas_deployed} } ];

                if (ref $plugins_config->{enabled} eq "ARRAY") {

                    # assuming we're going to be modifying this, doesn't hurt to load it..
                    require MeritCommons::Model;

                    # scan the enableds..
                    my $model_version = $MeritCommons::Model::VERSION;

                    my $ldp_scp = 0;
                    if ($last_deployment && $model_version < $last_deployment->{version}) {
                        $model_version = $last_deployment->{version};
                        foreach my $pl (keys %{ $last_deployment->{plugins} }) {
                            ++$ldp_scp if $last_deployment->{plugins}->{$pl}->{schema_version};
                        }
                    }

                    my $schema_changing_plugins = 0;
                    my $loaded_last_time        = 0;
                    my $core_changed            = 0;

                    foreach my $plugin (@{ $plugins_config->{enabled} }) {
                        my ($plugin_version, $schema_version);
                        if (my $exception = load_class $plugin) {
                            die "[fatal] error loading MeritCommons Plugin '$plugin': $exception $@\n";
                            exit;
                        } else {
                            no strict 'refs';
                            $plugin_version = ${"${plugin}::VERSION"};
                            $schema_version = ${"${plugin}::SCHEMA_VERSION"};
                            use strict 'refs';
                        }

                        if ($schema_version) {

                            # bump it up by one if it's a core schema
                            if ($model_version == $MeritCommons::Model::VERSION) {
                                $model_version += 1;
                                $core_changed = 1;
                                print
                                  "[info] core schema changed, please run prepare_schema_upgrade and upgrade_schema!\n"
                                  if $ENV{MERITCOMMONS_DEBUG};
                            }
                            ++$schema_changing_plugins;
                        }

                        my $ldp = $last_deployment->{plugins}->{$plugin};

                        if ($schema_version && $ldp && $ldp->{schema_version} == $schema_version) {
                            print "[info] $plugin\'s schema is the same as what's listed in the last deployment\n"
                              if $ENV{MERITCOMMONS_DEBUG};
                            ++$loaded_last_time;
                        } elsif (!$schema_version) {
                            print "[info] $plugin has no \$SCHEMA_VERSION, assuming no schema\n"
                              if $ENV{MERITCOMMONS_DEBUG};
                        } elsif ($ldp && $schema_version != $ldp->{schema_version}) {
                            print
                              "[info] $plugin\'s schema changed, please run prepare_schema_upgrade and upgrade_schema!\n"
                              if $ENV{MERITCOMMONS_DEBUG};
                            $model_version += 1;
                        } else {
                            print "[info] $plugin appears to be a newly enabled plugin\n" if $ENV{MERITCOMMONS_DEBUG};
                        }
                    }

                    # no matter what, if there are more or less schema changing plugins than there are now, we have to increment the version.
                    if ($ldp_scp && ($schema_changing_plugins != $ldp_scp)) {
                        #
                        # $loaded_last_time == the number of plugins loaded last time that have the same version of their schema this time
                        # $ldp_scp == plugins present at the last deployment that made schema changes
                        # $schema_changing_plugins == the number of plugins that change schema present this time
                        #
                        $model_version++;
                    }

                    print "[info] setting global Model version to $model_version\n" if $ENV{MERITCOMMONS_DEBUG};
                    $MeritCommons::Model::VERSION = $model_version;
                }
            }
        }
    }

    #
    #
    # INIT MODEL
    #
    #

    my $model;

    # Model + "m" helper!  The model is now available app wide!
    eval { $model = MeritCommons::Model->connect(@{ $config->{database_connect_info}->{primary} }); };

    if (my $error = $@) {
        warn "[very very bad]: could not connect to the database, launching against my better judgement; error: $error\n";
    }

    # now set up the replica.
    my $replica;
    if (my $replicas = $config->{database_connect_info}->{replicas}) {
        $replica = MeritCommons::Model->clone;
        $replica->storage_type([ '::DBI::Replicated', { balancer_type => '::Random' } ]);
        $replica->connection(@{ $replicas->[0] });
        $replica->storage->connect_replicants(@$replicas);
    }

    my ($ql, $rql);
    if ($ENV{MERITCOMMONS_DEBUG}) {
        require DBIx::Class::QueryLog;
        require DBIx::Class::QueryLog::Analyzer;
        $ql = DBIx::Class::QueryLog->new();
        $model->storage->debugobj($ql);
        $model->storage->debug(1);

        if ($replica) {
            $rql = DBIx::Class::QueryLog->new();
            $replica->storage->debugobj($rql);
            $replica->storage->debug(1);
        }
    }

    # making these nonfatal so we can run database maintenence commands
    eval {
        # if we're SQLite, let's do some tuning.
        if ($model->storage->dbh->{Driver}->{Name} eq "SQLite") {
            $model->storage->dbh->do("PRAGMA synchronous = OFF"); # async database writes, corruption prone w/o safe shutdown.
            $model->storage->dbh->do("PRAGMA cache_size = 100000");    # 100MB of cache
        }
    };

    # If we're Postgres, let's do some tuning.  pg_server_prepare doesn't allow for parameter values to factored into
    # the explain plan.  We'll disable it since it hinders performance when filtering on messages/streams, and since it
    # isn't otherwise providing us any apparent value.
    eval {
        if ($model->storage->dbh->{Driver}->{Name} eq "Pg") {
            $model->storage->dbh_do(
                sub {
                    my (undef, $dbh) = @_;
                    $dbh->{pg_server_prepare} = 0;
                }
            );
            $db_is_postgres = 1;
        }
    };

    # enhanced database handles for async access to PostgreSQL
    my $mojo_pg = Mojo::Pg->new(_db_config_to_url($config->{database_connect_info}->{primary}));
    my @mojo_pg_replicas =
      map { Mojo::Pg->new(_db_config_to_url($_)) } @{ $config->{database_connect_info}->{replicas} };

    # get the async handle as well
    my ($async_mojo_pg, $async_mojo_pg_url);

    # Gelato!  Pwede na?  Kanpai!
    if (!$config->{postgres_async_url}) {
        my $async_mojo_pg_url = _db_config_to_url($config->{database_connect_info}->{primary}, 'async');

        if ($ENV{MERITCOMMONS_DEBUG}) {
            warn "[debug] attempting to connect to async db at $async_mojo_pg_url\n";
        }

        # Load up Minion the offline job processor!
        eval {
            $self->plugin('Minion', { Pg => $async_mojo_pg_url });
            $async_mojo_pg = $self->minion->backend->pg;
        };
    } else {
        if ($async_mojo_pg_url = $config->{postgres_async_url}) {
            eval {
                $self->plugin('Minion', { Pg => $async_mojo_pg_url });
                $async_mojo_pg = $self->minion->backend->pg;
            };
        } else {
            unless ($ENV{MERITCOMMONS_TESTING}) {
                warn
                  "[error]: async tasks require use of the PostgreSQL backend; You can still use this RDBMS but you should\n";
                warn
                  "         start and specify a PostgreSQL server using the postgres_url config option.  See the perldoc\n";
                warn "         for Mojo::Pg for format info.\n";
                die "[fatal]: aborting startup\n";
            }
        }
    }

    if ($async_mojo_pg && $self->minion) {
        $async_mojo_pg->migrations->name('async')->from_data;
        $async_mojo_pg->once(connection => sub { shift->migrations->migrate });
    } else {
        unless ($ENV{MERITCOMMONS_TESTING} || ($ENV{MERITCOMMONS_DOCKER} && $> == 0)) {
            warn "[error]: async tasks are not set up correctly; expect weird things.\n";
        }
    }

    #
    # scan and populate base markdown file structure
    #
    my $md_path = "$ENV{MERITCOMMONS_HOME}/doc/markdown";
    
    find(
        sub {
            my $filename = $File::Find::name;
            if ($filename =~ /^\Q$md_path\E(\/.+)\.md$/i) {
                $markdown_files->{"$1/"} = $filename;
            }
        },
        $md_path
    );

    if ($self->mode eq "development" || $config->{show_release_notes}) {
        $md_path = "$ENV{MERITCOMMONS_HOME}/doc/release";
        
        find(
            sub {
                my $filename = $File::Find::name;
                if ($filename =~ /^\Q$md_path\E(\/.+)\.md$/i) {
                    $markdown_files->{"$1/"} = $filename;
                }
            },
            $md_path
        );
    }

    # Model convenience method.
    $self->helper(
        'm' => sub {
            return $model;
        }
    );

    # Replica set convenience method.
    $self->helper(
        'replica' => sub {
            return $replica;
        }
    );

    # Replica-ok model, returns replica if defined, otherwise returns model.
    $self->helper(
        'rorm' => sub {
            return $replica ? $replica : $model;
        }
    );

    #
    #
    # INITIALIZE CORE HELPER MODULES
    #
    #

    unless ($config->{authentication_provider}) {
        die "[warn]: no authentication_provider found in your config!\n";
    }

    # load our authentication method.
    $self->plugin($config->{authentication_provider});

    $self->plugin('CryptUtil');      # cryptographic functions here (SessionUtil will need these)
    $self->plugin('SessionUtil');    # all MeritCommons session functions
    $self->plugin('FileUtil');       # code to handle file uploads
    $self->plugin('MiscUtil');       # important junk drawer (new_uuid, md5_hex, etc)
    $self->plugin('DataUtil');       # some model logic / fusing of various db engines
    $self->plugin('RenderUtil');     # to aid in rendering of things.
    $self->plugin('LinkUtil');       # methods about links
    $self->plugin('SphinxUtil');     # Sphinx search/indexing code
    $self->plugin('MailUtil');       # methods for generating email digests
    $self->plugin('BloomUtil');      # methods for querying and updating bloom filters

    # instance id with in object and local caching.  required by logging functions, so set earlier than
    # other helpers.
    $self->helper(
        instance_id => sub {
            my ($c) = @_;

            # first the ram cache
            my $instance_id = $self->{instance_id};

            unless ($instance_id) {

                # now the file...
                if (open my $fh, '<', '/var/tmp/instance_id') {
                    $instance_id = <$fh>;
                }

                unless ($instance_id) {

                    # otherwise, go get it.
                    if ($c->config->{aws}) {
                        my $ua = Mojo::UserAgent->new();
                        my $tx = $ua->get("http://169.254.169.254/latest/meta-data/instance-id");
                        $instance_id = $tx->res->body;
                    } else {

                        # not on aws?  generate an "instance id" randomly
                        $instance_id = "i-" . $c->crypto->random_hex(17);
                    }

                    # SAVE FOR NEXT TIME.
                    open my $fh, '>', '/var/tmp/instance_id';
                    print $fh $instance_id;
                    close $fh;
                }
            }

            return $instance_id;
        }
    );

    #
    #
    # SET UP LOGGING
    #
    #

    # enable access log if it's configured.
    if ($config->{access_log}) {
        require Mojolicious::Plugin::AccessLog;
        $self->plugin(
            'AccessLog' => {
                log    => $config->{access_log},
                format => $config->{access_log_format} ? $config->{access_log_format} : "common"
            }
        );
    } elsif ($config->{log_to_publisher}) {
        require MeritCommons::ZMQAccessLog;
        $self->plugin(
            'MeritCommons::ZMQAccessLog' => {
                format => $config->{access_log_format} ? $config->{access_log_format} : "common"
            }
        );
    } elsif ($config->{flock_syslog}) {
        require MeritCommons::SyslogAccessLog;
        $self->plugin(
            'MeritCommons::SyslogAccessLog' => {
                format => $config->{access_log_format} ? $config->{access_log_format} : "common"
            }
        );
    }

    if (my $ar = $config->{auth_log_syslog}) {
        my $loggers = [];

        for (my $i = 0 ; $i <= $#{$ar} ; $i++) {

            # get the cached logger or make a new one!
            $loggers->[$i] = Log::Syslog::Fast->new(LOG_UDP, $ar->[$i], 514, LOG_LOCAL1, LOG_NOTICE,
                $config->{front_door_host}, 'auth_log');
        }

        $self->helper(auth_log_syslog => sub { return $loggers });
    }

    if (my $ar = $config->{audit_log_syslog}) {
        my $loggers = [];

        for (my $i = 0 ; $i <= $#{$ar} ; $i++) {

            # get the cached logger or make a new one!
            $loggers->[$i] = Log::Syslog::Fast->new(LOG_UDP, $ar->[$i], 514, LOG_LOCAL2, LOG_NOTICE,
                $config->{front_door_host}, 'audit_log');
        }

        $self->helper(audit_log_syslog => sub { return $loggers });
    }

    # set up error syslogging here, as it requires the instance_id helper be in place.
    if (my $ar = $config->{error_log_syslog}) {
        foreach my $address (@$ar) {

            # get the cached logger or make a new one!
            my $logger = Log::Syslog::Fast->new(LOG_UDP, $address, 514, LOG_LOCAL5, LOG_NOTICE,
                $config->{front_door_host}, 'error_log');
            $self->log->on(
                message => sub {
                    my ($log, $level, @lines) = @_;
                    unless ($ENV{MERITCOMMONS_DEBUG}) {
                        return if $level eq "debug";
                    }
                    if ($logger) {
                        foreach my $line (@lines) {

                            # make this nonfatal!
                            eval { $logger->send("@{[$self ? $self->instance_id : 'unknown']} [$level] $line"); };
                            if (my $error = $@) {
                                warn
                                  "[error] UDP Syslog configured but unreachable!  reason: $error - Tried to log line '$line'\n";
                            }
                        }
                    }
                }
            );
        }
    }

    #
    #
    # CONFIGURE IPC AND CACHING
    #
    #

    # create link to the publisher daemon
    $publisher_fifo_path = '/var/tmp/meritcommons_publisher.fifo';
    mkfifo($publisher_fifo_path, 0700);
    chown($run_as_uid, $(, $publisher_fifo_path);

    # create link to the notifier daemon
    $notifier_fifo_path = '/var/tmp/meritcommons_notifier.fifo';
    mkfifo($notifier_fifo_path, 0700);
    chown($run_as_uid, $(, $notifier_fifo_path);

    my $build_id = "__DEVELOPMENT__";

    # Set up caching! (Mojo::Cache or Cache::Memcached::Fast)
    my $cache;
    if ($config->{memcached_servers}) {
        $cache = Cache::Memcached::Fast->new(
            {
                servers => $config->{memcached_servers},
                compress_threshold => 10_000,
                compress_ratio => 0.8,
                utf8 => 1,
            }
        );
    } else {
        $cache = Mojo::Cache->new(max_keys => 10000);

        # stub.
        unless (defined(&Mojo::Cache::delete)) {
            *Mojo::Cache::delete = sub {
                return Mojo::Cache::set(@_, undef);
            };
        }

        if ($ENV{HYPNOTOAD_REV}) {
            print "[warning] using Mojo::Cache and Hypnotoad will result in STALE CACHED DATA.\n";
            print "          start memcached and specify 'memcached_servers' in meritcommons.conf\n";
            print "          for interprocess cache invalidation.\n";
        }
    }

    my $running_tasks = {};

    #     #
    #     #
    #######
    #     #
    #     # ELPERS

    # initialize publisher buffer arrayref
    $self->{publisher_buffer} = [];

    # is the backend postgresql?
    $self->helper(
        db_is_postgres => sub {
            return $db_is_postgres;
        }
    );

    # Get at the publisher file handle (installed early, because needed in helpers below!)
    $self->helper(
        'pub_write' => sub {
            my ($controller, @lines) = @_;
            if (-p $publisher_fifo_path && sysopen my $fifo, $publisher_fifo_path, O_NONBLOCK | O_WRONLY) {
                print "[pub_write] writing out @{[scalar(@{$self->{publisher_buffer}})]} + @{[scalar(@lines)]} to FIFO\n"
                  if $ENV{MERITCOMMONS_FIFO_DEBUG};
                print $fifo join("\n", @{ $self->{publisher_buffer} }, @lines) . "\n";

                # we weren't clearing the publisher buffer!
                $self->{publisher_buffer} = [];
                close($fifo);
            } else {
                print "[pub_write] FIFO not ready, buffering @{[scalar(@lines)]} message(s).\n" if $ENV{MERITCOMMONS_FIFO_DEBUG};

                # fifo wasn't ready to be written to, let's spool it up.
                push(@{ $self->{publisher_buffer} }, @lines);

                # did the fifo go away?
                if (!-p $publisher_fifo_path) {
                    $self->log(
                        error => "FIFO and publisher have gone away.  To recover, please restart this MeritCommons node.");
                }
            }
        }
    );

    # create a new async task
    $self->helper(
        'add_async_task' => sub {
            my ($controller, $task_name, $subref) = @_;

            # the subroutine is amended to emit the ID when it's done running.
            my $task = sub {
                my ($job, $id, $publisher_fifo_path, @rest) = @_;

                # only write to publisher when it's ready to be written to
                require Time::HiRes;

                my $data;
                eval {
                    # call the task, get the data out.
                    $data = $subref->($job, @rest);
                };

                # short circuit routing the data through postgres for tests
                if ($ENV{MERITCOMMONS_TESTING}) {
                    return $data;
                }

                my $message;
                if (my $error = $@) {
                    $controller->app->log->fatal("error running async_task id $id - $error");

                    $message = "$id async:failed";

                } else {

                    # write the data to the async db.
                    my $pg = $controller->async_mojo_pg;
                    $pg->db->query("insert into meritcommons_async_results (task_id, payload) values (?, ?)" =>
                          ($id, { json => $data }));

                    $message = "$id async:finished";
                }

                my $pub_write_done;
                do {
                    # manually pub_write since we're outside the application in this context (in a minion).
                    if (-p $publisher_fifo_path && sysopen my $fifo, $publisher_fifo_path, O_NONBLOCK | O_WRONLY) {
                        print "[async] sending '$message' to publisher\n" if $ENV{MERITCOMMONS_DEBUG};
                        print $fifo "$message\n";
                        close($fifo);
                        $pub_write_done = 1;
                    } else {

                        # did the fifo go away?
                        if (!-p $publisher_fifo_path) {
                            $self->log(error =>
                                  "FIFO and publisher have gone away, async tasks processed on this host will not notify ZMQ"
                            );
                            $pub_write_done = 1;
                        }
                        warn "[async] FIFO not ready for writes, trying again...\n" if $ENV{MERITCOMMONS_DEBUG};
                        Time::HiRes::sleep(0.1);
                    }
                } until ($pub_write_done);
            };

            eval { $controller->minion->add_task($task_name, $task); };
            my $error = $@;
            if ($error && !($ENV{MERITCOMMONS_DOCKER} && $> == 0)) {
                warn
                  "[error]: error registering task '$task_name', async tasks are not set up correctly, received error '$error'; expect weird things\n";
            }
        }
    );

    # run a new async task (must have been previously "add_"ed)
    $self->helper(
        'run_async_task' => sub {
            my ($controller, $task_name, $callback, $cmd, @args) = @_;

            my $priority = 0;
            if (ref($cmd) eq "HASH") {
                @args     = @{ $cmd->{args} };
                $priority = $cmd->{priority};
                $cmd      = $cmd->{command};
            }

            my $cmd_isa_cmd = UNIVERSAL::can($cmd, 'isa') && $cmd->isa('MeritCommons::Hydrant::Command');

            # make it so the system doesn't try to shut this websocket down.
            $cmd->hydrant->shutdown_protection(1) if $cmd_isa_cmd;

            my $task_id = $controller->new_uuid;

            # register the running task and its callback.
            $controller->running_tasks->{$task_id} = { callback => $callback, };

            $controller->running_tasks->{$task_id}->{cmd} = $cmd if $cmd_isa_cmd;

            # subscribe to it!
            if (!$cmd_isa_cmd || (zmq_setsockopt($cmd->hydrant->zmq_subscriber, ZMQ_SUBSCRIBE, $task_id) == 0)) {
                warn "[async] new $task_name => $task_id\n" if $ENV{MERITCOMMONS_DEBUG};

                if ($ENV{MERITCOMMONS_TESTING}) {

                    # run the task directly if we're in testing mode
                    my $data = $controller->minion->tasks->{$task_name}->($task_id, $publisher_fifo_path, undef, @args);
                    $controller->finish_async_task($task_id, $cmd_isa_cmd ? $cmd->hydrant : undef, $data);
                } else {
                    $controller->minion->enqueue(
                        $task_name => [ $task_id, $publisher_fifo_path, @args ],
                        { priority => $priority }
                    );
                }
            } else {
                warn "Async task failed: unable to subscribe to task_id $task_id\n";
            }
        }
    );

    # an async task has finished!
    $self->helper(
        'finish_async_task' => sub {
            my ($controller, $task_id, $hydrant) = @_;

            my $hr = delete $controller->running_tasks->{$task_id};
            my $cmd_isa_cmd = UNIVERSAL::can($hr->{cmd}, 'isa') && $hr->{cmd}->isa('MeritCommons::Hydrant::Command');

            if ($ENV{MERITCOMMONS_TESTING}) {

                # unsubscribe..
                if ($cmd_isa_cmd) {
                    unless (zmq_setsockopt($hydrant->zmq_subscriber, ZMQ_UNSUBSCRIBE, $task_id) == 0) {
                        warn "Unable to unsubscribe from task_id $task_id\n";
                    }
                }

                # data comes as a 4th argument during testing...
                $hr->{callback}->($hr->{cmd}, { payload => $_[3] });

                # turn off shutdown protection on the websocket, if we're being run from a websocket
                $hydrant->shutdown_protection(0) if $cmd_isa_cmd;
            } else {
                my $pg = $controller->async_mojo_pg;

                $pg->db->query(
                    'select payload from meritcommons_async_results where task_id = ?' => $task_id => sub {
                        my ($db, $err, $results) = @_;

                        $hr->{callback}->($hr->{cmd}, $results->expand->hash);

                        if ($cmd_isa_cmd) {

                            # unsubscribe..
                            unless (zmq_setsockopt($hydrant->zmq_subscriber, ZMQ_UNSUBSCRIBE, $task_id) == 0) {
                                warn "Unable to unsubscribe from task_id $task_id\n";
                            }
                        }

                        $pg->db->query(
                            "delete from meritcommons_async_results where task_id = ?" => $task_id => sub {

                                # it's okay to shut this websocket down now.
                                $hydrant->shutdown_protection(0) if $cmd_isa_cmd;
                            }
                        );
                    }
                );
            }
        }
    );

    # helper for accessing running tasks hashref
    $self->helper(
        'running_tasks' => sub {
            return $running_tasks;
        }
    );

    # for accessing the production database in an async fashion
    $self->helper(
        'mojo_pg' => sub {
            return $mojo_pg;
        }
    );

    # for accessing the async tasks database
    $self->helper(
        'async_mojo_pg' => sub {
            return $async_mojo_pg;
        }
    );

    # return a random replica
    $self->helper(
        'mojo_pg_replica' => sub {
            return $mojo_pg_replicas[ rand @mojo_pg_replicas ];
        }
    );

    # return a random replica or the mojo_pg
    $self->helper(
        'mojo_pg_rorm' => sub {
            return scalar @mojo_pg_replicas ? $mojo_pg_replicas[ rand @mojo_pg_replicas ] : $mojo_pg;
        }
    );

    # return a list of all replicas
    $self->helper(
        'mojo_pg_replicas' => sub {
            return @mojo_pg_replicas;
        }
    );

    # async tasks were dependent on these helpers!!
    $self->plugin('AsyncTasks');    # configured Minion async tasks

    # run the content driver inbound chain...
    $self->helper(
        'cd_inbound' => sub {
            my ($controller, $content, $actor) = @_;
            unless (ref($content) eq "MeritCommons::Content") {
                die "cd_inbound requires MeritCommons::Content object!\n";
            }
            my $type = $content->render_as;

            unless (exists($cd_data->{$type}) && $cd_data->{$type}->{setup}) {
                $controller->cd_setup($type);
            }

            return $cd_data->{$type}->{run_inbound}->($controller, $content, $actor);
        }
    );

    # run the content driver outbound chain..
    $self->helper(
        'cd_outbound' => sub {
            my ($controller, $content, $actor) = @_;
            unless (ref($content) eq "MeritCommons::Content") {
                die "cd_inbound requires MeritCommons::Content object!\n";
            }
            my $type = $content->render_as;

            unless (exists($cd_data->{$type}) && $cd_data->{$type}->{setup}) {
                $controller->cd_setup($type);
            }

            return $cd_data->{$type}->{run_outbound}->($controller, $content, $actor);
        }
    );

    # run the content driver notification chain..
    $self->helper(
        'cd_notification' => sub {
            my ($controller, $content, $actor, $notifier) = @_;
            unless (ref($content) eq "MeritCommons::Content") {
                die "cd_notification requires MeritCommons::Content object!\n";
            }

            my $type;
            if (my $thread = $content->thread) {
                $type = $thread->render_as;
            } else {
                $type = $content->about->render_as;
            }

            unless (exists($cd_data->{$type}) && $cd_data->{$type}->{setup}) {
                $controller->cd_setup($type);
            }

            return $cd_data->{$type}->{run_notification}->($controller, $content, $actor, $notifier);
        }
    );

    # set up the content driver stack..
    $self->helper(
        'cd_setup' => sub {
            my ($controller, $type) = @_;

            # reconfigure if it already exists.
            if (exists($cd_data->{$type})) {
                delete $cd_data->{$type};
            }

            # create classes and instantiate objects.
            foreach my $class ($controller->cd_list) {
                eval "require $class";

                my $obj = $class->new({ for => $type, app => $self });
                if (my $priority = $obj->priority) {
                    $cd_data->{$type}->{$class} = {
                        obj      => $obj,
                        priority => $priority,
                    };
                }
            }

            my $exec_sequence = [];
            foreach my $loaded_class (
                sort { $cd_data->{$type}->{$a}->{priority} <=> $cd_data->{$type}->{$b}->{priority} }
                keys %{ $cd_data->{$type} }
              ) {
                push(@$exec_sequence, $cd_data->{$type}->{$loaded_class}->{obj});
            }

            if ($ENV{MERITCOMMONS_DEBUG}) {
                print "[debug] TYPE is $type\n[debug] Exec sequence is...\n";
                foreach my $obj (@$exec_sequence) {
                    warn "      " . ref($obj) . "\n";
                }
            }

            $cd_data->{$type}->{run_inbound} = sub {
                my ($controller, $content, $actor) = @_;
                foreach my $obj (@$exec_sequence) {
                    if ($obj->should_handle($controller, $content, $actor, 'inbound')) {
                        my $old_ra = $content->render_as;
                        $content = $obj->inbound($controller, $content, $actor);

                        # if the message type changed, it's probaby being re-dispatched, stop this dispatch here.
                        last if $old_ra ne $content->render_as;
                    }
                }
                return $content;
            };

            $cd_data->{$type}->{run_outbound} = sub {
                my ($controller, $content, $actor) = @_;
                foreach my $obj (@$exec_sequence) {
                    if ($obj->should_handle($controller, $content, $actor, 'outbound')) {
                        my $old_ra = $content->render_as;
                        $content = $obj->outbound($controller, $content, $actor);

                        # if the message type changed, it's probaby being re-dispatched, stop this dispatch here.
                        last if $old_ra ne $content->render_as;
                    }
                }
                return $content;
            };

            $cd_data->{$type}->{run_notification} = sub {
                my ($controller, $content, $actor, $notifier) = @_;
                foreach my $obj (@$exec_sequence) {
                    if ($obj->should_handle($controller, $content, $actor, 'notification')) {
                        my $old_ra = $content->render_as;
                        $content = $obj->notification($controller, $content, $actor, $notifier);

                        # if the message type changed, it's probaby being re-dispatched, stop this dispatch here.
                        last if $old_ra ne $content->render_as;
                    }
                }
                return $content;
            };

            $cd_data->{$type}->{setup} = 1;
        }
    );

    $self->helper(
        'cd_list' => sub {
            my ($controller, $cd_lib_dir) = @_;

            # disable "use of uninitialized" yadda yadda
            no warnings;

            my @cd_list;
            my $cd_lib_base = $ENV{MERITCOMMONS_HOME} . "/lib/MeritCommons/ContentDriver";

            foreach my $base_path ($cd_lib_base, @$contentdriver_namespaces) {
                my $dfh;
                opendir($dfh, "$base_path/$cd_lib_dir") or die "Can't open ContentDriver lib dir $base_path: $!\n";

                while (my $file = readdir($dfh)) {
                    next if $file =~ /^\./;
                    if (-d "$cd_lib_base/$cd_lib_dir/$file") {

                        # recurse!
                        push(@cd_list, $controller->cd_list("$cd_lib_dir/$file"));
                    }
                    if ($file =~ /(\w+)\.pm$/) {
                        my (undef, $rel_path) = split(/\/lib\//, $base_path);
                        my $class_prefix =
                          join('::', split('/', $rel_path)) . '::' . join('::', split('/', $cd_lib_dir));
                        push(@cd_list, "$class_prefix$1");
                    }
                }
            }

            return (@cd_list);
        }
    );

    # Get at the notifier file handle!
    $self->helper(
        'notifier_write' => sub {
            my ($controller, @entities) = @_;

            # we can't write anything if the fifo isn't ready to be written to.
            if (sysopen my $fifo, $notifier_fifo_path, O_NONBLOCK | O_WRONLY) {
                my $message = join(
                    ' ',
                    map {
                        (
                              ref($_) eq "MeritCommons::Model::Stream::Message" ? "m."
                            : ref($_) eq "MeritCommons::Model::Stream"          ? "s."
                            : ref($_) eq "MeritCommons::Model::User"            ? "u."
                            : $_ =~ /^m\.[0-9a-f\-]+$/i                      ? $_
                            : $_ =~ /^s\.[0-9a-f\-]+$/i                      ? $_
                            : $_ =~ /^u\.[0-9a-f\-]+$/i                      ? $_
                            :                                                  "?.$_"
                          ) .
                          (ref($_) && $_->can('unique_id') ? $_->unique_id : '')
                    } @entities
                );

                print $fifo "$message\n";
                close($fifo);
            }
        }
    );

    $self->helper(
        'markdown_files' => sub {
            return $markdown_files;
        }  
    );

    $self->helper(
        'contentdriver_namespaces' => sub {
            return $contentdriver_namespaces;
        }
    );

    $self->helper(
        'hydrant_namespaces' => sub {
            return $hydrant_namespaces,;
        }
    );

    if ($config->{bloomd_config} && $config->{bloom_filters}) {
        warn "[debug] bloom filter configuration found, enabling bloom filters (BETA FEATURE)\n"
          if $ENV{MERITCOMMONS_DEBUG};

        # make sure the bloom filters exist...
        my $bloomd = Bloomd::Client->new($config->{bloomd_config} ? %{ $config->{bloomd_config} } : ());
        my $bf_list = $bloomd->list;
        if (ref $config->{bloom_filters} eq "HASH") {
            while (my ($k, $v) = each %{ $config->{bloom_filters} }) {
                my $created = 0;
                foreach my $in_bloomd (@$bf_list) {
                    if ($in_bloomd->{name} eq $v) {
                        $created = 1;
                        last;
                    }
                }
                unless ($created) {
                    warn "[debug] bloom filter for '$k' doesn't exist, creating it...\n" if $ENV{MERITCOMMONS_DEBUG};
                    $bloomd->create($v, 5000000, 0.00001);
                    $bloomd->flush($v);
                }
            }
        }

        $self->helper(
            'bloomd' => sub {
                return $bloomd;
            }
        );
    }

    $self->helper(
        'cache' => sub {
            return $cache;
        }
    );

    $self->helper(
        'build_id' => sub {
            return $build_id;
        }
    );

    # make it so we don't have to parse every time.
    $self->helper(
        'msie' => sub {
            my ($self) = @_;
            my $msie;
            unless ($msie = $self->stash('msie')) {
                if ($self->req->headers->user_agent) {
                    if ($self->can('req') && $self->req->headers->user_agent =~ /MSIE ([5-9])/) {
                        $self->stash(msie => 1);
                        $msie = 1;
                    }
                }
            }
            return $msie;
        }
    );

    $self->helper(
        'hixie76' => sub {
            my ($self) = @_;
            my $hixie76;
            unless ($hixie76 = $self->stash('hixie76')) {
                if ($self->can('req')) {
                    if ($self->req->headers->user_agent =~ /AppleWebKit\/(\d+)/) {
                        if ($1 < 536) {
                            $self->stash(hixie76 => 1);
                            $hixie76 = 1;
                        }
                    } elsif ($self->req->headers->user_agent =~ /Firefox\/(\d+)/) {
                        if ($1 < 20) {
                            $self->stash(hixie76 => 1);
                            $hixie76 = 1;
                        }
                    } elsif ($self->req->headers->user_agent =~ /MSIE ([5-9])/) {
                        $self->stash(hixie76 => 1);
                        $hixie76 = 1;
                    }
                }
            }
            return $hixie76;
        }
    );

    $self->helper(
        'production_js_bundle' => sub {
            my ($self) = @_;
            if ($self->app->mode eq "production") {
                if ($self->msie) {
                    return "/js/main-" . $self->build_id . ".js";
                } else {
                    return $asset_base . "js/main-" . $self->build_id . ".js";
                }
            }
        }
    );

    $self->helper(
        'production_css_bundle' => sub {
            my ($self) = @_;
            if ($self->app->mode eq "production") {
                if ($self->msie) {
                    return "/css/main-" . $self->build_id . ".css";
                } else {
                    return $asset_base . "css/main-" . $self->build_id . ".css";
                }
            }
        }
    );

    $self->helper(
        'development_css_bundle' => sub {
            return "/css/themes/" . $config->{theme} . "/main.less";
        }
    );

    $self->helper(
        'running_as_user' => sub {
            return ($run_as_user, $run_as_uid);
        }
    );

    # just return the fifo path for informational purposes.
    $self->helper(
        'publisher_fifo_path' => sub {
            return $publisher_fifo_path;
        }
    );

    $self->helper(
        'publisher_pid' => sub {
            return $publisher_pid;
        }
    );

    # just return the fifo path for informational purposes.
    $self->helper(
        'notifier_fifo_path' => sub {
            return $notifier_fifo_path;
        }
    );

    $self->helper(
        'notifier_pid' => sub {
            return $notifier_pid;
        }
    );

    # QueryLog convenience method
    $self->helper(
        'ql' => sub {
            return $ql;
        }
    );

    # Replica's QueryLog convenience method
    $self->helper(
        'rql' => sub {
            return $rql;
        }
    );

    $self->helper(
        'local_asset_path' => sub {
            return $local_asset_path;
        }
    );

    $self->helper(
        'asset_base' => sub {
            return $asset_base;
        }
    );

    $self->helper(
        'upload_path' => sub {
            return $upload_path;
        }
    );

    $self->helper(
        'asset_url' => sub {
            my ($self, $subpath) = @_;
            return $asset_base . $subpath;
        }
    );

    $self->helper(
        'external_assets_configured' => sub {
            my ($self) = @_;
            if ($config->{external_asset_base} && $config->{external_asset_path}) {
                return 1;
            }
            return undef;
        }
    );

    # need these now that we're not pulling directly from the config
    $self->helper(
        'publishers' => sub {
            unless ($publishers) {
                my $conf_publishers = $self->config('publishers');
                my @new_publishers;
                foreach my $publisher (@$conf_publishers) {
                    if ($publisher eq 'flock://find_publisher') {

                        # only interpolate if flock_vpn is on.
                        if ($self->config('flock_vpn')) {
                            push(@new_publishers, "epgm://@{[$self->config->{flock_netif_name}]};239.0.13.13:1313");
                        }
                    } else {
                        push(@new_publishers, $publisher);
                    }
                }
                $publishers = \@new_publishers;
            }
            return $publishers;
        }
    );

    $self->helper(
        'publish_to' => sub {
            unless ($publish_to) {
                my $conf_publish_to = $self->config('publish_to');
                my @new_publish_to;
                foreach my $publisher (@$conf_publish_to) {
                    if ($publisher eq 'flock://find_publisher') {

                        # only interpolate if flock_vpn is on.
                        if ($self->config('flock_vpn')) {
                            push(@new_publish_to, "epgm://@{[$self->config->{flock_netif_name}]};239.0.13.13:1313");
                        }
                    } else {
                        push(@new_publish_to, $publisher);
                    }
                }
                $publish_to = \@new_publish_to;
            }
            return $publish_to;
        }
    );

    $self->helper(
        'plugins_config' => sub {
            return $plugins_config;
        }
    );

    # no error handling!
    $self->helper(
        'save_hashref' => sub {
            my ($app, $hr, $file) = @_;
            local $Data::Dumper::Terse = 1;
            Mojo::File->new($file)->spurt($app->dumper($hr));
        }
    );

    $self->helper(
        'plugins_config_file' => sub {
            return $plugins_config_file;
        }
    );

    $self->helper(
        'save_plugins_config' => sub {
            my ($app) = @_;
            $app->save_hashref($app->plugins_config, $plugins_config_file);
        }
    );

    $self->helper(
        'closest_semester' => sub {
            my ($c, $time, $fmt) = @_;
            $time //= time;
            my @tc = localtime($time);
            
            $fmt //= "%Y%m";
            
            my $year = $tc[5] + 1900;
            my $mon = $tc[4] + 1;
            my $day = $tc[3];
            
            # Rolling calendar -- clicks to the "closest semster" based on the following guide (falls forward on the date)
            # <-----<-DEC1=->------ YYYY01 -----<-APR1=->----- YYYY06 -----<-AUG1=->----- YYYY09 ------------>
            
            # DEC1 - APR1 => YYYY01
            # APR1 - AUG1 => YYYY06
            # AUG1 - DEC1 => YYYY09
            
            if ($mon == 12) {
                # YYYY01 (Y + 1)
                $tc[5]++;
                $tc[4] = 0;
            } elsif ($mon >= 8) {
                # YYYY09
                $tc[4] = 8;
            } elsif ($mon >= 4) {
                # YYYY06
                $tc[4] = 5;
            } else {
                # YYYY01
                $tc[4] = 0;
            }
            
            # use 01 as the "day" in all cases.
            $tc[3] = 1;
            
            return strftime($fmt, @tc);
        }
    );

    # TODO: move to SearchUtil once we get rid of Sphinx + SphinxUtil
    $self->helper(
        search_providers => sub {
            my ($c) = @_;

            my $search_providers = {
                meritcommons => {
                    action      => '/search/',
                    placeholder => 'Search ' . ($config->{system_title} // 'MeritCommons'),
                    query_param => 'query',
                    extra       => {},
                },
                ref $config->{search_providers} eq "HASH" ? %{ $config->{search_providers} } : ()
            };

            if (my $sf = $c->stash('search_stream_filter')) {
                $search_providers->{meritcommons}->{extra}->{search_stream_filter} = $sf;
            }

            return $search_providers;
        }
    );    

    my $daemons = MeritCommons::Daemons->new(app => $self);
    $self->helper(
        daemons => sub {
            return $daemons;
        }
    );

    $self->hook(
        before_server_start => sub {
            my ($server, $self) = @_;
            
            # server ID!
            print $self->version_banner . "\n";

            # set the terminal's titlebar
            print "\c[];@{[$self->version_banner]}\a";

            # some useful debug output
            print "[debug] main process PID is $$\n" if $ENV{MERITCOMMONS_DEBUG};
            print "[debug] selected cache is " . ref($cache) . "\n" if $ENV{MERITCOMMONS_DEBUG};

            # set up the Flock VPN for cluster control + multicast on multicast hating networks
            my $iface;
            my $fvpn;

            # start flock_vpn before the publishers.
            if ($self->app->config('flock_vpn')) {
                $fvpn = MeritCommons::Infra::FlockVPN->new($self->app);
                if ($fvpn->coordinator) {

                    # start coordinator duties.
                    $fvpn->start_supernode();
                    $iface = $fvpn->start_edge();
                    if ($iface) {

                        # start dhcp..
                        warn "[debug] starting dhcpd on $iface\n" if $ENV{MERITCOMMONS_DEBUG};
                        $fvpn->start_dhcpd;
                        $fvpn->setup_routes;
                    }
                } else {
                    $iface = $fvpn->start_edge() unless $fvpn->edge_pid;

                    my $dhclient_pid = `ps -ef | grep 'dhclient @{[$fvpn->iface]}' | grep -v grep | awk '{print \$2}'`;
                    chomp($dhclient_pid);
                    unless ($dhclient_pid) {
                        system("sudo dhclient @{[$fvpn->iface]}");
                    }
                    $fvpn->setup_routes;
                }
            }

            # if we're production, let's build!  PRODUCTION BUILD <- for finding this later.
            if ($self->mode eq "production") {
                my (@template_files, @component_files);

                # Lets make sure that we clean up any symlinks if we got them
                if (-l "$ENV{MERITCOMMONS_HOME}/public/css/themes") {
                    if (-l "$ENV{MERITCOMMONS_HOME}/public/css/themes/img") {

                        # Lets get rid of that then
                        unlink "$ENV{MERITCOMMONS_HOME}/public/css/themes/img"
                          or die "Failed to remove `themes/img` symlink before starting prod!";
                    }
                    if (-l "$ENV{MERITCOMMONS_HOME}/public/css/themes/font") {

                        # Lets get rid of that then
                        unlink "$ENV{MERITCOMMONS_HOME}/public/css/themes/font"
                          or die "Failed to remove `themes/font` symlink before starting prod!";
                    }
                    unlink "$ENV{MERITCOMMONS_HOME}/public/css/themes"
                      or die "Failed to remove `themes` symlink before starting prod!";
                }

                # where to scan for includes
                my $js_dir  = "$ENV{MERITCOMMONS_HOME}/public/js";
                my $css_dir = "$ENV{MERITCOMMONS_HOME}/public/css";

                find(
                    sub {
                        my $filename = $File::Find::name;
                        if ($filename =~ /$js_dir\/(.+\.mustache)$/i) {
                            push(@template_files, "text!$1");
                        }
                    },
                    $js_dir . "/templates"
                );

                find(
                    sub {
                        my $filename = $File::Find::name;
                        if ($filename =~ /$js_dir\/(.+)\.js$/i) {
                            push(@component_files, "$1");
                        }
                    },
                    $js_dir . "/backbone_components"
                );

                # since require.js doesn't know about everything we're including aside from main.js, let's include a few other things.
                my $include_string = join(",", @template_files, @component_files);

                my $nodejs = `which node`;
                unless ($nodejs) {
                    $nodejs = `which nodejs`;
                }
                chomp $nodejs;

                unless ($nodejs) {
                    die "[fatal]: can't start in production without Node.js";
                }

                # build the js to a temp file
                system(
                    "$nodejs --stack-size=10240000 $ENV{MERITCOMMONS_HOME}/script/r.js -o $ENV{MERITCOMMONS_HOME}/etc/build.js include='$include_string' out=/tmp/$$-build.js.tmp 2>&1 >> /dev/null"
                );

                # slurp it in to do an md5sum on it
                open(BUILT_JS, '<', "/tmp/$$-build.js.tmp") or die "[error]: can't open js build temp file: $!\n";
                binmode(BUILT_JS);
                my $js_string;
                {
                    local $/;
                    $js_string = <BUILT_JS>;
                }
                close(BUILT_JS);

                open my $ab_less, '>', "$ENV{MERITCOMMONS_HOME}/themes/$config->{theme}/.asset-base.less";
                print $ab_less '@asset-base: "' . $asset_base . '";';
                close $ab_less;

                # build the css to a temp file
                system("lessc -x $ENV{MERITCOMMONS_HOME}/themes/$config->{theme}/main.less > /tmp/$$-build.css.tmp");

                # slurp it in to do an md5sum on it
                open(BUILT_CSS, '<', "/tmp/$$-build.css.tmp") or die "[error]: can't open css build temp file: $!\n";
                binmode(BUILT_CSS);
                my $css_string;
                {
                    local $/;
                    $css_string = <BUILT_CSS>;
                }
                close(BUILT_CSS);

                $build_id  = $self->crypto->md5_hex($js_string . $css_string);
                $built_js  = "$js_dir/main-$build_id.js";
                $built_css = "$css_dir/main-$build_id.css";

                find(
                    sub {
                        my $filename = $File::Find::name;
                        if ($filename =~ /(main-[0-9A-F]{32}\.js)$/i) {
                            return if $filename eq $built_js;
                            print "[debug] cleaning up previous production bundle $1\n" if $ENV{MERITCOMMONS_DEBUG};
                            unlink($filename);
                        }
                    },
                    $js_dir
                );

                # write it out to the new location.
                open(BUILT_JS, '>', $built_js);
                print BUILT_JS $js_string;
                close(BUILT_JS);

                find(
                    sub {
                        my $filename = $File::Find::name;
                        if ($filename =~ /(main-[0-9A-F]{32}\.css)$/i) {
                            return if $filename eq $built_css;
                            print "[debug] cleaning up previous production bundle $1\n" if $ENV{MERITCOMMONS_DEBUG};
                            unlink($filename);
                        }
                    },
                    $css_dir
                );

                # write it out to the new location.
                open(BUILT_CSS, '>', $built_css);
                print BUILT_CSS $css_string;
                close(BUILT_CSS);

                # cleanup.
                unlink("/tmp/$$-build.js.tmp");
                unlink("/tmp/$$-build.css.tmp");

                if ($external_asset_path && $external_asset_base) {
                    if (!-e "$external_asset_path/js/main-$build_id.js") {
                        print "[info] uploading JS bundle to $external_asset_base" . "js/...\n";

                        open(EXTERNAL_BUILT_JS, '>', "$external_asset_path/js/main-$build_id.js");
                        print EXTERNAL_BUILT_JS $js_string;
                        close(EXTERNAL_BUILT_JS);
                    }

                    if (!-e "$external_asset_path/css/main-$build_id.css") {
                        print "[info] uploading CSS bundle to $external_asset_base" . "css/...\n";

                        open(EXTERNAL_BUILT_CSS, '>', "$external_asset_path/css/main-$build_id.css");
                        print EXTERNAL_BUILT_CSS $css_string;
                        close(EXTERNAL_BUILT_CSS);
                    }
                }

                print "[info] MeritCommons production build id: $build_id\n" if $ENV{MERITCOMMONS_DEBUG};
            } else {

                # We're in development!

                # Check to see if we have everything symlinked properly
                if (-l "$ENV{MERITCOMMONS_HOME}/public/css/themes") {

                    # Cool, got the themes dir symlinked. Lets make sure that
                    # the img dir is symlinked in themes too.
                    unless (-l "$ENV{MERITCOMMONS_HOME}/public/css/themes/img") {

                        # Let's make it then
                        system("ln -s $ENV{MERITCOMMONS_HOME}/public/img $ENV{MERITCOMMONS_HOME}/public/css/themes/img");
                    }

                    # Cool, got the themes dir symlinked. Lets make sure that
                    # the img dir is symlinked in themes too.
                    unless (-l "$ENV{MERITCOMMONS_HOME}/public/css/themes/font") {

                        # Let's make it then
                        system("ln -s $ENV{MERITCOMMONS_HOME}/public/font $ENV{MERITCOMMONS_HOME}/public/css/themes/font");
                    }
                } else {

                    # O Noes! Lets make those symlinks!
                    system("ln -s $ENV{MERITCOMMONS_HOME}/themes $ENV{MERITCOMMONS_HOME}/public/css/themes");
                    system("ln -s $ENV{MERITCOMMONS_HOME}/public/img $ENV{MERITCOMMONS_HOME}/public/css/themes/img");
                    system("ln -s $ENV{MERITCOMMONS_HOME}/public/font $ENV{MERITCOMMONS_HOME}/public/css/themes/font");
                }

                open my $ab_less, '>', "$ENV{MERITCOMMONS_HOME}/themes/$config->{theme}/.asset-base.less";
                print $ab_less '@asset-base: "/";';
                close $ab_less;                
            }

            ####
            #   #
            #    #
            #   #
            #### AEMONS
            $daemons->iface($iface);
            $daemons->fvpn($fvpn);
            $daemons->startup;

            print "[debug] main process forked PIDs $publisher_pid, $notifier_pid, $system_agent_pid\n"
              if $ENV{MERITCOMMONS_DEBUG};
            $self->app->log->info($self->app->version_banner . "; Manager running as pid $$");
        }
    ); # end before_server_start hook


    # this event is only emitted by the meritcommons-development server
    $self->on(
        devspawn => sub {
            my ($app) = @_;
            system("meritcommons minion_mp --stop --quiet");
            $daemons->stop_all;
        }
    );

    #######
    #     #
    ######
    #    #
    #     # OUTES
    my $r = MeritCommons::Routes->new($self)->startup;

    #     #
    #     #
    #######
    #     #
    #     # OOKS

    # gzip after render if encoding allows..
    $self->hook(
        after_render => sub {
            my ($c, $output, $format) = @_;

            # sshould we compress?
            return unless $c->stash->{gzip};
            return unless ($c->req->headers->accept_encoding // '') =~ /gzip/i;
            $c->res->headers->append(Vary => 'Accept-Encoding');

            $c->res->headers->content_encoding('gzip');
            gzip $output, \my $compressed;
            $$output = $compressed;
        }
    );

    $self->on(
        unauthenticated_access => sub {
            my ($app, $c) = @_;

            if ($c->req->url->path =~
                /^\/(?:myws|auth|js|img|css|favicon\.ico|hydrant|cs|lt|si|idp|login|self_check)\/?$/) {
                $c->stash(redirect_to_auth_url => 0);
            } else {

                # if something else already said don't redirect, then we don't redirect
                unless (defined $c->stash('redirect_to_auth_url') && $c->stash('redirect_to_auth_url') == 0) {
                    $c->stash(redirect_to_auth_url => 1);
                }
            }
        }
    );

    $self->hook(
        around_dispatch => sub {
            my ($next, $c) = @_;

            eval { $next->(); };

            if (my $error = $@) {
                if ($error =~ /Error ID/) {

                    # this one has an ID, and therefore it's already been processed.  don't log for it.
                    $c->reply->exception($error);
                } else {
                    my $error_id = $c->new_uuid;
                    $self->log->error(
                        "Error ID $error_id - general error - request @{[$c->req->method]} @{[$c->req->url->to_string]} $error"
                    );

                    if ($c->tx->remote_address && $self->mode eq 'production') {
                        $c->reply->exception("<h3>General Error</h3><p>Error ID: $error_id</p>");
                    } elsif ($c->tx->remote_address) {
                        $c->reply->exception($error);
                    }
                }
            }
        }
    );

    # enforce front_door_host, ELB health check exceptions, and auth url goodies
    $self->hook(
        before_dispatch => sub {
            my ($self) = @_;

            # server version header
            my $mode = $self->app->mode;
            $self->tx->res->headers->server($self->version_banner);

            # for old IE versions, force the most-compatible supported version
            $self->tx->res->headers->append('X-UA-Compatible' => 'IE=edge');

            # first thing's first, make sure force_ssl requests are redirected to SSL
            if ($config->{force_ssl}) {
                if (!$self->req->is_secure) {
                    my $url = $self->req->url;
                    $url->base->scheme('https');

                    # may as well redirect to the proper front door here as well.
                    my $redirect_url = $config->{front_door_url};
                    if ($redirect_url) {
                        $redirect_url .= $url->path if $url->path;
                        $redirect_url .= "?" . $url->query->to_string if $url->query->to_string;
                    } else {

                        # it's not configured, just redirect to https:// whatever this is.
                        $redirect_url = $url->to_abs;
                    }
                    return $self->redirect_to($redirect_url);
                }
            }

            my $ua = $self->req->headers->user_agent;
            
            if ($ua && ($ua eq "ELB-HealthChecker/1.0" || $ua eq "MeritCommons")) { 
                # just render all clear for health check
                $self->render(text => "everything's okay");
            } else {
                my $url = $self->req->url->to_abs;

                # only hydrant requests go directly to the app servers.
                unless (($url->host eq $config->{front_door_host}) || ($url->path eq "/hydrant")) {
                    $url->host($config->{front_door_host});
                    return $self->redirect_to($url);
                }

                # set the username
                if (my $user = $self->active_user) {
                    $self->req->env->{REMOTE_USER} = $user->userid;
                } else {
                    # may as well do this here since we already checked for active_user
                    if (my $auth_url = $config->{auth_url}) {

                        # let's get a Mojo::URL
                        $auth_url = Mojo::URL->new($auth_url);

                        # default to destination_url for back parameter
                        my $back_param = $config->{auth_back_param} || 'destination_url';

                        $self->app->emit('unauthenticated_access' => $self);

                        # if it's not a session negotiation request, make them log in!
                        if ($self->stash('redirect_to_auth_url')) {

                            # add the query & redirect...
                            $auth_url->query({ $back_param => $self->req->url->to_abs });
                            return $self->redirect_to($auth_url);
                        }
                    }
                }
            }
        }
    );

    # load plugins last so they can override stuff
    unless ($ENV{MERITCOMMONS_NO_PLUGINS}) {

        # dynamically load all plugins identified in the config
        if (ref $plugins_config->{enabled}) {
            for my $plugin (@{ $plugins_config->{enabled} }) {

                # they should be already loaded (above)
                no strict 'refs';
                print "[info] loading plugin '$plugin' version " . ${"${plugin}::VERSION"} . "\n"
                  if $ENV{MERITCOMMONS_DEBUG};
                use strict 'refs';
                push(@$loaded_plugins, $self->plugin($plugin));
            }
        }
    }

    # this has to be last, for obvious reasons.
    $r->route('/:catchall')->to('controller-catchall#default');
}

sub _db_config_to_url {
    my ($block, $suffix) = @_;

    $suffix = "_$suffix" if $suffix;

    # default to 'async' suffix
    $suffix //= "";

    if (ref($block) eq "HASH") {
        if ($block->{dsn} =~ /^dbi:Pg:(.+)$/) {
            my %kvs = (map { split(/=/) } split(/;/, $1));
            my $url = Mojo::URL->new();
            $url->scheme('postgresql');
            $url->host($kvs{host} || "localhost");
            $url->port($kvs{port} || 5432);
            $url->path($kvs{dbname} ? "$kvs{dbname}$suffix" : "meritcommons$suffix");

            $url->userinfo(join(':', $block->{user} ? ($block->{user}, $block->{password}) : (getpwnam($>), '')));
            return $url->to_string;
        }
    } elsif (ref($block) eq "ARRAY") {

        # arrayrefs are used for replica definitions
        # ['dbi:Pg:host=127.0.0.1;dbname=meritcommons', 'mikeyg', 'abcd1234', { pg_enable_utf8 => 1 }],

        if ($block->[0] =~ /^dbi:Pg:(.+)$/) {
            my %kvs = (map { split(/=/) } split(/;/, $1));
            my $url = Mojo::URL->new();
            $url->scheme('postgresql');
            $url->host($kvs{host} || "localhost");
            $url->port($kvs{port} || 5432);
            $url->path($kvs{dbname} ? "$kvs{dbname}$suffix" : "meritcommons$suffix");

            $url->userinfo(join(':', $block->[1] ? ($block->[1], $block->[2]) : (getpwnam($>), '')));

            return $url->to_string;
        }
    }

    warn "[error] database config supplied to _db_config_to_url is not for a PostgreSQL database\n";
    return undef;
}

sub DESTROY {
    my ($self) = @_;

    #warn "$$ MeritCommons::DESTROY: manager process? $is_manager_process ($daemons_shut_down, $self->{is_mojo_command})\n";

    if ($is_manager_process && !$daemons_shut_down && !$self->{is_mojo_command}) {
        my $log;
        unless ($log = $self->log) {
            $log = Mojo::Log->new(path => "$ENV{MERITCOMMONS_HOME}/log/MeritCommons_DESTROY.log");
        }
        $log->info("Daemon-killing DESTROY called by $$, $0, at " . scalar(localtime)) if $log;

        if ($system_agent_pid) {
            kill("QUIT", $system_agent_pid);
        }

        if ($notifier_pid) {
            kill("QUIT", $notifier_pid);
        }
        unlink($notifier_fifo_path);

        if ($publisher_pid) {
            kill("QUIT", $publisher_pid);
        }
        unlink($publisher_fifo_path);

        $daemons_shut_down = 1;
    }

    if ($zmq_shared_context) {
        zmq_ctx_destroy($zmq_shared_context);
    }
}

=pod

=encoding utf8

=head1 SYNOPSIS

=over 2

B<MeritCommons, © 2012-2017 Wayne State University>

An enterprise social portal in production on the B<Amazon Web Services> platform at 
B<Wayne State University> in B<Detroit, MI>

=back

=head1 TECHNICAL DOCUMENTATION

Currently the best source of technical documentation on MeritCommons would be the core 
repository's wiki at: https://git.meritcommons.io/meritcommons/core/wikis/home/

=head1 DEVELOPMENT ENVIRONMENT

A quick and easy way to get a Mac or Linux client, or a Linux VM going as a development
server is to use the B<MeritCommons Docker Tools> available at: https://git.meritcommons.io/meritcommons/docker-tools/

=head1 LICENSE

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself,
either Perl version 5.26 or, at your option, any later version of Perl 5 you may have available.  See 
L<The Perl Artistic License|doc/markdown/license.md> in F<doc/markdown/license.md> (from the root of the 
core repository) for more information.

=head1 DEDICATED TO

=over 3 

=item * 

I<The great Students, Faculty, and Staff of Wayne State University>

=item * 

I<The resurgence of the great city of Detroit, MI>

=item * 

I<The MeritCommons Development Team and Contributors>

=item * 

I<Everyone who attended an MeritCommons Friday>

=item * 

I<A Brighter Tomorrow>

=back

=head1 DEVELOPERS

=over 2

These are the people who brought MeritCommons from concept to reality, overcoming writer's block,
setting sound new years resolutions, squashing bugs, committing all of MathJax again and 
again.  This team stepped up to help create what ended up being over 100,000 lines of front-end
and back-end code, leveraging bleeding edge web technologies like WebSockets, bare-metal efficient 
messaging implementations like ZeroMQ, and confronting a situation where we had to bridge the 
old world to the internet that was emerging before us.  Together we created a truly real-time 
portal platform that didn't leave any legacy systems behind and allowed us to integrate with new, 
emerging systems using the new realtime interfaces they provided.  

I have heard many say "the portal is dead", I for one think the jury's still out on that.  And just 
in case it isn't, MeritCommons is here to save the day with fast SSO, links, search, a message ingestion
rate that could handle all tweets pertaining to Justin Bieber (in his hayday), incredible flexibility
in content presentation, and a horizontal scale that could likely make it over the million concurrent
user mark without breaking a sweat.  It's all thanks to these dedicated, curious, inventive, and well 
learned individuals who I<volunteered> to be on my team.  From the bottom of my heart I<thank you>.

I know I went all Barry Sanders near the endzone and clammed up to get it over the goal line, but
I want to make it very clear that I couldn't have done this without you.  Heck, even maintaining
it semi-solo is hard.  I miss AFs, I miss when half this stuff didn't exist, I miss the first days of
messaging and the first I<MEGATHREADS>.  When we were the only users on the system.  Those days have
come and gone, we're now in our third year of production and people are getting used to things.

We all knew we weren't ever going to be able to compete with Silicon Valley's social networks on
messaging but we did a great job of being a "Better Pipeline".  Getting people where they needed
to go and getting the heck out of their way.  It can and will only get better from here, as we move
towards positioning ourselves not merely as an application but as an open source B<platform> for 
developing integrated real-time applications.

=back

=head2 CORE DEVELOPMENT TEAM 2012-2016

=over 3 

=item * 

B<Claudio Bryla> - I<claudio@claudio.pl>

=item * 

B<Brad Dunn> - Formerly of I<(Wayne State University)>

=item * 

B<Adam Lincoln> - Formerly of I<(Wayne State University)>

=item * 

B<David Thompson> I<david@wayne.edu>

=item * 

B<Mike Ward> - I<mward@wayne.edu>

=back

=head2 CONTRIBUTING DEVELOPERS 2012-2016

=over 3

=item * 

B<Kwame Beard> - I<LordSoulReaverThe3rdEsq@wayne.edu>

=item *

B<Shane Burgess> - Formerly of I<(Merit Network, Inc.)>

=item * 

B<Jeff Dunn> - I<jdunn@wayne.edu>

=item * 

B<James Lee> - I<jameslee@wayne.edu>

=item * 

B<Genetha Smith> - I<genetha@wayne.edu>

=item * 

B<Rob Thompson> - I<rob@wayne.edu>

=back

=head2 ARCHITECT; LEAD DEVELOPER; BDFL and as of now, SOLE MAINTAINER 2011-PRESENT

=over 3

=item * 

B<Michael Gregorowicz> - I<mike@mg2.org>, I<mg@wayne.edu>

=back

=cut

1;

__DATA__

@@ async
-- 1 up
create table if not exists meritcommons_async_results (
    id bigserial not null primary key,
    task_id uuid not null,
    payload json
);
create index on meritcommons_async_results (task_id);
create table if not exists meritcommons_async_stash (
    id bigserial not null primary key,
    unique_id varchar(64) not null,
    payload json
);
create index on meritcommons_async_stash ( unique_id );
create table if not exists minion_jobs (
  id       bigserial not null primary key,
  args     json not null,
  created  timestamp with time zone not null,
  delayed  timestamp with time zone not null,
  finished timestamp with time zone,
  priority int not null,
  result   json,
  retried  timestamp with time zone,
  retries  int not null,
  started  timestamp with time zone,
  state    text not null,
  task     text not null,
  worker   bigint
);
create index on minion_jobs (priority DESC, created);
create table if not exists minion_workers (
  id      bigserial not null primary key,
  host    text not null,
  pid     int not null,
  started timestamp with time zone not null
);
create or replace function minion_jobs_insert_notify() returns trigger as $$
  begin
    perform pg_notify('minion.job', '');
    return null;
  end;
$$ language plpgsql;
set client_min_messages to warning;
drop trigger if exists minion_jobs_insert_trigger on minion_jobs;
set client_min_messages to notice;
create trigger minion_jobs_insert_trigger after insert on minion_jobs
  for each row execute procedure minion_jobs_insert_notify();

-- 1 down
drop table if exists minion_jobs;
drop function if exists minion_jobs_insert_notify();
drop table if exists minion_workers;

-- 2 up
alter table minion_jobs alter column created set default now();
alter table minion_jobs alter column state set default 'inactive';
alter table minion_jobs alter column retries set default 0;
alter table minion_workers add column
  notified timestamp with time zone not null default now();
alter table minion_workers alter column started set default now();

-- 3 up
create index on minion_jobs (state);

-- 4 up
alter table minion_jobs add column queue text not null default 'default';

-- 5 up
alter table minion_jobs add column attempts int not null default 1;

-- 6 up
drop index minion_jobs_state_idx;

-- 7 up
create type minion_state as enum ('inactive', 'active', 'failed', 'finished');
alter table minion_jobs alter column state set default 'inactive'::minion_state;
alter table minion_jobs
  alter column state type minion_state using state::minion_state;
alter table minion_jobs alter column args type jsonb using args::jsonb;
alter table minion_jobs alter column result type jsonb using result::jsonb;

-- 7 down
alter table minion_jobs alter column state type text using state;
alter table minion_jobs alter column state set default 'inactive';
drop type if exists minion_state;

-- 8 up
alter table minion_jobs add constraint args check(jsonb_typeof(args) = 'array');

-- 9 up
create or replace function minion_jobs_notify_workers() returns trigger as $$
  begin
    if new.delayed <= now() then
      notify "minion.job";
    end if;
    return null;
  end;
$$ language plpgsql;
set client_min_messages to warning;
drop trigger if exists minion_jobs_insert_trigger on minion_jobs;
drop trigger if exists minion_jobs_notify_workers_trigger on minion_jobs;
set client_min_messages to notice;
create trigger minion_jobs_notify_workers_trigger
  after insert or update of retries on minion_jobs
  for each row execute procedure minion_jobs_notify_workers();

-- 9 down
drop trigger if exists minion_jobs_notify_workers_trigger on minion_jobs;
drop function if exists minion_jobs_notify_workers();

-- 10 up
alter table minion_jobs add column parents bigint[] default '{}';

-- 11 up
create index on minion_jobs (state, priority desc, id);

-- 12 up
alter table minion_workers add column inbox jsonb
  check(jsonb_typeof(inbox) = 'array') default '[]';

-- 15 up
alter table minion_workers add column status jsonb;

-- 16 up
create index on minion_jobs using gin (parents);
create table if not exists minion_locks (
  id      bigserial not null primary key,
  name    text not null,
  expires timestamp with time zone not null
);
create function minion_lock(text, int, int) returns bool as $$
declare
  new_expires timestamp with time zone = now() + (interval '1 second' * $2);
begin
  delete from minion_locks where expires < now();
  lock table minion_locks in exclusive mode;
  if (select count(*) >= $3 from minion_locks where name = $1) then
    return false;
  end if;
  if new_expires > now() then
    insert into minion_locks (name, expires) values ($1, new_expires);
  end if;
  return true;
end;
$$ language plpgsql;

-- 16 down
drop function if exists minion_lock(text, int, int);
drop table if exists minion_locks;

-- 17 up
alter table minion_jobs add column notes jsonb
  check(jsonb_typeof(notes) = 'object') not null default '{}';
alter table minion_locks set unlogged;
create index on minion_locks (name, expires);

-- 18 up
create or replace function minion_lock(text, int, int) returns bool as $$
declare
  new_expires timestamp with time zone = now() + (interval '1 second' * $2);
begin
  lock table minion_locks in exclusive mode;
  delete from minion_locks where expires < now();
  if (select count(*) >= $3 from minion_locks where name = $1) then
    return false;
  end if;
  if new_expires > now() then
    insert into minion_locks (name, expires) values ($1, new_expires);
  end if;
  return true;
end;
$$ language plpgsql;

-- 18 down
drop function if exists minion_lock(text, int, int);