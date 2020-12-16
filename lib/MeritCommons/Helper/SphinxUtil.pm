#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Helper::SphinxUtil;
use Mojo::Base 'Mojolicious::Plugin';
use Carp qw/croak/;
use Sphinx::Search;

sub register {
    my ($self, $app) = @_;

    # install local subroutine as a helper.
    $app->helper(add_link_index                 => \&_add_link_index);
    $app->helper(add_message_index              => \&_add_message_index);
    $app->helper(add_stream_index               => \&_add_stream_index);
    $app->helper(add_user_index                 => \&_add_user_index);
    $app->helper(delete_message_index           => \&_delete_message_index);
    $app->helper(update_message_index           => \&_update_message_index);
    $app->helper(delete_link_index              => \&_delete_link_index);
    $app->helper(sphinx_delete_all_indexes      => \&_sphinx_delete_all_indexes);
    $app->helper(sphinx_delete_index            => \&_sphinx_delete_index);
    $app->helper(sphinx_rebuild_link_indexes    => \&_sphinx_rebuild_link_indexes);
    $app->helper(sphinx_rebuild_message_indexes => \&_sphinx_rebuild_message_indexes);
    $app->helper(sphinx_rebuild_stream_indexes  => \&_sphinx_rebuild_stream_indexes);
    $app->helper(sphinx_rebuild_user_indexes    => \&_sphinx_rebuild_user_indexes);
    $app->helper(search_users                   => \&_search_users);
    $app->helper(search_users_id_only           => \&_search_users_id_only);

    # get this out so we dont have to call the method erry time
    my $config = $app->config;

    # Sphinx MySQL connection
    $app->helper(
        'sphinx_dbh' => sub {
            my ($self) = @_;
            if ($config->{sphinx}) {
                return DBI->connect_cached($config->{sphinx}->{dsn});
            }
            return undef;
        }
    );

    # Sphinx connection
    $app->helper(
        'sphinx_h' => sub {

            # Establish connection to Sphinx
            my $sph;
            if ($config->{sphinx}) {
                $sph = Sphinx::Search->new();
                $sph->SetServer($config->{sphinx}->{host}, $config->{sphinx}->{port});
            } else {
                warn "[warn] Sphinx is not defined in config";
                $sph = undef;
            }

            return $sph;
        }
    );

    $app->on(
        self_check => sub {
            my ($app, $c) = @_;

            # check sphinx
            unless ($c->sphinx_h->Open) {
                $c->res->body(
                    "FAIL - @{[$c->instance_id]} - sphinx search database unavailable; application is up; please escalate to tier 2"
                );
                $c->app->log->error("self_check - sphinx unavailable!");
            }

            $c->sphinx_h->Close;
        }
    );
}

sub _delete_link_index {
    my ($self, $link) = @_;

    my $sphinx_dbh = $self->sphinx_dbh;

    # sphinxql throws an "sphinxql: syntax error, unexpected QUOTED_STRING" error when DBD tries to bind by a variable
    # As a workaround, the ID is added inline to the query, but the format is double-checked to ensure the input is sanitized
    unless ($link->id =~ /^\d+$/) {
        return;
    }

    # delete the link from the Sphinx index
    my $query = "DELETE FROM links WHERE id = " . $link->id;
    my $sth   = $sphinx_dbh->prepare($query);
    $sth->execute();

    return 1;
}

sub _add_link_index {
    my ($self, $link) = @_;

    my $sphinx_dbh = $self->sphinx_dbh;

    if (my $keywords = $link->keywords) {

        # add the link to the Sphinx index
        my $query = "INSERT INTO links (id,title,keywords) VALUES (?,?,?)";
        $sphinx_dbh->do($query, {}, $link->id, $link->title, $keywords);
    } else {
        my $query = "INSERT INTO links (id,title) VALUES (?,?)";
        $sphinx_dbh->do($query, {}, $link->id, $link->title);
    }

    return 1;
}

