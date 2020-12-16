#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::set_profile_pic;

use Mojo::Base 'Mojolicious::Command';
use Mojo::Asset::File;
use Mojo::Upload;
use Mojo::Headers;

has description => "Set a user's profile pic\n";
has usage       => "Usage: $0 set_profile_pic [USER] [PROFILE_PIC_FILE]\n";

sub run {
    my ($self, $username, $profile_pic_file) = @_;
    unless ($username && $profile_pic_file) {
        print $self->usage;
        return;
    }

    my $user = $self->app->user($username);

    unless ($user) {
        print "Can't find user $username!\n";
        return;
    }

    if (-e $profile_pic_file) {

        # let's fake an upload!
        my $file = Mojo::Asset::File->new(path => $profile_pic_file);
        my $upload = Mojo::Upload->new;
        $upload->asset($file);
        my @ppp = split(/\//, $profile_pic_file);
        $upload->filename($ppp[$#ppp]);

        my $headers = Mojo::Headers->new;

        # infer mime type from the file extension
        my ($ext) = $ppp[$#ppp] =~ /\.(\w+)$/;
        if ($ext = lc($ext)) {
            $headers->content_type(
                  $ext eq "jpg"  ? "image/jpeg"
                : $ext eq "jpeg" ? "image/jpeg"
                : $ext eq "png"  ? "image/png"
                : $ext eq "bmp"  ? "image/bmp"
                :                  undef
            );
        }
        $upload->headers($headers);

        $user->profile_picture($upload);
        $user->update;
    } else {
        warn "[error] file not found $profile_pic_file\n";
    }
}

1;
