#!/usr/bin/env perl

use v5.10;
use Mojo::Url;
use Getopt::Long qw(:config no_auto_abbrev no_ignore_case);

GetOptions(
    'chain-parameter|p=s' => \my @params,
    'help|h' => \my $help,
    'scheme|s=s' => \my $scheme,
    'trailing-slash|t' => \my $trailing_slash,
);

@params = split(/,/, join(',', @params));

if ($help) {
    print usage();
    exit;
}

my @urls = @ARGV;

if (@urls) {
    say __dester();
} else {
    print "No URLs specified!\n";
    print usage();
}

sub usage {
    return<<"EOF";

Usage: dester.pl [OPTIONS] [URL1] [URL2] [URLN] 

dester.pl (c) 2017 Michael Gregorowicz - Create properly encoded chained urls in no time flat!

These options are available for 'dester.pl':
    -p, --chain-parameter           The name of the chain parameter to use to send the user to the 
                                    next hop.  This may be specified multiple times if different
                                    chain parameters are used.  They will be used for the urls in 
                                    the same order they are specified on the command line.
                                    Some examples of chain parameters include: destination_url, back
                                    Note: if there are more URLs than chain parameters specified 
                                    then the last parameter specified is used for the remainder of
                                    the URLs.  Defaults to 'destination_url'
    -s, --scheme                    Override all schemes with this scheme for all URLs at all stages
                                    of the chain.  e.g. https to force https for all urls.
    -t, --trailing-slash            Make sure there's a trailing slash at the end of all urls.                     
    
EOF
}

sub __dester {
    my (@urls) = reverse(@urls);
    my (@params) = reverse(@params);
    my $count = $#urls;
    my $pcount = $#params;
    my ($dpn, $last, $chain_url);
    if ($count > $pcount) {
        $dpn = $params[0] // "destination_url";
    }
    
    my $i = 0;
    foreach my $u (@urls) {
        $pidx = (($count - $pcount) - $i);
        unless ($pidx >= 0 || $pidx <= $pcount) {
            $pidx = -1;
        }
        if ($i == 0) {
            my $url = __url_string($u);
            if ($count == 0) {
                return $url;
            } else {
                $last = $url;
            }
        } elsif ($i < $count) {
            $last = __url_string($u, $last, $params[$pidx] ? $params[$pidx] : $dpn);
        } else {
            $chain_url = __url_string($u, $last, $params[$pidx] ? $params[$pidx] : $dpn);
            my $url = Mojo::URL->new($u);
        }
        $i++;
    }

    return $chain_url;
}

sub __url_string {
    my ($url, $prev_url, $pn) = @_;
    $url = Mojo::URL->new($url);
    $url->scheme($scheme) if $scheme && $url->host;
    if ($trailing_slash) {
        unless ($url->path =~ /\/$/) {
            $url->path("@{[$url->path]}/");   
        }
    }
    if ($prev_url && $pn) {
        $url->query([$pn => $prev_url]);
    }
    return $url->to_string;
}