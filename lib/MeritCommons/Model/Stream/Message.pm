#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Model::Stream::Message;

use base qw/DBIx::Class/;
use Carp qw(croak);

__PACKAGE__->load_components(qw/PK::Auto Core/);
__PACKAGE__->table('meritcommons_stream_message');

__PACKAGE__->add_columns(
    id => {
        is_auto_increment => 1,
        data_type         => 'integer',
        is_numeric        => 1,
        size              => 18,
    },
    create_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    modify_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    post_time => {
        data_type  => 'integer',
        is_numeric => 1,
    },
    submitter => {
        data_type      => 'integer',
        is_numeric     => 1,
        is_foreign_key => 1,
    },
    unique_id => {
        data_type => 'varchar',
        size      => 64,
    },
    external_unique_id => {
        data_type   => 'varchar',
        is_nullable => 1,
        size        => 255,
    },
    external_url => {
        data_type   => 'text',
        is_nullable => 1,
    },
    public => {
        data_type     => 'integer',
        is_numeric    => 1,
        default_value => 1,
    },
    in_reply_to => {
        data_type   => 'varchar',
        is_nullable => 1,
        size        => 64,
    },
    render_as => {
        data_type     => 'varchar',
        size          => 255,
        default_value => 'generic',
    },
    gizmo_code => {
        data_type   => 'text',
        is_nullable => 1,
    },
    serialized_payload => {
        data_type   => 'text',
        is_nullable => 1,
    },
    original_body => {
        data_type   => 'text',
        is_nullable => 1,
    },

    # part of the schema of "important/official" messages.
    subject => {
        data_type   => 'text',
        is_nullable => 1,
    },

    # nag interval of 0 means nag disabled
    nag_interval => {
        data_type     => 'integer',
        default_value => '0',
    },

    # serialized JSON containing all information required to 'mask' the submitter, for "official" messages
    # that take on the persona of a stream.
    submitter_mask => {
        data_type   => 'text',
        is_nullable => 1,
    },
    body => {
        data_type => 'text',
    },
    serialized => {
        data_type  => 'integer',
        is_numeric => 1,
        size       => 2,
    },
    signature => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    signed_by => {
        data_type   => 'varchar',
        size        => 255,
        is_nullable => 1,
    },
    thread_id => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 1,
    },
    score => {
        data_type     => 'integer',
        default_value => 0,
    },

    # can be thread or message.
    regarding => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 1,
    },

    # read_only flag enables or disables comments
    read_only => {
        data_type     => 'integer',
        default_value => 0,
        is_nullable   => 1,
    },

    # can only be a message.
    about => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 1,
    },
    regarding_stream => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 1,
    },
    subtype => {
        data_type   => 'varchar',
        size        => 64,
        is_nullable => 1,
    },
);

# set the primary key, baby
__PACKAGE__->set_primary_key('id');

# submitter and streams
__PACKAGE__->has_many(message_streams => 'MeritCommons::Model::Stream::MessageStream', 'message');
__PACKAGE__->many_to_many(streams => 'message_streams', 'stream');
__PACKAGE__->belongs_to(submitter => 'MeritCommons::Model::User');

# Links!
__PACKAGE__->has_many(message_links => 'MeritCommons::Model::Stream::MessageLink', 'message');
__PACKAGE__->many_to_many(links => 'message_links', 'link');

# support for gizmos (and gremlins unforch)
__PACKAGE__->might_have(gizmo       => 'MeritCommons::Model::Stream::Message::Gizmo');
__PACKAGE__->might_have(attachments => 'MeritCommons::Model::Stream::Message::Attachment');

# replies + threads
__PACKAGE__->belongs_to(
    in_reply_to => 'MeritCommons::Model::Stream::Message',
    { 'foreign.unique_id' => 'self.in_reply_to' }
);
__PACKAGE__->has_many(replies => 'MeritCommons::Model::Stream::Message', { 'foreign.in_reply_to' => 'self.unique_id' });
__PACKAGE__->has_many(
    thread_replies => 'MeritCommons::Model::Stream::Message',
    { 'foreign.thread_id' => 'self.unique_id' }
);
__PACKAGE__->has_many(
    regarding_me => 'MeritCommons::Model::Stream::Message',
    { 'foreign.regarding' => 'self.unique_id' }
);
__PACKAGE__->belongs_to(
    in_regards_to => 'MeritCommons::Model::Stream::Message',
    { 'foreign.unique_id' => 'self.regarding' }
);

