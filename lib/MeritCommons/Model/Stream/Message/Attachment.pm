#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Message::Attachment;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/+DBIx::ClassAttachment PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_message_attachment');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
        size              => 18,
    },
    message => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
        is_nullable    => 1,
        size           => 18,
    },
    uploader => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
);

# Attachment configuration
__PACKAGE__->has_attachment(
    'file',
    {
        'thumbnail' => [
            {
                'thumbnail' => {
                    'geometry' => '64x64^',
                },
            },
            {
                'extent' => {
                    'geometry' => '64x64',
                    'gravity'  => 'center',
                },
            },
        ],
        'large' => [
            {
                'resize' => {
                    'geometry' => '500x',
                },
            },
        ],
        'medium' => [
            {
                'resize' => {
                    'geometry' => '220x',
                },
            },
        ],
        'small' => [
            {
                'resize' => {
                    'geometry' => '64x',
                },
            },
        ],
    }
);

# set the primary key, baby
__PACKAGE__->set_primary_key('id');

# encapsulating message and author
__PACKAGE__->belongs_to(message  => 'MeritCommons::Model::Stream::Message');
__PACKAGE__->belongs_to(uploader => 'MeritCommons::Model::User');

sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    unless ($self->is_column_changed('pretty_size')) {
        $self->pretty_size(format_bytes($self->size));
    }

    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}
