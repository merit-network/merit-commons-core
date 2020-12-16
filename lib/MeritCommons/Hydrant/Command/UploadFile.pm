#    MeritCommons Portal
#    Copyright 2014 Wayne State University
#    All Rights Reserved

package MeritCommons::Hydrant::Command::UploadFile;

use Mojo::Base 'MeritCommons::Hydrant::Command';
use Mojo::Util qw/b64_encode/;

has user_activity_flag  => 1;

sub command {
    my ($self, $header, $asset) = @_;

    # make sure we're being called in binary context...
    unless (ref($header) eq "HASH" && ref($asset)) {
        $self->send("no.", "cmdresponse:error");
        $self->controller->app->log->error(
            "UploadFile, an MERITCOMMONSBINARY Hydrant Command, was called in 'text' context");
        return undef;
    }

    if ($header->{size} != $asset->size) {
        $self->controller->app->log->warn("Asset size and header size mismatch in $header->{name}; using asset size.");
    }

    my $m = $self->controller->m;

    my $uuid = $self->controller->new_uuid;

    # stash the uuid in the header, too.
    $header->{uuid} = $uuid;

    my $file = $m->resultset('File')->create(
        {
            unique_id => $uuid,
            mime_type => $header->{type},
            uploader  => $self->controller->active_user->id,
        }
    );

    # now we have our unique id, time to write it to a shared document store
    my $pg = $self->controller->async_mojo_pg;
    $pg->db->query(
        "insert into meritcommons_async_stash (unique_id, payload) VALUES (?, ?)",
        $file->unique_id,
        {
            json => {
                payload   => b64_encode($asset->slurp),
                unique_id => $file->unique_id,
            },
        },
        sub {
            my ($db, $error, $result) = @_;

            $self->controller->run_async_task(
                process_file_upload => sub {
                    my ($cmd, $doc) = @_;

                    if ($doc->{payload}->{success}) {
                        $cmd->send($doc->{payload}, "upload_file:$header->{request_id}:success");
                    } else {
                        $cmd->send($doc->{payload}, "upload_file:$header->{request_id}:error");
                    }
                },
                {
                    command  => $self,
                    priority => 3,
                    args => [ $file->unique_id, $header ],
                }
            );
        }
    );
}

1;
