#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Profile;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON qw/to_json/;
use Carp qw/croak/;

sub show {
    my ($self) = @_;

    # gzip these as they may be quite large
    $self->stash(gzip => 1);

    # If the user isn't logged in, jsut show a 404. Otherwise get the profile user
    my $profile_user;
    if ($self->active_user) {
        $profile_user = $self->user($self->stash('user'));
    } else {
        return $self->reply->not_found;
    }

    # If the user was found, show them, but if not, show a generic sort of
    # "user doesn't exist" page.
    unless (!$profile_user) {
        my $profile_attributes = $self->app->m->resultset('MeritCommons::Model::User::Profile::Attribute')->search(
            {
                'user_attribute.meritcommons_user' => $profile_user->id,
            },
            {
                join     => 'user_attribute',
                order_by => [ 'attr_group', 'label', 'id' ]
            }
        );

        my @payload_messages =
          $self->app->single_stream_messages($self->active_user, $profile_user->personal_outbox, 25);

        $self->stash(
            alt_title_link => { href => "/u/" . $profile_user->userid . "/", title => $profile_user->common_name });
        $self->stash(profile_user          => $profile_user);
        $self->stash(profile_attributes    => $profile_attributes);
        $self->stash(payload_messages      => \@payload_messages);
        $self->stash(payload_messages_json => to_json(\@payload_messages));
        $self->render(template => "profile/show");
    } else {
        $self->render(template => "profile/user_not_found");
    }

}

sub edit {
    my ($self) = @_;

    if ($self->active_user) {
        my $profile_user = $self->user($self->stash('user'));

        unless ($profile_user->id == $self->active_user->id) {
            croak "[error]: user does not have access to edit profile\n";
        }

        my $profile_attributes = $self->app->m->resultset('MeritCommons::Model::User::Profile::Attribute')->search(
            {
                'user_attribute.meritcommons_user' => $self->active_user->id,
            },
            {
                join     => 'user_attribute',
                order_by => [ 'attr_group', 'label' ]
            }
        );

        my @profile_attributes_template = ();
        while (my $profile_attribute = $profile_attributes->next) {
            push @profile_attributes_template,
              {
                "id"              => $profile_attribute->id,
                "label"           => $profile_attribute->label,
                "dataType"        => $profile_attribute->type,
                "attr_group"      => $profile_attribute->attr_group,
                "values"          => $profile_attribute->delimited_values,
                "unknownDataType" => 0
              };
        }

        my $profile_attributes_count = @profile_attributes_template;

        my $standard_profile_attributes_results =
          $self->app->m->resultset('MeritCommons::Model::Profile::StandardAttribute')->search(
            {},
            {
                order_by => 'label'
            }
          );

        my @standard_profile_attributes = ();
        while (my $standard_profile_attribute = $standard_profile_attributes_results->next) {
            push(@standard_profile_attributes,
                { dataType => $standard_profile_attribute->type, label => $standard_profile_attribute->label });

            if (($profile_attributes_count == 0) && ($standard_profile_attribute->is_default)) {
                push @profile_attributes_template,
                  {
                    "id"              => undef,
                    "label"           => $standard_profile_attribute->label,
                    "attr_group"      => "General",
                    "dataType"        => $standard_profile_attribute->type,
                    "values"          => "",
                    "unknownDataType" => 0
                  };
            }
        }

        $self->stash(standard_profile_attributes => $self->json_encode(\@standard_profile_attributes));
        $self->stash(profile_user                => $profile_user);
        $self->stash(profile_attributes          => $self->json_encode(\@profile_attributes_template));

        $self->render(template => "profile/edit");
    } else {
        $self->reply->not_found;
    }
}

# verifies if a given profile attribute key is not already taken
sub attribute_key_is_available {
    my ($self, $key) = @_;

    my $result = $self->app->m->resultset('MeritCommons::Model::User::Attribute')->search(
        {
            meritcommons_user => $self->active_user->id,
            k              => $key
        }
    )->first;

    if ($result) {
        return 0;
    } else {
        return 1;
    }

    return 1;
}

# converts a label to a profile attribute key
sub underscore_attribute_key {
    my ($self, $index, $label) = @_;

    my $key = "profile_" . $label;
    $key =~ s/ - /_/g;             # Replace all " - " with "_"
    $key =~ s/[^A-Za-z0-9]/_/g;    # Replace all non-alphanumericals with _
    $key = lc($key);

    if ($index != 0) {
        $key .= "_" . $index;
    }

    return $key;
}

sub _delete_profile_attribute_values {
    my ($self, $user_profile_attribute) = @_;

    my $user_profile_attribute_values = $user_profile_attribute->vals;
    while (my $user_profile_attribute_value = $user_profile_attribute_values->next) {
        my $user_attribute_value = $user_profile_attribute_value->user_attribute_value;

        $user_profile_attribute_value->delete;
        $user_attribute_value->delete;
    }
}

