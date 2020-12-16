#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Plugin;
use Mojo::Base 'Mojolicious::Plugin';
use File::Basename 'dirname';
use Module::Util qw/find_installed/;
use File::Spec;
use File::Path qw/make_path/;
use File::Find;
use Carp 'carp';

has tests => sub { return [] };

sub register {
    my ($self, $app) = @_;

    # Infer the plugin name by inspecting $self
    my $plugin_namespace = (ref $self);

    my (undef, $base_path, undef) = File::Spec->splitpath(find_installed($plugin_namespace));
    $base_path = $base_path . $self->plugin_class_name . "/";

    # look for and add tests.
    if (-d $base_path . 't') {
        foreach my $test_file (glob($base_path . "t/*")) {
            next if $test_file =~ /^./;
            push(@{$self->tests}, "$base_path/t/$test_file");
        }
    }

    # Add command and helper namespaces
    if (-d $base_path . 'Command') {
        push(@{ $app->commands->namespaces }, $plugin_namespace . '::Command');
    }

    if (-d $base_path . 'Helper') {
        push(@{ $app->plugins->namespaces }, $plugin_namespace . '::Helper');
    }

    unless (-d $base_path . 'Controller') {
        print "[info] nothing found matching " . $plugin_namespace . "::Controller; adding Mojolicious::Controller to \$plugin_namespace\::ISA \n" if $ENV{MERITCOMMONS_PLUGIN_DEBUG};
        no strict 'refs';
        # MeritCommons Plugins are also Mojolicious::Controllers by default.
        push @{"${plugin_namespace}::ISA"}, "Mojolicious::Controller";
    }

    # Load DBIx models that the plugin has defined
    no strict 'refs';
    my $schema_version = ${"${plugin_namespace}::SCHEMA_VERSION"};
    use strict 'refs';

    if ($schema_version) {
        if (-d $base_path . '/Model') {
            print "[info] enabling schema namespace " . $plugin_namespace . "::Model\n" if $ENV{MERITCOMMONS_PLUGIN_DEBUG};
            $app->m->load_namespaces(result_namespace => '+' . $plugin_namespace . '::Model');
        }
    }

    # register hydrant commands...
    if (-d $base_path . "/Hydrant/Command") {
        print "[info] enabling hydrant command namespace " . $plugin_namespace . "::Hydrant::Command\n"
          if $ENV{MERITCOMMONS_PLUGIN_DEBUG};
        push(@{ $app->hydrant_namespaces }, $plugin_namespace . "::Hydrant::Command");
        $self->{hydrant_command_path} = $base_path . "Hydrant/Command/";
    }

    if (-d $base_path . "/ContentDriver") {
        print "[info] enabling content driver namespace " . $plugin_namespace . "::ContentDriver\n"
          if $ENV{MERITCOMMONS_DEBUG};
        push(@{ $app->contentdriver_namespaces }, $base_path . "ContentDriver");
        $self->{content_driver_path} = $base_path . "ContentDriver/";
    }

    # Register the template path
    my $template_dir = $base_path . "assets/templates";
    if (-d $template_dir) {
        print "[info] enabling $plugin_namespace\'s templates directory '$template_dir'\n"
          if $ENV{MERITCOMMONS_PLUGIN_DEBUG};
        unshift(@{ $app->renderer->paths }, $template_dir);
        $self->{template_path} = "$template_dir/";
    }

    # register static asset paths
    my $public_dir = $base_path . "assets/public";
    if (-d $public_dir) {
        print "[info] enabling $plugin_namespace\'s static assets directory '$public_dir'\n"
          if $ENV{MERITCOMMONS_PLUGIN_DEBUG};
        unshift(@{ $app->static->paths }, $public_dir);
        $self->{public_path} = "$public_dir/";
    }

    # we all know what our name is!
    my $plugin_name     = $self->plugin_name;
    my $plugin_filename = 'etc/plugin/' . $plugin_name . '.conf';

    $self->{config_file} = $plugin_filename;

    # stash the app in here, cos why not?
    $self->{app} = $app;

    if (-e $ENV{MERITCOMMONS_HOME} . '/' . $plugin_filename) {
        print "[info] parsing and loading $plugin_namespace\'s configuration file $plugin_filename\n"
          if $ENV{MERITCOMMONS_PLUGIN_DEBUG};
        $app->plugin('MeritCommons::Config', { file => $plugin_filename, plugin => $plugin_name });
        print "[info] installing helper app->plugin_configs->$plugin_name for parsed file $plugin_filename\n"
          if $ENV{MERITCOMMONS_PLUGIN_DEBUG};
          

        # built-in plugin helpers...
        
        #
        # The plugin itself, $c->myplugin->plugin returns the plugin object!
        #
        $app->helper("$plugin_name.plugin" => sub { return $self });
        
        #
        # The plugin's base path
        #
        
        $app->helper("$plugin_name.base_path" => sub { return $base_path });
        
        #
        # Configuration helpers...
        #
        my $pc = $self->plugin_config;
        $app->helper("plugin_configs.$plugin_name" => sub { return $pc });
        
        # install a plugin_config helper in the plugin's namespace as well.
        $app->helper("$plugin_name.plugin_config" => sub { return $pc });
        $app->helper("$plugin_name.config" => sub { return $pc });
    }

    # by default provide a path to the base assets directory
    if (-d "$base_path/assets") {
        $app->helper("$plugin_name.assets_path", sub {
            return "$base_path/assets";
        });
    }

    my $md_path = $base_path . "assets/doc/markdown";

    if (-d $md_path) {
        find(
            sub {
                my $filename = $File::Find::name;
                if ($filename =~ /^\Q$md_path\E(\/.+)\.md$/i) {
                    $MeritCommons::markdown_files->{"$1/"} = $filename;
                }
            },
            $md_path
        );
    }

    if ($self->can('_register')) {
        $self->_register($app);
    }
    
    return $self;
}

