#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Config;

#
# The MeritCommons Config System
#

use Mojo::Base 'Mojolicious::Plugin::Config';
use File::Spec::Functions 'file_name_is_absolute';

sub register {
    my ($self, $app, $conf) = @_;

    # Config file
    my $file = $conf->{file} || $ENV{MOJO_CONFIG};
    $file ||= $app->moniker . '.' . ($conf->{ext} || 'conf');

    # Mode specific config file
    my $mode = $file =~ /^(.*)\.([^.]+)$/ ? join('.', $1, $app->mode, $2) : '';

    my $home = $app->home;
    $file = $home->rel_file($file) unless file_name_is_absolute $file;
    $mode = $home->rel_file($mode) if $mode && !file_name_is_absolute $mode;
    $mode = undef unless $mode && -e $mode;

    # Read config file
    my $config = {};
    if (-e $file) {
        $config = $self->load($file, $conf, $app);
    } elsif (!$conf->{default} && !$mode) {
        die qq{Config file "$file" missing, maybe you need to create it?\n};
    }

    # return here if we're not supposed to merge this stuff into the global structure
    return $config if $conf->{just_parse};

    # Merge (or place) everything
    $config = { %$config, %{ $self->load($mode, $conf, $app) } } if $mode;
    $config = { %{ $conf->{default} }, %$config } if $conf->{default};

    my $current = $app->defaults(config => $app->config)->config;
    if (my $ns = $conf->{namespace}) {
        $current->{$ns} = $config;
    } elsif (my $plugin_name = $conf->{plugin}) {
        $current->{_plugins}->{$plugin_name} = $config;
    } else {
        %$current = (%$current, %$config);
    }

    return $current;
}

1;
