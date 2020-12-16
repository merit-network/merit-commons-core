#!/usr/bin/env perl

use IO::Prompt;
use Time::HiRes;
use Term::ANSIColor;
use Term::ProgressBar;
use Crypt::Digest 'digest_file';
use POSIX 'strftime';
use File::Find;
use Cwd;
use Getopt::Long qw/GetOptions :config no_auto_abbrev no_ignore_case/;

GetOptions(
    'a|diff-all' => \my $diff_all,
    'c|diff-config' => \my $diff_config,
    'h|help' => \my $help,
    'no-backup' => \my $no_backup,
    'core-only' => \my $core_only,
    'n|no-diff' => \my $no_diff,
    'q|quiet' => \my $quiet,
    's|summary-only' => \my $summary_only,
    'b|customer-base=s' => \my $base,
    'e|customer-environment=s' => \my $env,
    'o|core-branch=s' => \my $core_branch,
    'p|plugins-branch=s' => \my $plugins_branch,
    'u|customizations-branch=s' => \my $customizations_branch,
    'v|verbose' => \$ENV{PREPARE_MERITCOMMONS_VERBOSE},
);


# Implied defaults
if ($summary_only) {
    $diff_all = 1;
}

# all overrides config.
if ($diff_all) {
    $diff_config = 0;
}

# can't be verbose and quiet at the same time
if ($quiet) {
    $ENV{PREPARE_MERITCOMMONS_VERBOSE} = 0;
}

print "Prepare MeritCommons Environment\n" unless $quiet;
print "(c) 2016-2017 Detroit Collaboration Works, LLC\n\n" unless $quiet;

if ($help) {
    print usage();
    exit;
}

# set up environment if one is defined locally
if (-e ".prepare_meritcommons_env") {
    foreach my $line (`bash -norc -noprofile -c '. .prepare_meritcommons_env; env'`) {
        chomp($line);
        my ($k, $v) = split(/=/, $line);
        $ENV{$k} = $v;
    }
}

# things have to be just right or we don't do a damn thing.
unless ($core_only) {
    unless ($base //= $ENV{MERITCOMMONS_CUSTOMER_BASE}) {
        warn color('bold red');
        warn "[fatal] MERITCOMMONS_CUSTOMER_BASE environment variable not set, please set to\n";
        warn "        something like git\@git.meritcommons.io:wayne-state, or use the\n";
        die  "        @{[color('bold cyan')]}--customer-base@{[color('bold red')]} command line option @{[color('reset')]}\n";
    }
}

unless ($core_only) {
    unless ($env //= $ENV{MERITCOMMONS_CUSTOMER_ENVIRONMENT}) {
        warn color('bold red');
        warn "[fatal] MERITCOMMONS_CUSTOMER_ENVIRONMENT variable not set, please set to\n";
        warn "        something like 'production' or 'development', or use the\n";
        die  "        @{[color('bold cyan')]}--customer-environment@{[color('bold red')]} command line option @{[color('reset')]}\n";
    }
}

unless ($core_branch //= $ENV{MERITCOMMONS_CORE_BRANCH}) {
    warn color('bold red');
    warn "[fatal] MERITCOMMONS_CORE_BRANCH variable not set, please set to something\n";
    warn "        like 'release-2016.09', 'latest-release', 'master', or use \n";
    die  "        the @{[color('bold cyan')]}--core-branch@{[color('bold red')]} command line option @{[color('reset')]}\n";
}

#
# these are optional
#
unless ($plugins_branch //= $ENV{MERITCOMMONS_PLUGINS_BRANCH}) {
    print "@{[color('bold white')]}\[info] defaulting plugins branch from core branch '$core_branch'@{[color('reset')]}\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
    $plugins_branch = $core_branch;
}

unless ($customizations_branch = $ENV{MERITCOMMONS_CUSTOMIZATIONS_BRANCH}) {
    print "@{[color('bold white')]}\[info] defaulting customizations branch to 'master'@{[color('reset')]}\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
    $customizations_branch = 'master';
}