sub _delete_message_index {
    my ($self, $msg) = @_;

    # remove the old index
    $self->sphinx_dbh->do("DELETE FROM messages where id = @{[$msg->id]}");

    return 1;
}

sub _update_message_index {
    my ($self, $msg) = @_;

    # delete it
    $self->delete_message_index($msg);

    # re-add it
    $self->add_message_index($msg);
}

sub _add_message_index {
    my ($self, $msg) = @_;

    my $sphinx_dbh = $self->sphinx_dbh;

    # Get an array of stream ids
    my $message_streams_rs = $self->app->m->resultset('Stream::MessageStream')->search(
        {
            'me.message' => $msg->id
        }
    );
    $message_streams_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my @message_streams = $message_streams_rs->all;
    my @stream_ids = map { $_->{stream} } @message_streams;

    # Get the submitter's name
    my $user_rs = $self->app->m->resultset('User')->search(
        {
            'me.id' => $msg->get_column('submitter')
        }
    );
    $user_rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
    my $user = $user_rs->first;

    # add the message to the Sphinx index
    my $query =
      "REPLACE INTO messages (id, message_id, common_name,body,post_time,submitter,public,unique_id,stream_id) VALUES (?,?,?,?,?,?,?,?,("
      . join(",", @stream_ids) . "))";
    $sphinx_dbh->do($query, {}, $msg->id, $msg->id, $user->{common_name},
        $msg->subject ? $msg->subject . " " . $msg->original_body : $msg->original_body,
        $msg->post_time, $user->{id}, $msg->public, $msg->unique_id);

    return 1;
}

sub _add_stream_index {
    my ($self, $stream) = @_;

    my $sphinx_dbh = $self->sphinx_dbh;

    if ((!$stream->personal_inbox_user) && (!$stream->personal_outbox_user)) {
        my $keywords    = $stream->keywords;
        my $description = $stream->description;

        if ($keywords && $description) {

            # we have both, so insert both
            my $query = "REPLACE INTO streams (id, unique_id, common_name, keywords, description) VALUES (?,?,?,?,?)";
            $sphinx_dbh->do($query, {}, $stream->id, $stream->unique_id, $stream->common_name, $keywords, $description);
        } elsif ($keywords) {

            # just keywords
            my $query = "REPLACE INTO streams (id, unique_id, common_name, keywords) VALUES (?,?,?,?)";
            $sphinx_dbh->do($query, {}, $stream->id, $stream->unique_id, $stream->common_name, $keywords);
        } elsif ($description) {

            # just description
            my $query = "REPLACE INTO streams (id, unique_id, common_name, description) VALUES (?,?,?,?)";
            $sphinx_dbh->do($query, {}, $stream->id, $stream->unique_id, $stream->common_name, $description);
        } else {

            # neither.
            my $query = "REPLACE INTO streams (id, unique_id, common_name) VALUES (?,?,?)";
            $sphinx_dbh->do($query, {}, $stream->id, $stream->unique_id, $stream->common_name);
        }
    }

    return 1;
}

sub _add_user_index {
    my ($self, $user) = @_;

    my $sphinx_dbh = $self->sphinx_dbh;

    # add the message to the Sphinx index
    my $query = "REPLACE INTO users (id, userid, common_name, search_userid) VALUES (?,?,?,?)";
    $sphinx_dbh->do($query, {}, $user->id, $user->userid, $user->common_name,
        join(' ', $user->userid, (map { $_->common_name } $user->aliases), $user->email_address));

    return 1;
}

sub _search_users {
    my ($self, $sph, $search_string) = @_;

    # allow searching for email addresses by escaping the @'s
    $search_string =~ s/([^\\]+)\@/$1\\@/g;

    my $results = $sph->SetSortMode(SPH_SORT_RELEVANCE)->SetLimits(0, 200)->Query($search_string, "users");

    my @user_ids = map { $_->{doc} } @{ $results->{matches} };

    my $users = $self->app->m->resultset('User')->search(
        {
            id => \@user_ids,
        },
        {
            order_by => "common_name asc"
        }
    );

    return $users->all;
}