# oh what a tangled web we weave.
__PACKAGE__->belongs_to(about => 'MeritCommons::Model::Stream::Message', { 'foreign.unique_id' => 'self.about' });
__PACKAGE__->has_many(about_me => 'MeritCommons::Model::Stream::Message', { 'foreign.about' => 'self.unique_id' });

__PACKAGE__->belongs_to(
    regarding_stream => 'MeritCommons::Model::Stream',
    { 'foreign.unique_id' => 'self.regarding_stream' }
);

# upboats and downvotes!
__PACKAGE__->has_many(votes => 'MeritCommons::Model::Stream::Message::Vote', 'message');

# for tags + flags
__PACKAGE__->has_many(tags => 'MeritCommons::Model::Stream::Message::Tag', 'message');

# who's watching me?
__PACKAGE__->has_many(
    watched => 'MeritCommons::Model::Stream::Message::Watcher',
    { 'foreign.target' => 'self.unique_id' }
);
__PACKAGE__->many_to_many(watchers => 'watched', 'watcher');

# change log for message
__PACKAGE__->has_many(
    changes => 'MeritCommons::Model::Stream::Message::ChangeLog',
    'message', { cascade_delete => 0, is_foreign_key_constraint => 0 }
);

# the uuids must be unique, or else.
__PACKAGE__->add_unique_constraint(['unique_id']);
__PACKAGE__->add_unique_constraint(['external_unique_id']);

# different resultset class...
__PACKAGE__->resultset_class('MeritCommons::ResultSet::Stream::Message');

# returns a hashref copy.
sub as_hashref {
    my %hash = (%{ shift->{_column_data} });
    return \%hash;
}

sub upvotes {
    my ($self) = @_;
    return $self->votes->search({ vote => '1' })->count;
}

sub downvotes {
    my ($self) = @_;
    return $self->votes->search({ vote => '-1' })->count;
}

sub link_to_stream {
    my ($self, $stream) = @_;
    foreach my $s ($self->message_streams) {
        if ($stream->id == $s->stream->id) {
            return undef;
        }
    }
    $self->message_streams->create({ stream => $stream->id });
}

sub unlink_from_stream {
    my ($self, $stream) = @_;
    foreach my $s ($self->message_streams) {
        if ($stream->id == $s->stream->id) {
            $s->delete;
            return 1;
        }
    }
    return undef;
}

sub thread_messages {
    my ($self) = @_;
    return ($self->result_source->resultset->search({ thread_id => $self->unique_id }, { prefetch => ['submitter'] }));
}

sub thread_participants {
    my ($self) = @_;

    my %participants;
    foreach my $msg ($self->thread_messages) {
        $participants{ $msg->submitter->id } = $msg->submitter;
    }
    return values %participants;
}

sub vote_participants {
    my ($self) = @_;
    return map { $_->voter } $self->votes;
}

sub like_participants {
    my ($self) = @_;
    return map { $_->voter } $self->votes({ vote => '1' });
}

sub dislike_participants {
    my ($self) = @_;
    return map { $_->voter } $self->votes({ vote => '-1' });
}

sub is_read_by {
    my ($self, $user) = @_;
    return $self->has_tag_by(_read => $user);
}

sub has_tag_by {
    my ($self, $word, $user) = @_;
    if ($self->tags->search({ meritcommons_user => $user->id, tag => "$word" })->first) {
        return 1;
    }
    return undef;
}

sub mark {
    my ($self, $word, $user) = @_;
    $self->tags->find_or_create(
        {
            meritcommons_user => $user,
            tag            => "$word",
        }
    );
}

# do this extra stuff on insert
sub insert {
    my ($self, @args) = @_;
    $self->create_time(time);
    $self->modify_time(time);
    unless ($self->is_column_changed('post_time')) {
        $self->post_time(time);
    }
    $self->next::method(@args);
}

# do this extra stuff on update
sub update {
    my ($self, @args) = @_;
    $self->modify_time(time);
    $self->next::method(@args);
}

sub sqlt_deploy_hook {
    my ($self, $sqlt_table) = @_;

    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_thread_id_idx',
        fields => ['thread_id'],
    );
    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_uuid_idx',
        fields => ['unique_id'],
    );
    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_post_time_idx',
        fields => ['post_time'],
    );
    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_modify_time_idx',
        fields => ['modify_time'],
    );
    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_render_as_idx',
        fields => ['render_as'],
    );

    # indexes for the notifications logic
    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_subtype_idx',
        fields => ['subtype'],
    );
    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_regarding_subtype_idx',
        fields => [ 'regarding', 'subtype' ],
    );

    $sqlt_table->add_index(
        name   => 'meritcommons_stream_message_external_unique_id_idx',
        fields => ['external_unique_id'],
    );
}

1;