print "\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};

my $cwd = getcwd;
unless ($quiet) {
    unless ($cwd eq "/usr/local/meritcommons") {
        unless (prompt("prepare_meritcommons.pl being run from outside /usr/local/meritcommons ($cwd), run anyway? [y/N] ", -yn1td=>"n")) {
            print color('red');
            print "User aborted\n";
            print color('reset');
            exit;
        }
    }
}

my $start_time = Time::HiRes::time();

# let's figure out the latest tag and latest branch first...
my $latest = {};
my @output = `git ls-remote git\@git.meritcommons.io:meritcommons/core.git`;

foreach my $line (@output) {
    my ($hash, $name) = split(/\s+/, $line);
    if ($name =~ /^refs\/heads\/(release\-(\d+)\.(\d+)\.*(?:hf(\d*))*)$/) {
        my $vers = "$2$3";
        if ($4) {
            $vers .= ".$4";
        }

        # two cases where we evict the latest branch.
        if (!$latest->{branch} || $latest->{branch}->{vers} < $vers) {
            $latest->{branch} = {
                vers => $vers,
                name => $1,
            };
        }
    } elsif ($name =~ /^refs\/tags\/((\d+)\.(\d+)\.*(?:hf(\d*))*)$/) {
        my $vers = "$2$3";
        if ($4) {
            $vers .= ".$4";
        }
        if (!$latest->{tag} || $latest->{tag}->{vers} < $vers) {
            $latest->{tag} = {
                vers => $vers,
                name => $1,
            };
        }
    }
}

# pull them out of the 'latest' hr.
my $latest_branch = $latest->{branch}->{name};
my $latest_tag = $latest->{tag}->{name};

unless ($quiet) {
    print "Deployment Summary\n";
    print "-------------------------------------------------\n";
    print "Deploy Target          : $cwd\n";
    
    # show actual branch in summary if "latest-release" is specified
    if ($core_branch eq "latest-release") {
        print "Branch (Core)          : $core_branch ($latest_branch)\n";
    } else {
        print "Branch (Core)          : $core_branch\n";
    }
    
    # show actual
    if ($plugins_branch eq "latest-release") {
        print "Branch (Plugins)       : $plugins_branch ($latest_branch)\n";
    } else {
        print "Branch (Plugins)       : $plugins_branch\n";
    }
    
    if ($core_only) {
        print "Branch (Customizations): DISABLED\n";
    } else { 
        print "Branch (Customizations): $customizations_branch\n";
    }
    
    print "Environment            : $env\n";
    print "From Base              : $base\n\n";
}

my $pbar = Term::ProgressBar->new({name => 'Downloading', count => 20, remove => 1}) unless $ENV{PREPARE_MERITCOMMONS_VERBOSE};

my $tmp_dir = "$cwd/.deploy_tmp_$$";
system("mkdir $tmp_dir");

# we're only operating on release branches here, but sub out
# latest-release for the latest branch
if ($core_branch eq "latest-release") {
    if ($ENV{PREPARE_MERITCOMMONS_VERBOSE}) {
        print color('bold white');
        print "[latest] subbing in latest branch $latest_branch for latest-release in core-branch\n";
        print color('reset');
    }
    $core_branch = $latest_branch;
}

if ($plugins_branch eq "latest-release") {
    if ($ENV{PREPARE_MERITCOMMONS_VERBOSE}) {
        print color('bold white');
        print "[latest] subbing in latest branch $latest_branch for latest-release in plugins-branch\n";
        print color('reset');
    }
    $plugins_branch = $latest_branch;
}

print "\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};

# dont stay at zero too long
$pbar->update(2) unless $ENV{PREPARE_MERITCOMMONS_VERBOSE};

# clone core
print "[core]\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
system("git clone @{[!$ENV{PREPARE_MERITCOMMONS_VERBOSE} && '-q']} git\@git.meritcommons.io:meritcommons/core.git $tmp_dir/meritcommons");
unless ($core_branch eq "master") {
    chdir("$tmp_dir/meritcommons");
    system("git fetch -q origin $core_branch");
    system("git checkout -q $core_branch");
    chdir($cwd);
}

