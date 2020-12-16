#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Helper::FileUtil;

use Mojo::Base 'Mojolicious::Plugin';
use Image::Magick;
use File::Path qw(make_path remove_tree);
use Mojo::URL;
use Mojo::Util qw/b64_decode/;

sub register {
    my ($self, $app) = @_;

    # event handlers
    $app->on(file_uploaded => \&_file_uploaded);
}

sub _file_uploaded {
    my ($app, $file, $header) = @_;

    # some config
    my $extension_map = {
        'image/png' => 'png',
        'image/gif' => 'gif',

        #'image/tiff' => 'tiff',
        'image/jpeg' => 'jpg',
    };

    my $type_map = {
        'image/png'  => [ \&__process_image ],
        'image/jpeg' => [ \&__process_image ],

        #'image/tiff' => [\&__process_image],
        'image/gif' => [ \&__process_image ],
    };

    # write the temp file out
    my $tmp_path;
    unless ($tmp_path = $app->global_config->{file_upload_tmp_path}) {
        $tmp_path = "/tmp";
    }

    # get the file extension, try mime type-based first.
    my $ext;
    unless ($ext = $extension_map->{ $header->{type} }) {

        # looks like we don't know about this type, let's get the file extension from the file
        unless (($ext) = $file =~ /\.(\w+)$/) {
            $ext = "dat";
        }
    }

    my $pg = $app->async_mojo_pg;

    my $tmp_file = $tmp_path . "/@{[$file->unique_id]}.$ext";
    if (open my $fh, '>', $tmp_file) {

        # get the data out of postgresql and write it to a temp file
        my $doc = $pg->db->query('select payload from meritcommons_async_stash where unique_id = ?', $file->unique_id)
          ->expand->hash->{payload};

        print $fh b64_decode($doc->{payload});
        close $fh;
    } else {

        # open() returned false, bubble the error up the chain.
        $pg->db->query(
            "update meritcommons_async_stash set payload = ? where unique_id = ?",
            {
                json => {
                    unique_id => "@{[$file->unique_id]}.process_file_upload",
                    success   => 0,
                    error     => "couldn't create upload temp file: $!",
                }
            },
            "@{[$file->unique_id]}.process_file_upload"
        );
        return undef;
    }

    # this is my document
    my $doc = $pg->db->query("select payload from meritcommons_async_stash where unique_id = ?",
        "@{[$file->unique_id]}.process_file_upload")->expand->hash->{payload};

    # now that we've created the temp file, dispatch to the processor by mime type
    if (my $ar = $type_map->{ $header->{type} }) {
        foreach my $sr (@$ar) {
            $doc = $sr->($app, $file, $header, $tmp_file, $doc);
        }
    } else {

        # only handle this error if there are no other plugins handling the file_uploaded event (because we can't speak to the capability of those)
        # IDEA: perhaps encourage file_uploaded handling plugins to provide some metadata about their supported mime types and create a system-wide
        # registry of supported mime types w/ their proper dispatch?
        if (scalar(@{ $app->subscribers('file_uploaded') }) == 1) {
            if (my $type = $header->{type}) {
                $doc->{error_title} = "Unsupported File Type";
                $doc->{error}       = "The file type '$type' is currently unsupported by MeritCommons";
            } else {
                $doc->{error_title} = "Unknown File Type";
                $doc->{error}       = "This type of file is not supported by MeritCommons";
            }
        }
    }

    unlink($tmp_file) if $tmp_file && -e $tmp_file;

    # if no processors set an error, it's a success
    unless ($doc->{error}) {
        $doc->{success} = 1;
    }

    $pg->db->query(
        "update meritcommons_async_stash set payload = ? where unique_id = ?",
        { json => $doc },
        "@{[$file->unique_id]}.process_file_upload"
    );
}

