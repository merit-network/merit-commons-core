#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::sync_assets_to_external;

use Mojo::Base 'Mojolicious::Command';

has description => "Sync all local assets to the external system\n";
has usage       => "Usage: $0 sync_assets_to_external\n";

sub run {
    my ($self) = @_;

    my $external_asset_path = $self->app->config->{external_asset_path};
    my $external_asset_base = $self->app->config->{external_asset_base};
    my $local_asset_path    = $self->app->config->{local_asset_path};

    if ($external_asset_path && $external_asset_base) {
        print "[info] syncing local assets to $external_asset_base...\n";

        # rsync base, plugins will show up last and overlay.
        foreach my $path (reverse @{ $self->app->static->paths }) {
            if (-d $path) {
                print "   ... syncing assets in: $path/\n";
                system("rsync -r --inplace --exclude .svn --exclude .git '$path/' '$external_asset_path/'");
            }
        }
        print " ... done!\n\n";
    } else {
        print "[error] can't sync; no external asset provider configured.\n";
    }
}

1;
