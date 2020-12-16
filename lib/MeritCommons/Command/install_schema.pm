#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::install_schema;

use Mojo::Base 'Mojolicious::Command';
use Getopt::Long qw(GetOptionsFromArray :config no_auto_abbrev no_ignore_case);
use DBIx::Class::Migration;

has description => "Deploy the meritcommons schema to the data stream configured in meritcommons.conf\n";
has usage       => <<"EOF";
Usage: $0 install_schema [OPTIONS]

These options are available for 'install_schema':
    --force-overwrite       Allow DBIx::Class::Migration to overwrite metadata files distributed with
                            MeritCommons Core.  Please do *not* commit these new files to the repository. 
    --version               Deploy this schema version
    --drop-tables           Drop existing tables before deploying
    -d                      Enable debug mode

EOF

sub run {
    my ($self, @args) = @_;

    GetOptionsFromArray(
        \@args,
        'force-overwrite' => \my $force_overwrite,
        'version=s'       => \my $deploy_version,
        'drop-tables'     => \my $drop_tables,
        'd'               => \my $debug,
    );

    # this is wayyy to spammy.
    unless ($ENV{MERITCOMMONS_DEBUG}) {
        open(STDERR, '>>/dev/null');
    }

    my $core_schema_dir    = $ENV{MERITCOMMONS_HOME} . "/var/sql";
    my $plugins_schema_dir = $ENV{MERITCOMMONS_HOME} . "/../var/plugins/sql";

    $self->{schema} = $self->app->m;

    # if we have schema changing plugins enabled, this should always return true.

    if ($ENV{MERITCOMMONS_TESTING}) {
        system("mkdir -p /tmp/meritcommons_schema.$$/");
        if (-d $plugins_schema_dir) {
            system("rsync -apr $plugins_schema_dir/ /tmp/meritcommons_schema.$$/");
        } else {
            system("rsync -apr $core_schema_dir/ /tmp/meritcommons_schema.$$/");
        }
        $self->{schema_dir} = "/tmp/meritcommons_schema.$$";
        $force_overwrite = 1;
    } elsif ($self->{schema}->schema_version % 1000) {
        system("mkdir -p $plugins_schema_dir") unless -d $plugins_schema_dir;
        system("rsync -apr $core_schema_dir/ $plugins_schema_dir/");
        $self->{schema_dir} = $plugins_schema_dir;
    } else {

        # we're just dealing with vanilla schemas
        $self->{schema_dir} = $core_schema_dir;
    }

    my $migration;
    if ($force_overwrite) {
        $migration = DBIx::Class::Migration->new(
            schema       => $self->{schema},
            target_dir   => $self->{schema_dir},
            dbic_dh_args => {
                force_overwrite => 1,
            },
        );
    } else {
        $migration = DBIx::Class::Migration->new(
            schema     => $self->{schema},
            target_dir => $self->{schema_dir},
        );
    }

    my ($is_installed, $schema_version, $deployed_version);
    eval {
        $is_installed     = $migration->dbic_dh->version_storage_is_installed;
        $schema_version   = $migration->dbic_dh->schema_version;
        $deployed_version = $migration->dbic_dh->database_version;
    };

    $deploy_version = $schema_version unless $deploy_version;

    my $dh = $migration->dbic_dh;

    if ($is_installed && $deployed_version) {
        print "[info] detected schema version $deployed_version is already installed.\n";
        if ($deploy_version > $deployed_version) {
            print
              "\n[hmm...] your schema ($deploy_version) looks newer than the installed ($deployed_version), you might want to try\n";
            print "          and run 'prepare_schema_upgrade' and / or 'upgrade_schema.'\n\n";
        }
        if ($drop_tables) {
            print "[info] dropping tables & redeploying schema\n";
            $migration->drop_tables;
            if ($force_overwrite) {
                $dh->prepare_deploy;
            }
            $dh->deploy({ version => $deploy_version });
            $dh->add_database_version(
                {
                    version => $deploy_version,
                }
            );
        } else {
            print "[bye] exiting.\n";
            return;
        }
    } else {
        print "[info] database schema is not currently installed.\n";
        eval { $dh->prepare_deploy; };
        $dh->deploy({ version => $deploy_version });

        eval {
            $dh->prepare_version_storage_install;
            $dh->install_version_storage;
        };

        $dh->add_database_version(
            {
                version => $deploy_version,
            }
        );

        print "[info] schema installed.\n";

        # clean up our scratch space.
        if ($ENV{MERITCOMMONS_TESTING}) {
            if (-d "/tmp/meritcommons_schema.$$") {
                system("rm -rf /tmp/meritcommons_schema.$$");
            }
        }
    }

    # Insert seed data for standard profile attributes
    my @profile_attributes = (
        { is_default => 0, type => "M", label => "Favorite TV Shows" },
        { is_default => 0, type => "M", label => "Favorite Movies" },
        { is_default => 0, type => "M", label => "Favorite Books" },
        { is_default => 0, type => "M", label => "Favorite Classes" },
        { is_default => 0, type => "S", label => "Favorite Color" },
        { is_default => 0, type => "S", label => "Favorite Drink" },
        { is_default => 0, type => "M", label => "Favorite Websites" },
        { is_default => 0, type => "M", label => "Favorite Web Comics" },
        { is_default => 0, type => "M", label => "Favorite Professor" },
        { is_default => 0, type => "S", label => "Favorite Class" },
        { is_default => 0, type => "S", label => "Favorite Restaurant" },
        { is_default => 0, type => "M", label => "Favorite Journals" },
        { is_default => 0, type => "M", label => "Favorite Magazines" },
        { is_default => 0, type => "M", label => "Favorite Blogs" },
        { is_default => 0, type => "M", label => "Favorite Games" },
        { is_default => 0, type => "M", label => "Favorite Athletes" },
        { is_default => 0, type => "M", label => "Favorite Teams" },
        { is_default => 0, type => "M", label => "Favorite Sports" },
        { is_default => 0, type => "S", label => "Favorite Radio Station" },
        { is_default => 0, type => "M", label => "Favorite Bands" },
        { is_default => 0, type => "M", label => "Favorite Music" },
        { is_default => 0, type => "M", label => "Favorite Newspapers" },
        { is_default => 0, type => "M", label => "Favorite Organizations" },
        { is_default => 0, type => "M", label => "Favorite Podcasts" },
        { is_default => 0, type => "M", label => "Favorite Quotes" },
        { is_default => 0, type => "S", label => "Employer" },
        { is_default => 1, type => "M", label => "Hobbies" },
        { is_default => 0, type => "M", label => "Languages I Speak" },
        { is_default => 1, type => "M", label => "Fields of Study" },
        { is_default => 0, type => "S", label => "Hometown" },
        { is_default => 1, type => "M", label => "Student Groups" },
        { is_default => 0, type => "S", label => "Birthday" },
        { is_default => 0, type => "S", label => "Blog URL" },
        { is_default => 1, type => "S", label => "Website URL" },
        { is_default => 0, type => "S", label => "Photo Gallery URL" },
        { is_default => 0, type => "S", label => "MySpace Profile" },
        { is_default => 0, type => "S", label => "Facebook Profile" },
        { is_default => 0, type => "S", label => "Flickr Stream" },
        { is_default => 0, type => "S", label => "Picasa Gallery" },
        { is_default => 0, type => "S", label => "Google Account" },
        { is_default => 0, type => "S", label => "Foursquare Account" },
        { is_default => 0, type => "S", label => "Github Account" },
        { is_default => 0, type => "S", label => "YouTube Account" },
        { is_default => 0, type => "S", label => "Vimeo Account" },
        { is_default => 0, type => "S", label => "StackExchange Account" },
        { is_default => 0, type => "S", label => "Wikipedia Userpage" },
        { is_default => 0, type => "S", label => "World of Warcraft Profile" },
        { is_default => 0, type => "S", label => "Steam Profile" },
        { is_default => 0, type => "S", label => "Goodreads Profile" },
        { is_default => 0, type => "S", label => "Last.Fm Account" },
        { is_default => 0, type => "S", label => "Tumblr Account" },
        { is_default => 0, type => "S", label => "Pinterest Account" },
        { is_default => 0, type => "S", label => "LinkedIn Account" },
        { is_default => 0, type => "S", label => "Reddit Account" },
        { is_default => 0, type => "S", label => "Amazon Wishlist" },
        { is_default => 0, type => "S", label => "Delicious Account" },
        { is_default => 0, type => "S", label => "Educause Account" },
        { is_default => 0, type => "S", label => "Nickname" },
        { is_default => 0, type => "M", label => "Email Addresses" },
        { is_default => 0, type => "S", label => "Twitter Username" },
        { is_default => 0, type => "S", label => "Identi.ca Username" },
        { is_default => 0, type => "S", label => "AOL Instant Messenger Username" },
        { is_default => 0, type => "S", label => "Yahoo IM" },
        { is_default => 0, type => "S", label => "ICQ" },
        { is_default => 0, type => "S", label => "Windows Live Username" },
        { is_default => 0, type => "S", label => "Jabber Username" },
        { is_default => 0, type => "S", label => "XMPP Username" },
        { is_default => 0, type => "S", label => "Skype Username" },
        { is_default => 0, type => "S", label => "Screen Name" }
    );

    if ($self->app->m->resultset('MeritCommons::Model::Profile::StandardAttribute')->count == 0) {
        foreach my $profile_attribute (@profile_attributes) {

            # Create a immutable key based on the label that will be used for lookups, where specific
            # attributes are used for specific functions
            my $key = $profile_attribute->{label};
            $key =~ s/ - /_/g;             # Replace all " - " with "_"
            $key =~ s/[^A-Za-z0-9]/_/g;    # Replace all non-alphanumericals with _
            $key = lc($key);
            $profile_attribute->{k} = $key;
            $self->app->m->resultset('MeritCommons::Model::Profile::StandardAttribute')->create($profile_attribute);
        }
    }

    my $user;

    # install the MeritCommons System User
    unless ($user = $self->app->m->resultset('User')->single({ common_name => 'MeritCommons System' })) {
        $user = $self->app->m->resultset('User')->create(
            {
                common_name       => 'MeritCommons System',
                email_address     => 'meritcommons@wayne.edu',
                userid            => 'MeritCommons',
                identity_resource => 'system:MeritCommons',
                unique_id         => $self->app->new_uuid,
            }
        );

        $self->app->add_user_index($user);

        print "[info] created user " . $user->common_name . "\n";
    }

    # install the MeritCommons System Message Stream
    my $stream;
    unless ($stream = $self->app->m->resultset('Stream')->single({ common_name => 'MeritCommons System Messages' })) {
        $stream = $self->app->m->resultset('Stream')->create(
            {
                common_name                   => 'MeritCommons System Messages',
                unique_id                     => $self->app->new_uuid,
                creator                       => $user->id,
                requires_author_authorization => 1,
                personal_outbox_user          => $user->id,
                type                          => 'system',
            }
        );

        $self->app->add_stream_index($stream);

        $self->app->m->resultset('Stream::Moderator')->create(
            {
                meritcommons_user      => $user->id,
                stream              => $stream->id,
                allow_add_moderator => 1,
                added_by            => $user->id,
            }
        );

        $self->app->m->resultset('Stream::Author')->create(
            {
                meritcommons_user => $user->id,
                stream         => $stream->id,
                authorized     => 1,
                allow_edit     => 1,
                added_by       => $user->id,
            }
        );

        # add the root collection
        $self->app->add_link_collection($user, "_top");

        # set MeritCommons System messages as the MeritCommons user's personal_outbox
        $user->personal_outbox($stream->id);
        $user->update;

        # give plugins a chance to do their thing with the new tables.
        eval { $self->app->emit(schema_deployed => $dh); };

        if (my $error = $@) {
            print "[error] found error after firing off schema_deployed event: $error\n";
        }

        print "[info] established stream " . $stream->common_name . " (" . $stream->unique_id . ")\n";
    }
}

1;