sub __process_image {
    my ($app, $file, $header, $tmp_file, $doc) = @_;

    my $ap;
    if ($app->external_assets_configured) {
        $ap = $app->global_config->{external_asset_path};
    } else {
        $ap = $app->global_config->{local_asset_path};
    }

    my $transform_sets = $app->global_config->{image_transforms};
    my $dt             = $app->global_config->{default_transform};

    while (my ($set_name, $set) = each %$transform_sets) {

        # new image for every operation
        my $img        = Image::Magick->new();
        my $read_error = $img->Read($tmp_file);

        # exit here on error
        if ($read_error) {
            $doc->{error_title} = "Error Reading Source Image '$header->{name}'";
            $doc->{error}       = $read_error;
            return $doc;
        }

        foreach my $transform (@$set) {
            while (my ($transform_name, $args) = each %$transform) {
                my $method_name = ucfirst($transform_name);
                my @method_args = map { $_ => $args->{$_} } keys %$args;

                # perform the transform
                my $transform_error = $img->$method_name(@method_args);
                if ($transform_error) {
                    $doc->{error_title} = "Error Running Image Transform '$method_name'";
                    $doc->{error} = ref $transform_error ? $app->dumper($transform_error) : $transform_error;
                    return $doc;
                }
            }
        }

        my $save_path = "$ap/@{[__user_dir($app, $file)]}";
        make_path($save_path);
        my $save_file   = "$save_path/@{[__fn($header, $set_name)]}";
        my $write_error = $img->Write($save_file);

        push(@{ $doc->{created} }, __fn($header, $set_name));

        if ($dt && $set_name eq $dt) {
            $doc->{canonical_url} =
              Mojo::URL->new($app->asset_base . "@{[__user_dir($app, $file)]}/@{[__fn($header, $set_name)]}");
        }

        # exit here on error
        if ($write_error) {
            $doc->{error_title} = "Error Writing Processed Image '$header->{name}'";
            $doc->{error}       = $write_error;
            return $doc;
        } else {
            my @stat = stat($save_file);

            # create the variant record.
            $file->variants->create(
                {
                    path        => $save_file,
                    size        => $stat[7],
                    url         => $app->asset_base . "@{[__user_dir($app, $file)]}/@{[__fn($header, $set_name)]}",
                    common_name => $set_name,
                }
            );
        }
    }

    # write the original
    my $img        = Image::Magick->new();
    my $read_error = $img->Read($tmp_file);

    # exit here on error
    if ($read_error) {
        $doc->{error_title} = "Error Reading Source Image '$header->{name}'";
        $doc->{error}       = $read_error;
        return $doc;
    }

    my $save_path = "$ap/@{[__user_dir($app, $file)]}";
    make_path($save_path);
    my $save_file   = "$save_path/@{[__fn($header, 'original')]}";
    my $write_error = $img->Write($save_file);

    # exit here on error
    if ($write_error) {
        $doc->{error_title} = "Error Writing Processed Image '$header->{name}'";
        $doc->{error}       = $write_error;
        return $doc;
    } else {
        my @stat = stat($save_file);

        # create the variant record.
        $file->variants->create(
            {
                path        => $save_file,
                size        => $stat[7],
                url         => $app->asset_base . "@{[__user_dir($app, $file)]}/@{[__fn($header, 'original')]}",
                common_name => 'original',
            }
        );
    }

    push(@{ $doc->{created} }, __fn($header, "original"));

    if ($dt && $dt eq "original") {
        $doc->{canonical_url} = $app->asset_base . "@{[__user_dir($app, $file)]}/@{[__fn($header, 'original')]}";
    }

    return $doc;
}

sub __user_dir {
    my ($app, $file) = @_;
    return $app->md5_hex($file->uploader->unique_id);
}

sub __fn {
    my ($header, $name) = @_;
    my ($n,      $e)    = $header->{name} =~ /^(.+?)\.(\w+)$/;
    return "$header->{uuid}-$name.$e";
}

1;
