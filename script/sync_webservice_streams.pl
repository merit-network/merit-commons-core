#!/usr/bin/env perl

my $sls = '/usr/local/meritcommons/meritcommons/etc/web_service_streams.txt';
open my $fh, '<', $sls or die "Can't open stream list file $sls: $!\n";
while (my $entry = <$fh>) {
    # skip comments and blank lines.
    next if $entry =~ /^#/;
    next if $entry =~ /^\s+$/;

    if ($entry =~ /^[^\s]+[\r\n]+$/) {
        # urls with no spaces get automatically synced
        system("meritcommons sync_streams_from_web_service -u $entry");
    } else {
        # if there's a space in the entry it's assumed to contain command line arguments
        system("meritcommons sync_streams_from_web_service $entry");
    }
}
close $fh;