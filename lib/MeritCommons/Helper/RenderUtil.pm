#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

=head1 NAME

    MeritCommons::Helper::RenderUtil - A helper to do some mustache template handling

=head1 DESCRIPTION

    MeritCommons::Helper::RenderUtil is a helper to do some mustache template handling,
    using Template::Mustache

=head1 FUNCTIONS

=cut

package MeritCommons::Helper::RenderUtil;
use Mojo::Base 'Mojolicious::Plugin';
use Template::Mustache;
use Carp qw/croak/;

=head2 C<register>

  register($app);

A basic helper register method, which registers the helper with the app.

=cut

sub register {
    my ($self, $app) = @_;

    # install local subroutine as a helper.
    $app->helper(render_mustache => \&_render_mustache);
}

=head2 C<_render_mustache>

  _render_mustache($template_name, $context, $partials);

Given a template name, the context, and partials, C<_render_mustache>
retrieves the template and reunders it, reruning the rendered template
as a string.

=cut

sub _render_mustache {
    my ($controller, $template_name, $context, $partials) = @_;
    my $mustache = Template::Mustache->new();

    for my $partial_label (keys %$partials) {
        my $partial_template = __slurp_mustache_template($partials->{$partial_label});
        unless ($partial_template) {
            return undef;
        }
        $partials->{$partial_label} = $partial_template;
    }
    if (my $template = __slurp_mustache_template($template_name)) {
        return $mustache->render($template, $context, $partials);
    }
    return undef;
}

=head2 C<__slurp_mustache_template>

  __slurp_mustache_template($template);

Given a template file name (without the .template extension), slurps the
mustache template file from public/js/templates/<name>.mustache and 
returns it as a string.

Used in _render_mustache, and not intended for public use.

=cut

sub __slurp_mustache_template {
    my ($template) = @_;
    my $string;
    open(TEMPLATE_FILE, '<', "$ENV{MERITCOMMONS_HOME}/public/js/templates/$template.mustache");
    {
        local $/;
        $string = <TEMPLATE_FILE>;
    }
    close(TEMPLATE_FILE);
    return $string;
}

1;
