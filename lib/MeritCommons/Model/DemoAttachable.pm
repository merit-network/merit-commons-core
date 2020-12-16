#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::DemoAttachable;

# Define the ISA order to ensure the "update" methods are called in the right sequence
our @ISA;

use Carp qw(croak);
use base qw(DBIx::Class);

__PACKAGE__->load_components(qw/+DBIx::ClassAttachment PK::Auto Core/);
__PACKAGE__->table('meritcommons_demo_attachable');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
        is_nullable       => 0,
    },
    create_time => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 0,
    },
    modify_time => {
        data_type   => 'integer',
        is_numeric  => 1,
        is_nullable => 0,
    },
    title => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
);

__PACKAGE__->set_primary_key('id');

# Attachment configuration
__PACKAGE__->has_attachment(
    'attachment1',
    {
        'thumbnail' => [
            { 'thumbnail' => { 'geometry' => '64x64^' } },
            { 'extent'    => { 'geometry' => '64x64', 'gravity' => 'center' } }
        ],
        'large'  => [ { 'resize' => { 'geometry' => '500x500' } } ],
        'medium' => [ { 'resize' => { 'geometry' => '250x250' } } ],
        'small'  => [ { 'resize' => { 'geometry' => '125x125' } } ],
    }
);

__PACKAGE__->has_attachment('attachment2', {});
__PACKAGE__->has_attachment('attachment3', {});

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    $self->next::method(@args);
}

1;
