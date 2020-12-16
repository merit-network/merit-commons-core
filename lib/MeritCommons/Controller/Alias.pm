#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Alias;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use Carp qw/croak/;

sub list {
    my ($self) = @_;

    #make sure they're logged in
    unless ($self->active_user) {
        return $self->reply->not_found;
    }

    # get the aliases used by that user, in an array, and spit 'em out.
    my $result = $self->app->m->resultset('MeritCommons::Model::User::Alias')->search(
        {
            owner => $self->active_user->id,
        }
    );

    my @aliases;
    while (my $i = $result->next) {
        my $tmp = {};
        $tmp->{common_name}    = $i->common_name;       # the alias
        $tmp->{owner}          = $i->owner;             # who made it
        $tmp->{id}             = $i->id;                # an identifier
        $tmp->{meritcommons_user} = $i->meritcommons_user;    # alias for who?
        $tmp->{used}           = $i->used;              # used?

        push(@aliases, $tmp);
    }

    $self->stash(aliases => \@aliases);
    $self->render(template => "alias/list");
}

sub delete {
    my ($self) = @_;

    #make sure they're logged in
    unless ($self->active_user) {
        return $self->reply->not_found;
    }

    my $result = $self->app->m->resultset('MeritCommons::Model::User::Alias')->search(
        {
            id    => $self->param('id'),
            owner => $self->active_user->id,
        }
    )->first;

    my $res;
    if (defined $result) {
        $res = $result->delete();
    }

    if (defined $res) {
        $self->flash(message    => 'Deleted alias.');
        $self->flash(flash_type => 'success');
        $self->flash(button     => 1);
    } else {
        $self->flash(message    => 'Failed to delete alias.');
        $self->flash(flash_type => 'danger');
        $self->flash(button     => 1);
    }

    $self->redirect_to($self->req->headers->referrer);
}

sub add {
    my ($self) = @_;

    #make sure they're logged in
    unless ($self->active_user) {
        return $self->reply->not_found;
    }

    my $existing_alias = $self->app->m->resultset('MeritCommons::Model::User::Alias')->search(
        {
            common_name => $self->param('common_name'),
            owner       => $self->active_user->id,
        }
    )->first;

    my $meritcommons_user = $self->app->m->resultset('MeritCommons::Model::User')->search(
        {
            userid => $self->param('meritcommons_user'),
        }
    )->first;

    if ($existing_alias != undef) {

        # warn them they already are using that alias, and bail.
        $self->flash(message    => 'You\'re already using that alias.');
        $self->flash(flash_type => 'danger');
        $self->flash(button     => 1);
        $self->redirect_to($self->req->headers->referrer);
    } elsif (!$meritcommons_user) {

        # warn them the target user doesn't exist, and bail.
        $self->flash(message    => 'That user doesn\'t exist');
        $self->flash(flash_type => 'danger');
        $self->flash(button     => 1);
        $self->redirect_to($self->req->headers->referrer);
    } else {
        my $new_alias = $self->app->m->resultset('MeritCommons::Model::User::Alias')->create(
            {
                common_name    => $self->param('common_name'),
                used           => 0,
                meritcommons_user => $meritcommons_user,
                owner          => $self->active_user,
            }
        );

        $self->flash(message    => 'New alias created.');
        $self->flash(flash_type => 'success');
        $self->flash(button     => 1);
    }

    $self->redirect_to($self->req->headers->referrer);
}

sub edit {
    my ($self) = @_;

    #make sure they're logged in
    unless ($self->active_user) {
        return $self->reply->not_found;
    }

    my $res = $self->app->m->resultset('MeritCommons::Model::User::Alias')->search(
        {
            id    => $self->param('id'),
            owner => $self->active_user->id,
        }
    );

    my $existing_alias = $res->first;

    if ($res->count() == 0) {

        # warn them they already are using that alias, and bail.
        $self->flash(message    => 'That alias doesn\'t exist yet.');
        $self->flash(flash_type => 'danger');
        $self->flash(button     => 1);
        $self->redirect_to($self->req->headers->referrer);
    } elsif (!$self->param('common_name') or !$self->param('id')) {

        # Just show them the form
        $self->stash(old_name       => $existing_alias->common_name);
        $self->stash(target_user    => $existing_alias->meritcommons_user->userid);
        $self->stash(id             => $self->param('id'));
        $self->stash(target_user_cn => $existing_alias->meritcommons_user->common_name);
        $self->render(template => "alias/edit");
    } else {
        my $checking_alias = $self->app->m->resultset('MeritCommons::Model::User::Alias')->search(
            {
                common_name => $self->param('common_name'),
                owner       => $self->active_user->id,
            }
        );

        if ($checking_alias->count() > 0) {
            $self->flash(message    => 'Alias already exists.');
            $self->flash(flash_type => 'danger');
            $self->flash(button     => 1);

            $self->stash(old_name       => $existing_alias->common_name);
            $self->stash(target_user    => $existing_alias->meritcommons_user->userid);
            $self->stash(id             => $self->param('id'));
            $self->stash(target_user_cn => $existing_alias->meritcommons_user->common_name);
            $self->redirect_to($self->req->headers->referrer);
        } else {
            $existing_alias->update(
                {
                    common_name => $self->param('common_name'),
                }
            );

            $self->flash(message    => 'Alias updated');
            $self->flash(flash_type => 'success');
            $self->flash(button     => 1);

            $self->redirect_to('/alias/list');
        }
    }
}

1;
