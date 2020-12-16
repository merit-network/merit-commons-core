#
# Build Tool for CSS & JavaScript
# (c) 2016 Michael Gregorowicz
#

package MeritCommons::Build;
use Mojo::Base -base;
use CSS::Sass;
use JavaScript::Minifier::XS;
use File::Find;

has js_base => "$ENV{MERITCOMMONS_HOME}/public/js";
has [ 'app', 'plugins', 'asset_base', 'plugins', 'theme_config' ];

sub build {
    my ($self) = @_;

}

sub build_js_file_lists {
    my ($self) = @_;

    my (@library_files, @component_files, @template_files);

    # start with the templates
    find(
        sub {
            my $filename = $File::Find::name;
            if ($filename =~ /$js_dir\/(.+\.mustache)$/i) {
                push(@template_files, "text!$1");
            }
        },
        $self->js_base . "/templates"
    );

    # now the backbone views and models
    find(
        sub {
            my $filename = $File::Find::name;
            if ($filename =~ /$js_dir\/(.+)\.js$/i) {
                push(@component_files, "$1");
            }
        },
        $self->js_base . "/backbone_components"
    );
    
    # now find the libaries..
    find(
        sub {
            my $filename = $File::Find::name;
            if ($filename =~ /$js_dir\/(.+)\.js$/i) {
                push(@library_files, "$1");
            }
        },
        $self->js_base . "/libs"
    );
    
    return (\@library_files, \@component_files, \@template_files);
}

sub compute_js_file_dependency_order {
    my ($self, $libs, $app_logic, $templates) = @_;
    
}

sub build_css {
    my ($self, $build_id) = @_;

}

1;
