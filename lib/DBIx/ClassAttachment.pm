#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package DBIx::ClassAttachment;

use parent 'DBIx::Class';
use DBIx::Attachment;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use base qw(Class::Accessor);

# This accessor queues the deletion of attachment file paths after an attachment has been removed
# from the DBIx object.  The reason it's queued is because we want to delete the files only
# after the record is saved/committed, not immediately when the attachment is unset.
__PACKAGE__->mk_accessors('post_commit_delete_paths');

# Create accessors/variables that are scoped to the subclasses (an actual DBIx source,
# but not all DBIx sources combined).  This is where we'll store the definitions of the
# attachments
__PACKAGE__->mk_classdata('attachment_definitions');

# This method enhances a DBIx class with magic methods, and adds DBIx columns to support
# storing attachment properties in the database
sub has_attachment {
    my ($self, $attachment_name, $styles) = @_;

    # Initialize variable
    if (!defined($self->attachment_definitions)) {
        $self->attachment_definitions({});
    }

    $self->attachment_definitions->{$attachment_name} = $styles;

    # Add columns to support the attachment
    $self->add_columns(
        $attachment_name .
          "_name" => {
            data_type   => 'varchar',
            size        => 255,
            is_nullable => 1,
          },
        $attachment_name .
          "_size" => {
            data_type   => 'varchar',
            size        => 255,
            is_nullable => 1,
          },
        $attachment_name .
          "_pretty_size" => {
            data_type   => 'varchar',
            size        => 255,
            is_nullable => 1,
          },
        $attachment_name .
          "_content_type" => {
            data_type   => 'varchar',
            size        => 255,
            is_nullable => 1,
          },
        $attachment_name .
          "_modify_time" => {
            data_type   => 'varchar',
            size        => 255,
            is_nullable => 1,
          },
    );

    # Add a dynamically named getter/setter method for getting and initializing an attachment
    # from an uploaded Mojo file object
    *{$attachment_name} = sub {
        my ($self, $file) = @_;

        $args_count = keys @_;

        if ($args_count == 2) {

            # Setter
            if (defined($file)) {

                # A file was passed, initialize the attachment object if needed
                if (!defined($self->{attachments}{$attachment_name})) {
                    $self->{attachments}{$attachment_name} = DBIx::Attachment->new($attachment_name, $self);
                }
            } else {

                # a undefined value was sent to unset/delete the object
                # load the attachment object, only to invoke a delete on it
                my $file_name_method = $attachment_name . "_name";
                my $file_name = $self->$file_name_method if $self->can($file_name_method);
                if (defined($file_name)) {
                    $attachment = DBIx::Attachment->new($attachment_name, $self);
                    $attachment->delete;
                }

                return undef;
            }

            $self->{attachments}{$attachment_name}->file($file);
        } else {

            # Getter - initialize the attachment object
            my $file_name_method = $attachment_name . "_name";
            my $file_name = $self->$file_name_method if $self->can($file_name_method);
            if (defined($file_name)) {
                $self->{attachments}{$attachment_name} = DBIx::Attachment->new($attachment_name, $self);
            }
        }

        # For both setters/getters,
        if (defined($self->{attachments}{$attachment_name})) {
            return $self->{attachments}{$attachment_name};
        } else {
            return undef;
        }
    };
}

# post-delete hook to delete all attachment files
sub delete {
    my ($self, @args) = @_;

    if (ref($self->attachment_definitions)) {
        while (($attachment_name) = each %{ $self->attachment_definitions }) {
            if (defined($self->$attachment_name)) {
                my $path = $self->$attachment_name->attachment_path;
                remove_tree($path);
            }
        }
    }

    $self->next::method(@args);
}

# post-update hook to delete attachment files if needed
sub update {
    my ($self, @args) = @_;

    if (@{ $self->post_commit_delete_paths }) {
        for my $delete_path (@{ $self->post_commit_delete_paths }) {
            remove_tree($delete_path);
        }
    }

    # Save the files
    foreach my $attachment_name (keys %{ $self->{attachments} }) {
        $self->{attachments}->{$attachment_name}->save;
    }

    $self->next::method(@args);
}

# post-insert hook
sub insert {
    my ($self, @args) = @_;

    my $to_return = $self->next::method(@args);

    # Save the files
    foreach my $attachment_name (keys %{ $self->{attachments} }) {
        $self->{attachments}->{$attachment_name}->save;
    }

    # return the object returned by the above method call to keep hope alive.
    return $to_return;
}

1;