$pbar->update(14) unless $ENV{PREPARE_MERITCOMMONS_VERBOSE};

# clone plugins
print "\n[plugins]\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
system("git clone @{[!$ENV{PREPARE_MERITCOMMONS_VERBOSE} && '-q']} git\@git.meritcommons.io:meritcommons/plugins.git $tmp_dir/plugins");
unless ($plugins_branch eq "master") {
    chdir("$tmp_dir/plugins");
    system("git fetch -q origin $plugins_branch");
    system("git checkout -q $plugins_branch");
    chdir($cwd);
}

$pbar->update(17) unless $ENV{PREPARE_MERITCOMMONS_VERBOSE};

# clone environment config
print "\n[$env]\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
system("git clone @{[!$ENV{PREPARE_MERITCOMMONS_VERBOSE} && '-q']} $base/$env.git $tmp_dir/chosen_env");
$pbar->update(19) unless $ENV{PREPARE_MERITCOMMONS_VERBOSE};

unless ($core_only) {
    print "\n[customizations]\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
    system("git clone @{[!$ENV{PREPARE_MERITCOMMONS_VERBOSE} && '-q']} $base/common.git $tmp_dir/client_common");
    unless ($customizations_branch eq "master") {
        chdir("$tmp_dir/client_common");
        system("git fetch -q origin $customizations_branch");
        system("git checkout -q $customizations_branch");
        chdir($cwd);
    }
    print "\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
}

$pbar->update(20) unless $ENV{PREPARE_MERITCOMMONS_VERBOSE};

