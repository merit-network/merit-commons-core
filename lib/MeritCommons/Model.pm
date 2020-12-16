#    MeritCommons Portal
#    Copyright 2013-2015 Wayne State University
#    All Rights Reserved

package MeritCommons::Model;

# I am the very model of the modern MeritCommons.

use base qw/DBIx::Class::Schema/;

# versioned schemas.
our $VERSION = 10000;

# import classes underneath MeritCommons::Model namespace
__PACKAGE__->load_classes();

sub version {
    my ($self) = @_;
    return $VERSION;
}

1;