sub app {
    my ($self) = @_;
    return $self->{app};
}

sub sass_files {
    my ($self) = @_;

    my @sass_files;

    if ($self->{public_path} && -d "$self->{public_path}sass") {
        my $sass_dir = $self->{public_path} . "sass";
        find(
            sub {
                my $filename = $File::Find::name;
                if ($filename =~ /$sass_dir\/(.+)\.scss$/i) {
                    push(@sass_files, "$sass_dir/$1");
                }
            },
            $sass_dir
        );
    }

    return (@sass_files);
}

sub js_files {
    my ($self) = @_;

    my @js_files;

    if ($self->{public_path} && -d "$self->{public_path}js") {
        my $js_dir = $self->{public_path} . "js";
        find(
            sub {
                my $filename = $File::Find::name;
                if ($filename =~ /$js_dir\/(.+)\.js$/i) {
                    push(@js_files, "$js_dir/$1");
                }
            },
            $js_dir
        );
    }

    return (@js_files);
}

sub plugin_class_name {
    my ($self) = @_;
    my @cc = split("::", ref($self));
    return $cc[$#cc];    # return the last
}

sub plugin_name {
    my ($self) = @_;
    return lc($self->plugin_class_name);
}

# a canonical place on the filesystem to store plugin data
sub plugin_data_dir {
    my ($self) = @_;
    unless ($self->{plugin_data_dir}) {
        $self->{plugin_data_dir} = "$ENV{MERITCOMMONS_HOME}/../var/plugins/@{[$self->plugin_name]}";
        unless (-d $self->{plugin_data_dir}) {
            make_path($self->{plugin_data_dir});
        }
    }
    return $self->{plugin_data_dir};
}

# alias for plugin_config()
sub config {
    my ($self) = @_;
    carp
      "[warn] ambiguous 'config' method called on an MeritCommons Plugin object, '@{[ref($self)]}', did you mean plugin_config or global_config?\n";
    return $self->plugin_config;
}

sub plugin_config {
    my ($self) = @_;
    if (my $config = $self->app->defaults(config => $self->app->config)->config) {
        if (my $plugin_config = $config->{_plugins}->{ $self->plugin_name }) {
            return $plugin_config;
        }
    }
    return {};
}

return 1;