unless ($quiet || $no_diff) {
    # allow users to see a diff of what changed
    if (-d "$cwd/meritcommons" || -d "$cwd/plugins") {
        my $summary_answer;
        if ($diff_all) {
            $summary_answer = 'a';
        } elsif ($diff_config) {
            $summary_answer = 'c';
        } else {
            # prompt for it
            $summary_answer = lc(prompt("Would you like to see a diff of changes? [a]ll/[C]onfig only/[n]o thanks ", -t1d=>'C'));
            print "\n";
        }
        my $config_changed;
        unless ($summary_answer eq "n") {
            if ($summary_answer eq "a" || $summary_answer eq "c") {
                my (%flaa, %flap, %flba, %flbp);
                my ($unchanged, $changed, $added, $removed) = (0, 0, 0, 0);
                if ($summary_answer eq "a") {
                    if (-d "$cwd/meritcommons") {
                        find(
                            sub {
                                my $file = $File::Find::name;
                                return if $file =~ /\.git/;
                                my ($rel_file) = $file =~ qr|^\Q$cwd/meritcommons/\E(.+)$|;
                                $flaa{$rel_file} = $file;
                            },
                            "$cwd/meritcommons"
                        );
                    }
                    if (-d "$cwd/plugins") {
                        find(
                            sub {
                                my $file = $File::Find::name;
                                return if $file =~ /\.git/;
                                my ($rel_file) = $file =~ qr|^\Q$cwd/plugins/\E(.+)$|;
                                $flap{$rel_file} = $file;
                            },
                            "$cwd/plugins"
                        );
                    }
                    if (-d "$tmp_dir/meritcommons") {
                        find(
                            sub {
                                my $file = $File::Find::name;
                                return if $file =~ /\.git/;
                                my ($rel_file) = $file =~ qr|^\Q$tmp_dir/meritcommons/\E(.+)$|;
                                $flba{$rel_file} = $file;
                            },
                            "$tmp_dir/meritcommons"
                        );
                    }
                    unless ($core_only) {
                        # overlay common
                        if (-d "$tmp_dir/client_common/meritcommons") {
                            find(
                                sub {
                                    my $file = $File::Find::name;
                                    return if $file =~ /\.git/;
                                    my ($rel_file) = $file =~ qr|^\Q$tmp_dir/client_common/meritcommons/\E(.+)$|;
                                    $flba{$rel_file} = $file;
                                },
                                "$tmp_dir/client_common/meritcommons"
                            );
                        }
                    }

                    # now plugins
                    if (-d "$tmp_dir/plugins") {
                        find(
                            sub {
                                my $file = $File::Find::name;
                                return if $file =~ /\.git/;
                                my ($rel_file) = $file =~ qr|^\Q$tmp_dir/plugins/\E(.+)$|;
                                $flbp{$rel_file} = $file;
                            },
                            "$tmp_dir/plugins"
                        );
                    }

                    unless ($core_only) {
                        # overlay common
                        if (-d "$tmp_dir/client_common/plugins") {
                            find(
                                sub {
                                    my $file = $File::Find::name;
                                    my ($rel_file) = $file =~ qr|^\Q$tmp_dir/client_common/plugins/\E(.+)$|;
                                    $flbp{$rel_file} = $file;
                                },
                                "$tmp_dir/client_common/plugins"
                            );
                        }
                    }
                }

                # base config (we would have already gotten this above if we had chosen 'all' but it doesn't matter
                if (-d "$cwd/meritcommons/etc") {
                    find(
                        sub {
                            return if $file =~ /\.git/;
                            my $file = $File::Find::name;
                            my ($rel_file) = $file =~ qr|^\Q$cwd/meritcommons/\E(.+)$|;
                            $flaa{$rel_file} = $file;
                        },
                        "$cwd/meritcommons/etc"
                    );
                }

                # environment config
                if (-d "$tmp_dir/chosen_env/meritcommons/etc") {
                    find(
                        sub {
                            my $file = $File::Find::name;
                            my ($rel_file) = $file =~ qr|^\Q$tmp_dir/chosen_env/meritcommons/\E(.+)$|;
                            $flba{$rel_file} = $file;
                        },
                        "$tmp_dir/chosen_env/meritcommons/etc"
                    );
                }

                # scan for what changed..
                foreach my $key (sort {$a cmp $b} keys %flaa) {
                    if (exists $flba{$key}) {
                        if (-d $flaa{$key} && -d $flba{$key}) {
                            unless ($summary_only) {
                                print " ** UNCHANGED: meritcommons/$key\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
                            }
                            ++$unchanged;
                        } elsif (-l $flaa{$key} && -l $flba{$key}) {
                            unless ($summary_only) {
                                print " ** UNCHANGED: meritcommons/$key\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
                            }
                            ++$unchanged;
                        } elsif (-f $flaa{$key} && -f $flba{$key}) {
                            if (digest_file('SHA256', $flaa{$key}) eq digest_file('SHA256', $flba{$key})) {
                                unless ($summary_only) {
                                    print " ** UNCHANGED: meritcommons/$key\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
                                }
                                ++$unchanged;
                            } else {
                                unless ($summary_only) {
                                    print " ** CHANGED  : meritcommons/$key\n";
                                    system("colordiff $flaa{$key} $flba{$key}");
                                }
                                if ($key =~ /etc\//) {
                                    $config_changed = 1;
                                }
                                ++$changed;
                            }
                        }
                    } else {
                        unless ($summary_only) {
                            print " -- REMOVED  : meritcommons/$key\n";
                        }
                        if ($key =~ /etc\//) {
                            $config_changed = 1;
                        }
                        ++$removed;
                    }
                }

                foreach my $key (sort {$a cmp $b} keys %flap) {
                    if (exists $flbp{$key}) {
                        if (-d $flap{$key} && -d $flbp{$key}) {
                            unless ($summary_only) {
                                print " ** UNCHANGED: plugins/$key\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
                            }
                            ++$unchanged;
                        } elsif (-l $flap{$key} && -l $flbp{$key}) {
                            unless ($summary_only) {
                                print " ** UNCHANGED: plugins/$key\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
                            }
                            ++$unchanged;
                        } elsif (-f $flap{$key} && -f $flbp{$key}) {
                            if (digest_file('SHA256', $flap{$key}) eq digest_file('SHA256', $flbp{$key})) {
                                unless ($summary_only) {
                                    print " ** UNCHANGED: plugins/$key\n" if $ENV{PREPARE_MERITCOMMONS_VERBOSE};
                                }
                                ++$unchanged;
                            } else {
                                unless ($summary_only) {
                                    print " ** CHANGED  : plugins/$key\n";
                                    system("colordiff $flap{$key} $flbp{$key}");
                                }
                                if ($key =~ /etc\//) {
                                    $config_changed = 1;
                                }
                                ++$changed;
                            }
                        }
                    } else {
                        unless ($summary_only) {
                            print " -- REMOVED  : plugins/$key\n";
                        }
                        ++$removed;
                    }
                }

                foreach my $key (sort {$a cmp $b} keys %flba) {
                    unless (exists($flaa{$key})) {
                        unless ($summary_only) {
                            print " ++ ADDED     : meritcommons/$key\n";
                        }
                        if ($key =~ /etc\//) {
                            $config_changed = 1;
                        }
                        ++$added;
                    }
                }

                foreach my $key (sort {$a cmp $b} keys %flbp) {
                    unless (exists($flap{$key})) {
                        unless ($summary_only) {
                            print " ++ ADDED     : plugins/$key\n";
                        }
                        ++$added;
                    }
                }

                if ($summary_answer eq 'a' || $config_changed) {
                    print "Upgrade Summary: $changed file(s) changed; $unchanged file(s) unchanged; $added file(s) added; and $removed file(s) removed\n\n";
                } elsif ($summary_answer eq 'c') {
                    print color('green');
                    print "System configuration files unchanged from last deployment";
                    print color('reset');
                    print "\n\n";
                }

                if ($changed == 0 && $added == 0 && $removed == 0 && $summary_answer eq 'a') {
                    chdir($cwd);
                    system("rm -rf $tmp_dir");
                    print color('green');
                    print "Upgrade unnecessary; system and configuration current";
                    print color('reset');
                    print "\n";
                    exit();
                }

                unless (prompt("After review, still perform upgrade? [y/N] ", -yn1td=>"n")) {
                    chdir($cwd);
                    system("rm -rf $tmp_dir");
                    print color('red');
                    print "User aborted\n";
                    print color('reset');
                    exit();
                }
            }
        }
    }
}

