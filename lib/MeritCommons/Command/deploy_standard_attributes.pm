#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::deploy_standard_attributes;

use Mojo::Base 'Mojolicious::Command';

has description => "Redeploys the standard attributes.\n";
has usage       => "Usage: $0 deploy_standard_attributes\n";

sub run {
    my ($self, @args) = @_;

    # Insert seed data for standard profile attributes
    my @profile_attributes = (
        { is_default => 0, type => "M", label => "Favorite TV Shows" },
        { is_default => 0, type => "M", label => "Favorite Movies" },
        { is_default => 0, type => "M", label => "Favorite Books" },
        { is_default => 0, type => "M", label => "Favorite Classes" },
        { is_default => 0, type => "S", label => "Favorite Color" },
        { is_default => 0, type => "S", label => "Favorite Drink" },
        { is_default => 0, type => "M", label => "Favorite Websites" },
        { is_default => 0, type => "M", label => "Favorite Web Comics" },
        { is_default => 0, type => "M", label => "Favorite Professor" },
        { is_default => 0, type => "S", label => "Favorite Class" },
        { is_default => 0, type => "S", label => "Favorite Restaurant" },
        { is_default => 0, type => "M", label => "Favorite Journals" },
        { is_default => 0, type => "M", label => "Favorite Magazines" },
        { is_default => 0, type => "M", label => "Favorite Blogs" },
        { is_default => 0, type => "M", label => "Favorite Games" },
        { is_default => 0, type => "M", label => "Favorite Athletes" },
        { is_default => 0, type => "M", label => "Favorite Teams" },
        { is_default => 0, type => "M", label => "Favorite Sports" },
        { is_default => 0, type => "S", label => "Favorite Radio Station" },
        { is_default => 0, type => "M", label => "Favorite Bands" },
        { is_default => 0, type => "M", label => "Favorite Music" },
        { is_default => 0, type => "M", label => "Favorite Newspapers" },
        { is_default => 0, type => "M", label => "Favorite Organizations" },
        { is_default => 0, type => "M", label => "Favorite Podcasts" },
        { is_default => 0, type => "M", label => "Favorite Quotes" },
        { is_default => 0, type => "S", label => "Employer" },
        { is_default => 1, type => "M", label => "Hobbies" },
        { is_default => 0, type => "M", label => "Languages I Speak" },
        { is_default => 1, type => "M", label => "Fields of Study" },
        { is_default => 0, type => "S", label => "Hometown" },
        { is_default => 1, type => "M", label => "Student Groups" },
        { is_default => 0, type => "S", label => "Birthday" },
        { is_default => 0, type => "S", label => "Blog URL" },
        { is_default => 1, type => "S", label => "Website URL" },
        { is_default => 0, type => "S", label => "Photo Gallery URL" },
        { is_default => 0, type => "S", label => "MySpace Profile" },
        { is_default => 0, type => "S", label => "Facebook Profile" },
        { is_default => 0, type => "S", label => "Flickr Stream" },
        { is_default => 0, type => "S", label => "Picasa Gallery" },
        { is_default => 0, type => "S", label => "Google Account" },
        { is_default => 0, type => "S", label => "Foursquare Account" },
        { is_default => 0, type => "S", label => "Github Account" },
        { is_default => 0, type => "S", label => "YouTube Account" },
        { is_default => 0, type => "S", label => "Vimeo Account" },
        { is_default => 0, type => "S", label => "StackExchange Account" },
        { is_default => 0, type => "S", label => "Wikipedia Userpage" },
        { is_default => 0, type => "S", label => "World of Warcraft Profile" },
        { is_default => 0, type => "S", label => "Steam Profile" },
        { is_default => 0, type => "S", label => "Goodreads Profile" },
        { is_default => 0, type => "S", label => "Last.Fm Account" },
        { is_default => 0, type => "S", label => "Tumblr Account" },
        { is_default => 0, type => "S", label => "Pinterest Account" },
        { is_default => 0, type => "S", label => "LinkedIn Account" },
        { is_default => 0, type => "S", label => "Reddit Account" },
        { is_default => 0, type => "S", label => "Amazon Wishlist" },
        { is_default => 0, type => "S", label => "Delicious Account" },
        { is_default => 0, type => "S", label => "Educause Account" },
        { is_default => 0, type => "S", label => "Nickname" },
        { is_default => 0, type => "M", label => "Email Addresses" },
        { is_default => 0, type => "S", label => "Twitter Username" },
        { is_default => 0, type => "S", label => "Identi.ca Username" },
        { is_default => 0, type => "S", label => "AOL Instant Messenger Username" },
        { is_default => 0, type => "S", label => "Yahoo IM" },
        { is_default => 0, type => "S", label => "ICQ" },
        { is_default => 0, type => "S", label => "Windows Live Username" },
        { is_default => 0, type => "S", label => "Jabber Username" },
        { is_default => 0, type => "S", label => "XMPP Username" },
        { is_default => 0, type => "S", label => "Skype Username" },
        { is_default => 0, type => "S", label => "Screen Name" }
    );

    if ($self->app->m->resultset('MeritCommons::Model::Profile::StandardAttribute')->count == 0) {
        foreach my $profile_attribute (@profile_attributes) {

            # Create a immutable key based on the label that will be used for lookups, where specific
            # attributes are used for specific functions
            my $key = $profile_attribute->{label};
            $key =~ s/ - /_/g;             # Replace all " - " with "_"
            $key =~ s/[^A-Za-z0-9]/_/g;    # Replace all non-alphanumericals with _
            $key = lc($key);
            $profile_attribute->{k} = $key;
            $self->app->m->resultset('MeritCommons::Model::Profile::StandardAttribute')->create($profile_attribute);
        }
        print "[info]: attributes deployed\n";
    } else {
        print "[info]: attributes found, not deploying\n";
    }
}

1;
