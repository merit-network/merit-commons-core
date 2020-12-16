#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package DBIx::Attachment;

use File::Path qw(make_path remove_tree);
use Carp qw(croak);
use Image::Magick;
use Digest::MD5 qw(md5_hex);
use feature qw/switch/;
use File::MimeInfo::Magic;
use Number::Bytes::Human 'format_bytes';
use Data::Dumper;
use IO::File;
use Image::EXIF;

sub new {
    my ($class, $name, $dbix_attachment) = @_;

    my $self = {
        name            => $name,
        dbix_attachment => $dbix_attachment,
        file            => undef,
    };

    bless $self, $class;
    return $self;
}

sub styles {
    my ($self) = @_;
    my %styles = $self->{dbix_attachment}->attachment_definitions;
    return $styles{ $self->{name} };
}

sub delete {
    my ($self) = @_;

    # Update the DBIx attributes
    my $method_name = $self->{name} . "_name";
    $self->{dbix_attachment}->$method_name(undef) if $self->{dbix_attachment}->can($method_name);

    $method_name = $self->{name} . "_size";
    $self->{dbix_attachment}->$method_name(undef) if $self->{dbix_attachment}->can($method_name);

    $method_name = $self->{name} . "_content_type";
    $self->{dbix_attachment}->$method_name(undef) if $self->{dbix_attachment}->can($method_name);

    $method_name = $self->{name} . "_modify_time";
    $self->{dbix_attachment}->$method_name(time) if $self->{dbix_attachment}->can($method_name);

    $method_name = $self->{name} . "_pretty_size";
    $self->{dbix_attachment}->$method_name(undef) if $self->{dbix_attachment}->can($method_name);

    # queue the attachment file path to be deleted only after an update on the DBIx record is invoked
    if (!defined($self->{dbix_attachment}->post_commit_delete_paths)) {
        $self->{dbix_attachment}->post_commit_delete_paths([]);
    }

    push(@{ $self->{dbix_attachment}->post_commit_delete_paths }, $self->attachment_path);

    return 1;
}

