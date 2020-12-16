#    MeritCommons Portal
#    Copyright 2013 Wayne State University
#    All Rights Reserved

package MeritCommons::Command::deploy_schema;

use Mojo::Base 'Mojolicious::Command';

has description => "Tell users that deploy_schema does not exist anymore\n";
has usage       => "Usage: $0\n";

sub run {
    my ($self, $cmd, @args) = @_;
    print "301 Moved Permanently\n";

    print <<"EOF";

                      .--. .-,       .-..-.__
                    .'(`.-` \\_.-'-./`  |\\_( "\\__
                 __.>\\ ';  _;---,._|   / __/`'--)
                /.--.  : |/' _.--.<|  /  | |
            _..-'    `\\     /' /`  /_/ _/_/
             >_.-``-. `Y  /' _;---.`|/)))) 
            '` .-''. \\|:  \\.'   __, .-'"`
             .'--._ `-:  \\/:  /'  '.\\             _|_
                 /.'`\\ :;   /'      `-           `-|-`
                -`    |     |                      |
                      :.; : |                  .-'~^~`-.
                      |:    |                .' _     _ `.
                      |:.   |                | |_) | |_) |
                      :. :  |                | | \\ | |   |
                      |   : ;                |deploy_    |
            -."-/\\\\\\/:::.    `\\."-._'."-"_\\\\-|    schema |///."-
            " -."-.\\\\"-."//.-".`-."_\\\\-.".-\\\\`=.........=`//-".

    See: install_schema, prepare_upgrade, upgrade_schema, and downgrade_schema

EOF
}

1;