sub _search_users_id_only {
    my ($self, $sph, $search_string) = @_;

    # allow searching for email addresses by escaping the @'s
    $search_string =~ s/([^\\]+)\@/$1\\@/g;

    my $results = $sph->SetSortMode(SPH_SORT_RELEVANCE)->SetLimits(0, 200)->Query($search_string, "users");

    return [ map { $_->{doc} } @{ $results->{matches} } ];
}

# loop through all Sphinx indexes and delete all associated records
sub _sphinx_delete_all_indexes {
    my ($self) = @_;

    my $sphinx_dbh = $self->sphinx_dbh;

    my $row;

    my %results = ();

    my $sth = $sphinx_dbh->prepare("SHOW TABLES");

    $sth->execute();

    while ($row = $sth->fetchrow_hashref()) {
        $results{ $row->{Index} } = $self->sphinx_delete_index($row->{Index});
    }

    return %results;
}

# The upcoming beta version of Sphinx allows a more elegant method to
# delete index data (TRUNCATE), but for now, we're forced to individually delete
# index records.  Sphinx doesn't allow a mass delete either, so this method loops
# over all records and deletes them in 100 record chunks.
sub _sphinx_delete_index {
    my ($self, $index_name) = @_;

    my $sphinx_dbh = $self->sphinx_dbh;

    my $id;
    my @ids;
    my $query;
    my $row;
    my $rows_deleted = 0;

    do {
        my $sth = $sphinx_dbh->prepare("SELECT id FROM " . $index_name . " LIMIT 0,100");

        $sth->execute();

        @ids = ();
        while ($row = $sth->fetchrow_hashref()) {
            push(@ids, $row->{id});
        }

        if (@ids > 0) {
            $query = "DELETE FROM " . $index_name . " WHERE id IN (" . join(",", @ids) . ")";

            # try it again if we had some sort of transient error (which they usually are)
            eval { $sphinx_dbh->prepare($query)->execute(); };

            if (my $error = $@) {
                $sphinx_dbh->prepare($query)->execute();
                $sth->execute();
            }

            $rows_deleted = $rows_deleted + @ids;
        }
    } while (@ids > 0);

    return $rows_deleted;
}

sub _sphinx_rebuild_link_indexes {
    my ($self)     = @_;
    my $sphinx_dbh = $self->sphinx_dbh;
    my $count      = 0;

    my $links = $self->app->rorm->resultset('MeritCommons::Model::Link')->search();

    while (my $link = $links->next) {
        $self->add_link_index($link);
        $count++;
    }

    return $count;
}

sub _sphinx_rebuild_message_indexes {
    my ($self)     = @_;
    my $sphinx_dbh = $self->sphinx_dbh;
    my $count      = 0;

    my $messages = $self->app->rorm->resultset('MeritCommons::Model::Stream::Message')->search();

    while (my $msg = $messages->next) {
        $self->add_message_index($msg);
        $count++;
    }

    return $count;
}

sub _sphinx_rebuild_stream_indexes {
    my ($self)     = @_;
    my $sphinx_dbh = $self->sphinx_dbh;
    my $count      = 0;

    my $streams = $self->app->rorm->resultset('MeritCommons::Model::Stream')->search();

    while (my $stream = $streams->next) {

        # Don't index streams with names that start with _
        if ($stream->common_name !~ /^_/) {
            $self->add_stream_index($stream);
            $count++;
        }
    }

    return $count;
}

sub _sphinx_rebuild_user_indexes {
    my ($self)     = @_;
    my $sphinx_dbh = $self->sphinx_dbh;
    my $count      = 0;

    my $users = $self->app->rorm->resultset('MeritCommons::Model::User')->search();

    while (my $user = $users->next) {
        $self->add_user_index($user);
        $count++;
    }

    return $count;
}

1;