# File setter
sub file {
    my ($self, $file) = @_;

    if (defined($file)) {
        if ($file->size > 0) {

            # Stash the file object (to be saved to the filesystem after a successful insert)
            $self->{file} = $file;

            my $mime_type = $file->headers->content_type;

            # do some processing here on the file name
            my $attachment_file_name = $self->{file}->filename;
            if ($attachment_file_name =~ /[\(\"\'\<\>\\]/) {
                my ($pfx, $ext) = $attachment_file_name =~ /^(.+?)\.(\w+)$/;
                $attachment_file_name = md5_hex($attachment_file_name) . ".$ext";
            }

            # Update the DBIx attributes
            my $method_name = $self->{name} . "_name";
            $self->{dbix_attachment}->$method_name($attachment_file_name)
              if $self->{dbix_attachment}->can($method_name);

            $method_name = $self->{name} . "_size";
            $self->{dbix_attachment}->$method_name($self->{file}->size)
              if $self->{dbix_attachment}->can($method_name);

            $method_name = $self->{name} . "_content_type";
            $self->{dbix_attachment}->$method_name($mime_type) if $self->{dbix_attachment}->can($method_name);

            $method_name = $self->{name} . "_modify_time";
            $self->{dbix_attachment}->$method_name(time) if $self->{dbix_attachment}->can($method_name);

            $method_name = $self->{name} . "_pretty_size";
            $self->{dbix_attachment}->$method_name(format_bytes($self->{file}->size))
              if $self->{dbix_attachment}->can($method_name);
        }
    }

    return 1;
}

sub mojo_home {

    # Lazy-load and then store the mojo_home folder.  This also allows the DBIX_ATTACHMENT_HOME
    # variable to be optionally set by the program to override the default.
    if (!$ENV{DBIX_ATTACHMENT_HOME}) {
        my $home = Mojo::Home->new;
        $home->detect('DBIx::Attachment');
        $ENV{DBIX_ATTACHMENT_HOME} = $home->rel_dir('/');
    }

    return $ENV{DBIX_ATTACHMENT_HOME};
}

sub attachment_path {
    my ($self) = @_;

    # hash of ref($self->{dbix_attachment}) . $self->{dbix_attachment}->id . $self->{name}
    $ENV{MERITCOMMONS_UPLOAD_PATH} .
      '/' . md5_hex(ref($self->{dbix_attachment}) . '-' . $self->{dbix_attachment}->id . '-' . $self->{name});
}

sub style_path {
    my ($self, $style) = @_;
    return $self->attachment_path . "/" . $style;
}

sub filename {
    my ($self, $style) = @_;

    # default to original filename
    if (!defined($style)) {
        my $style = 'original';
    }

    $file_name_method = $self->{name} . "_name";
    return $self->style_path($style) . "/" . $self->{dbix_attachment}->$file_name_method;
}

# name is an alias to file name just so i can have $file->name instead of $file->filename while im putting my pin number into the atm machine.
*name = \&filename;

sub size {
    my ($self, $style) = @_;
    $file_size_method = $self->{name} . "_size";
    return $self->{dbix_attachment}->$file_size_method;
}

sub pretty_size {
    my ($self, $style) = @_;
    $file_size_method = $self->{name} . "_pretty_size";
    return $self->{dbix_attachment}->$file_size_method;
}

sub content_type {
    my ($self, $style) = @_;
    $content_type_method = $self->{name} . "_content_type";
    return $self->{dbix_attachment}->$content_type_method;
}

sub url {
    my ($self, $style) = @_;

    $file_name_method = $self->{name} . "_name";

    return $ENV{MERITCOMMONS_ASSET_BASE} .
      md5_hex(ref($self->{dbix_attachment}) . '-' . $self->{dbix_attachment}->id . '-' . $self->{name}) .
      "/$style/" . $self->{dbix_attachment}->$file_name_method;
}

sub file_exists {
    my ($self) = @_;

    # files only exist after saved, check that the record has been committed/saved
    if ($self->{dbix_attachment}->id) {
        return 1;
    } else {
        return 0;
    }
}

sub is_jpeg {
    my ($self) = @_;

    # define supported mime-types for jpegs
    my @mime_types = ('image/jpeg', 'image/pjpeg');

    if ($self->file_exists) {
        $content_type_method = $self->{name} . "_content_type";
        my $content_type = $self->{dbix_attachment}->$content_type_method;

        # return true if the content type matches a supported mime-type
        if (grep $_ eq $content_type, @mime_types) {
            return 1;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

sub exif {
    my ($self) = @_;

    if ($self->is_jpeg) {
        return new Image::EXIF($self->filename('original'));
    } else {
        return undef;
    }
}

sub is_image {
    my ($self) = @_;

    # define supported mime-types
    my @mime_types = ('image/jpeg', 'image/pjpeg', 'image/gif', 'image/png', 'image/bmp', 'image/x-windows-bmp');

    if ($self->file_exists) {
        $content_type_method = $self->{name} . "_content_type";
        my $content_type = $self->{dbix_attachment}->$content_type_method;

        # return true if the content type matches a supported mime-type
        if (grep $_ eq $content_type, @mime_types) {
            return 1;
        } else {
            return 0;
        }
    } else {
        return 0;
    }
}

# Called only after insert() is called on the DBIx::Class object.  The file should be saved
# only if the record creation was successful.  Also, we need the record ID created on insert
# in order to determine the destination file path.
sub save {
    my ($self) = @_;

    if ($self->{file}) {

        # save the original
        make_path($self->style_path('original')) unless -d $self->style_path('original');
        $self->{file}->move_to($self->filename('original'));

        my $original_image = Image::Magick->new;

        # only process styles for recognized mime-types
        if ($self->is_image) {
            my $image_read_error = $original_image->Read($self->filename('original'));

            # only process styles for images that can be read by image magick
            if (!"$image_read_error") {

                # save all of the variations of styles
                while (($style_name, $transforms) =
                    each(%{ $self->{dbix_attachment}->attachment_definitions->{ $self->{name} } })) {

                    my $image = Image::Magick->new;
                    $image->Read($self->filename('original'));

                    for my $transform (@{$transforms}) {
                        while (($transform_name, $arguments) = each %{$transform}) {

                            # process recognized transforms
                            if ($transform_name eq 'resize') {
                                $image->Resize(geometry => $arguments->{geometry});
                            } elsif ($transform_name eq 'crop') {
                                $image->Crop(geometry => $arguments->{geometry});
                            } elsif ($transform_name eq 'thumbnail') {
                                $image->Thumbnail(geometry => $arguments->{geometry});
                            } elsif ($transform_name eq 'extent') {
                                $image->Extent(geometry => $arguments->{geometry}, gravity => $arguments->{gravity});
                            }
                        }
                    }

                    make_path($self->style_path($style_name)) unless -d $self->style_path($style_name);
                    my $write_error = $image->Write($self->filename($style_name));
                    if ($write_error) {
                        ($code) = $write_error =~ /(\d+)/;
                        if ($code >= 400) {
                            warn "[error] problem writing " .
                              $self->filename($style_name) . ": $write_error, retrying\n";
                            unlink($self->filename($style_name));
                            $image->Write($self->filename($style_name));
                        }
                    }
                }
            }
        }
    }
}

1;
