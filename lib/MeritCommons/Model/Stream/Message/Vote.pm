#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Message::Vote;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_message_vote');

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
        size           => 18,
    },
    voter => {
        data_type      => 'integer',
        is_foreign_key => 1,
        is_numeric     => 1,
    },

    # signed integer containing -1, or 1
    vote => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
);

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;

    # add this result to the message's score
    my $msg = $self->message;
    $msg->score($msg->score + $self->vote);
    $msg->update();

    $self->create_time(time);
    $self->next::method(@args);
}

# set the primary key, baby
__PACKAGE__->set_primary_key('id');

# encapsulating message and author
__PACKAGE__->belongs_to(message => 'MeritCommons::Model::Stream::Message');
__PACKAGE__->belongs_to(voter   => 'MeritCommons::Model::User');

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;
}