sub update_profile_attributes {
    my ($self) = @_;

    # parse the form inputs to consolidate data into a more manageable form
    my @attributes             = ();
    my @attribute_id_param     = @{ $self->every_param('attribute-id') };
    my @attribute_type_param   = @{ $self->every_param('attribute-type') };
    my @attribute_param        = @{ $self->every_param('attribute-label') };
    my @attribute_values_param = @{ $self->every_param('attribute-values') };
    my @attribute_group_param  = @{ $self->every_param('attribute-group') };

    my $has_values;
    for my $i (0 .. (@attribute_id_param - 1)) {
        my $id              = $attribute_id_param[$i];
        my $attributes      = {};
        my $attribute_type  = $attribute_type_param[$i];
        my $attribute_label = $attribute_param[$i];
        my $attribute_group = $attribute_group_param[$i];
        my $values_param    = $attribute_values_param[$i];
        $values_param =~ s/^\s+//;
        my $has_values = length($values_param) > 0;

        my $user_profile_attribute;
        my $user_attribute;

        if ($has_values) {

            # Determine if the label is a standard attribute
            my $standard_attribute = $self->app->m->resultset('MeritCommons::Model::Profile::StandardAttribute')->search(
                {
                    'label' => $attribute_label
                }
            )->first;

            my $standard_attribute_id = $standard_attribute ? $standard_attribute->id : undef;

            if ($id eq "") {

                # Create new attributes
                my $c = 0;
                my $key;
                while (
                    !$self->attribute_key_is_available($key = $self->underscore_attribute_key($c++, $attribute_label)))
                {
                }

                $user_attribute = $self->app->m->resultset('MeritCommons::Model::User::Attribute')->create(
                    {
                        "meritcommons_user" => $self->active_user->id,
                        "k"              => $key
                    }
                );

                $user_profile_attribute =
                  $self->app->m->resultset('MeritCommons::Model::User::Profile::Attribute')->create(
                    {
                        "user_attribute"     => $user_attribute->id,
                        "standard_attribute" => $standard_attribute_id,
                        "label"              => $attribute_label,
                        "type"               => $attribute_type,
                        "attr_group"         => $attribute_group ? $attribute_group : 'General'
                    }
                  );
            } else {

                # Fetch attributes and delete old values
                $user_profile_attribute =
                  $self->app->m->resultset('MeritCommons::Model::User::Profile::Attribute')->search(
                    {
                        'me.id'                         => $id,
                        'user_attribute.meritcommons_user' => $self->active_user->id
                    },
                    {
                        join => 'user_attribute'
                    }
                  )->first;

                if ($user_profile_attribute) {

                    # Update the label if needed
                    $user_profile_attribute->label($attribute_label);
                    $user_profile_attribute->attr_group($attribute_group ? $attribute_group : 'General');
                    $user_profile_attribute->standard_attribute($standard_attribute_id);
                    $user_profile_attribute->update;

                    $user_attribute = $user_profile_attribute->user_attribute;

                    $self->_delete_profile_attribute_values($user_profile_attribute);
                } else {
                    croak "[error]: user profile attribute not found, or does not belong to user\n";
                }

            }

            my @attribute_values;
            if ($user_profile_attribute->type eq "M") {

                # attribute is multi value, split on comma
                @attribute_values = split(/,/, $values_param);
            } else {

                # otherwise just treat it as regular text.
                @attribute_values = ($values_param);
            }

            # Add new values
            my $ordinal = 0;
            foreach my $value (@attribute_values) {
                my $user_attribute_value =
                  $self->app->m->resultset('MeritCommons::Model::User::Attribute::Value')->create(
                    {
                        "attribute" => $user_attribute->id,
                        "v"         => $value
                    }
                  );

                $self->app->m->resultset('MeritCommons::Model::User::Profile::Attribute::Value')->create(
                    {
                        "user_attribute_value" => $user_attribute_value->id,
                        "profile_attribute"    => $user_profile_attribute->id,
                        "ordinal"              => $ordinal,
                    }
                );

                $ordinal++;
            }
        } else {
            if ($id) {

                # Delete all attributes/values
                $user_profile_attribute =
                  $self->app->m->resultset('MeritCommons::Model::User::Profile::Attribute')->search(
                    {
                        'me.id'                         => $id,
                        'user_attribute.meritcommons_user' => $self->active_user->id
                    },
                    {
                        join => 'user_attribute'
                    }
                  )->first;

                if ($user_profile_attribute) {
                    $self->_delete_profile_attribute_values($user_profile_attribute);
                    my $user_attribute = $user_profile_attribute->user_attribute;
                    $user_profile_attribute->delete;
                    $user_attribute->delete;
                } else {
                    croak "[error]: user profile attribute not found, or does not belong to user\n";
                }
            }
        }
    }

    $self->redirect_to('/u/' . $self->active_user->userid . "/");
}

sub update_profile_picture {
    my ($self) = @_;

    my $profile_user = $self->app->m->resultset('User')->search(
        {
            userid => $self->stash('user'),
        }
    )->first;

    unless ($profile_user->id == $self->active_user->id) {
        croak "[error]: user does not have access to edit profile\n";
    }

    $profile_user->profile_picture($self->param('profile_picture'));
    $profile_user->update();

    $self->redirect_to('/u/' . $profile_user->userid . '/edit');
}

1;