unless ($no_backup) {
    # put the backups in var/backups
    unless (-d "$ENV{HOME}/var/backups") {
        system("mkdir -p $ENV{HOME}/var/backups");
    }

    print "\n[backup]\n" unless $quiet;
    if (-d "$cwd/meritcommons") {
        my $backup_file = "$ENV{HOME}/var/backups/meritcommons_backup-@{[strftime('%F-%I.%M.%S.%p', localtime(time))]}.tar.gz";
        print "Archiving existing meritcommons directory to $backup_file\n" unless $quiet;
        system("tar -czpf $backup_file meritcommons/");
    }

    if (-d "$cwd/plugins") {
        my $backup_file = "$ENV{HOME}/var/backups/meritcommons_plugins_backup-@{[strftime('%F-%I.%M.%S.%p', localtime(time))]}.tar.gz";
        return if $file =~ /\.git/;
        print "Archiving existing plugins directory to $backup_file\n" unless $quiet;
        system("tar -czpf $backup_file plugins/");
    }
}

if (-d "$cwd/meritcommons") {
    system("rm -rf $cwd/meritcommons");
}

if (-d "$cwd/plugins") {
    system("rm -rf $cwd/plugins");
}

system("mkdir $cwd/meritcommons");
chdir("$tmp_dir/meritcommons");
system("git archive $core_branch | tar -C $cwd/meritcommons -xf -");

system("mkdir $cwd/plugins");
chdir("$tmp_dir/plugins");
system("git archive $plugins_branch | tar -C $cwd/plugins -xf -");

