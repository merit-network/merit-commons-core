#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Controller::Schema;

# declare our @ISA
our @ISA;

# we're a Mojolicious::Controller, first and foremost!
use Mojo::Base 'Mojolicious::Controller';
use SQL::Translator;

#
# the default handler method! :)
#
sub default {
    my ($self) = @_;

    if ($self->app->mode eq "development") {
        my $file_name = 'diagram-v' . $self->m->version . '.png';

        my $trans = SQL::Translator->new(
            parser        => 'SQL::Translator::Parser::DBIx::Class',
            parser_args   => { package => $self->m },
            producer      => 'Diagram',
            producer_args => {
                out_file         => '../public/img/' . $file_name,
                show_constraints => 1,
                show_datatypes   => 1,
                show_sizes       => 1,
                show_fk_only     => 0,
            }
        );

        $trans->translate;

        $self->render(image => "/img/$file_name", template => "general/image");
    } else {
        $self->render(message => "Sorry, MeritCommons is not in development mode!", template => "general/message");
    }
}

1;
