#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

=head1 NAME

    MeritCommons::Content - Class that encapsulates a message on it's way in and out of MeritCommons

=head1 DESCRIPTION

    MeritCommons::Content is a class that encapsulates a message on it's way in and out of MeritCommons

=cut

package MeritCommons::Content;

use base qw(Class::Accessor);

=head1 FIELDS

The following fields exist for every message in MeritCommons, along with their associated accessors. 

=over 4

=item * render_as - What to render this message as. A YouTube video post? A Flickr Photo? A generic message? (default: 'generic')

=item * message_id - A UUID used to identify this message across MeritCommons installations

=item * create_time - The creation time of the message (unix time)

=item * modify_time - The last time this message was modified (unix time)

=item * post_time - When this message was posted

=item * score - The message's score (default: 0)

=item * upvotes - The current number of upvotes for this message

=item * downvotes - The current number of downvotes for this message

=item * day_hhmmss - The time this was posted, in the form "Feb 16 at 4:00PM"

=item * post_time_pretty - The time this was posted, in the form "16/02/2015 16:00:31"

=item * post_day_pretty - The day this was posted, in the form "Monday, February 16"

=item * submitter - The internal user id of the person posting this message

=item * submitter_userid - the user id of the submitter (the one users see)

=item * submitter_profile_url - URL of the submitter's profile

=item * submitter_common_name - The common name of the submitter

=item * submitter_flair - The flair shown next to the submitter's name

=item * full_body - The full length body of the message, never truncated.

=item * thread_replies - The number of replies to this message

=item * number_of_replies

=item * attempted_streams

=item * in_reply_to

=item * public - Whether or not the message is public (default: 1)

=item * body - The body of the message, with HTML markup.

=item * original_body - The body of the message as originally sent by the user.

=item * stripped_body

=item * serialized

=item * serialized_payload

=item * external_url

=item * external_unique_id - Eventually will/may be used for federated messaging

=item * thread_id

=item * streams - The streams this message belongs to

=item * submitter_profile_thumb_url

=item * submitter_profile_tiny_url

=item * seconds_since_post - The number of seconds since this was posted.

=item * read

=item * subtype - If this is a root post for a thread, blank. If it's a reply, "comment"

=item * notification_icon

=item * notification_href

=item * notification_thumb_url

=item * abbr_ago - The user-friendly display of when this was posted, shown in the message on the page (e.g. "Feb 16" or "57m")

=item * about

=item * regarding

=item * regarding_stream

=item * actor

=item * recipient

=item * thread

=item * submitter_gravatar_url

=back 

=cut

our @fields = qw/
  render_as message_id create_time modify_time post_time score upvotes downvotes day_hhmmss post_time_pretty post_day_pretty submitter
  submitter_userid submitter_profile_url submitter_common_name full_body thread_replies number_of_replies attempted_streams in_reply_to
  public body original_body stripped_body serialized serialized_payload external_url external_unique_id thread_id streams submitter_profile_thumb_url
  submitter_profile_tiny_url seconds_since_post read subtype notification_icon notification_href notification_thumb_url abbr_ago
  about regarding regarding_stream actor recipient thread submitter_gravatar_url subject submitter_mask masked read_only submitter_flair
  edited edited_on editor editor_userid editor_common_name editor_profile_url editor_profile_thumb_url editor_profile_tiny_url/;

__PACKAGE__->mk_accessors(@fields);

=head2 C<new>

  new($data);

A basic constrictor, which can take in an C<MeritCommons::Model::Stream::Message> object and convert it
to this C<MeritCommons::Content> object.

=cut

sub new {
    my ($class, $data) = @_;

    if (ref($data) eq "MeritCommons::Model::Stream::Message") {

        # copy this to another variable, we're going to convert this message to a Content object
        my $msg = $data;

        # copy the message in to the hashref
        $data = {};
        foreach my $field (@fields) {

            # Don't automatically set in_reply_to since it will fire off a query.  This value will be set manually.
            if ($msg->can($field) && ($field ne 'in_reply_to')) {
                $data->{$field} = $msg->$field;
            }
        }
        $data->{message_id} = $msg->unique_id;
        $data->{message}    = $msg;
    } elsif (!ref($data)) {
        $data = {};
    }

    my $self = bless($data, $class);
    return $self;
}

=head2 C<as_hashref>

  as_hashref();

Returns this object's data as a hashref, takes one optional argument to omit original_body from what's generated.

=cut

sub as_hashref {
    my ($self, $omit_ob) = @_;
    my $hr = {};
    foreach my $field (@fields) {
        if (exists($self->{$field})) {
            my $ref = ref($self->{$field});
            if (!$ref || $ref eq "HASH" || $ref eq "ARRAY") {
                $hr->{$field} = $self->{$field};
            }
        }
    }

    if ($omit_ob) {
        delete $hr->{original_body};
    }

    return $hr;
}

=head2 C<add_fields>

  add_fields(@fields);

Takes in an array of fieldnames and for each one, if it doesn't exist,
create it along with its accessor.

=cut

sub add_fields {
    my ($self, @fields) = @_;
    foreach my $field (@fields) {
        my $field = lc($field);

        my $found;
        foreach my $f (@fields) {
            if ($f eq $field) {
                $found = 1;
                last;
            }
        }

        unless ($found) {

            # add the field to the array, also add the accessor
            push(@fields, $field);
            __PACKAGE__->mk_accessors($field);
        }
    }
}

1;