unless ($core_only) {
    chdir("$tmp_dir/client_common");
    system("git archive $customizations_branch | tar -C $cwd -xf -");
}

chdir("$tmp_dir/chosen_env");
system("git archive master | tar -C $cwd -xf -");

chdir($cwd);
system("rm -rf $tmp_dir");

my $time_taken = sprintf("%.02f", Time::HiRes::time() - $start_time);
print "\n[summary]\n" unless $quiet;
print "$env environment prepared from $base in $time_taken seconds\n" unless $quiet;
print "\n";

sub usage {
    return <<"EOF";
Usage: prepare_meritcommons.pl [OPTIONS]

Prepare MeritCommons should be run from the /usr/local/meritcommons directory.  It checks for a
.prepare_meritcommons_env file from which it loads environment variables that configure the data
sources for the deployment process.  This configuration may be overidden or specified by the
Data Source Options listed below.

The preparation process will load your selected branch from git.meritcommons.io:meritcommons/core.git,
git.meritcommons.io:meritcommons/plugins.git, \$repo_base/common.git, and \$repo_base/\$env.git literal
examples might be git.meritcommons.io:example/common.git or git.meritcommons.io:example/development.git

It can then, optionally give you an overview of what has changed between the existing deployment
and the one that's being prepared.  You will be prompted for input if you did not specify any 
options for these behaviors on the command line.  If you do not use the --quiet, --no-diff, or
refuse the offer to see a diff, you will be prompted with an "are you sure" type prompt giving
you one last chance to back out.

Unless the --no-backup option is specified, backups are made of the meritcommons/ and plugins/ 
directories before the new environments are deployed.

These options are available for 'prepare_meritcommons.pl':

Switches:
    -a, --diff-all              Show diff for all files that would be changed by this prepare 
                                action, and prompt before continuing
        --no-backup             Disable backups of existing deployments

    -c, --diff-config           Show diff for only configuration files that would be changed
                                by this prepare action, and prompt before continuing
    -h, --help                  Print this help page
    -n, --no-diff               Do not prompt for, show diffs, or prompt for confirmation
    -q, --quiet                 Assume defaults to all prompts, and run the prepare actions 
                                silently.  Please note, this option overrides both the --verbose,
                                and --summary-only command line options, it also overrides the 
                                PREPARE_MERITCOMMONS_VERBOSE environment variable.  However, even 
                                with --quiet specfied, error messages will still be printed.
    -s, --summary-only          Do not print out lines noting files were added, removed, or 
                                modified, only print out summary information, also assumes
                                'yes' to all prompts
    -v, --verbose               Print out information about unchanged files

Data Source Options:
    -b, --customer-base         Specify customer repository base to deploy customizations from
                                e.g. 'git\@git.meritcommons.io:wayne-state', please note specifying 
                                this overrides the MERITCOMMONS_CUSTOMER_BASE environment variable
    -e, --customer-environment  Specify this deployment's environment, a repository with a
                                corresponding name must exist within the customer-base that 
                                contains configuration for this environment, please note 
                                specifying this option overrides the MERITCOMMONS_CUSTOMER_ENVIRONMENT
                                environment variable
    -o, --core-branch           Specify the branch of MeritCommons Core to use in this deployment,
                                'master' will always be the bleeding edge release, 'latest-release'
                                will always be the latest stable release, and you can alsp specify
                                a release by name.  e.g. release-2016.09.  Please note that 
                                specifying this option overrides the MERITCOMMONS_CORE_BRANCH 
                                environment variable
    -p, --plugins-branch        Specify the branch of the MeritCommons Core Plugins to use in this
                                deployment.  Defaults to the branch selected with core-branch.
                                Please note that specifying this option overrides the
                                MERITCOMMONS_PLUGINS_BRANCH environment variable
    -u, --customizations-branch Specify the branch of the common customizations repository to use
                                in this deployment.
        --core-only             Disables deployment customizations and rolls out the core repos
                                only
EOF
}