#!/usr/bin/env perl

# we don't need to wait around for children, but let's avoid zombies eh?
$SIG{CHLD} = 'IGNORE';

# daemonize...
unless (fork) {
    while (1) {
        my $count = scalar(`df | grep s3fs | wc -l`) + 0;
        if ($count == 0) {
            # clean up old mount
            system("umount /usr/local/meritcommons/var/s3");
            
            # remount!
            system("su - meritcommons -c 's3fs static.meritcommons.wayne.edu -odefault_acl=public-read -ouid=1001 -ogid=1001 -oallow_other var/s3'");
        }
        sleep 20;
    }
}