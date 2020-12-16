package MeritCommons::Routes;

# the main MeritCommons route file

use Mojo::Base -base;

has qw/app/;

sub new {
    my ($class, $app) = @_;
    return bless { app => $app }, $class;
}

sub startup {
    my ($self) = @_;

    # Unpack Routes Object
    my $r = $self->app->routes;

    # das home page.
    $r->route('/')->to('controller-merge#default')->name('merge');

    # documentation
    $r->route('/docs')->to('controller-docs#default')->partial(1);

    # moved authentication to /auth
    $r->route('/auth')->to('controller-auth#default');
    $r->route('/cs')->via(qw/GET POST/)->to('controller-auth#cookie_setter');
    $r->route('/cs')->via('OPTIONS')->to('controller-auth#cookie_setter_options');
    $r->route('/lt')->to('controller-auth#get_login_token');
    $r->route('/si')->via(qw/GET POST/)->to('controller-auth#session_info');
    $r->route('/si')->via('OPTIONS')->to('controller-auth#session_info_options');
    $r->route('/detect_features')->to('controller-auth#detect_js_features');
    $r->route('/hmb')->via(qw/GET/)->to('controller-auth#hold_my_beer');
    $r->route('/gmb')->via(qw/GET POST/)->to('controller-auth#gimme_my_beer');
    
    $r->route('/loading')->to('controller-common#loading');

    $r->route('/login')->to('controller-auth#login');
    $r->route('/auth/session_poll')->to('controller-auth#session_poll');
    $r->route('/auth/session_extend')->via(qw/GET_POST/)->to('controller-auth#session_extend');
    $r->route('/auth/session_extend')->via('OPTIONS')->to('controller-auth#session_extend_options');

    # development mode only!
    $r->route('/schema')->to('controller-schema#default');

    # user settings!
    $r->route('/user_settings')->to('controller-settings#user_settings');

    # testage
    $r->route('/hello_world')->to('controller-hello#default');
    $r->websocket('/hydrant')->to('controller-hydrant#default');
    $r->route('/watch_hydrant')->to('controller-hydrant#watch');

    # Idp (work-in-progress)
    $r->route('/idp/login')->to('controller-idp#default');
    $r->route('/idp/logout')->to('controller-idp#logout');

    # a system info page for meritcommons
    $r->route('/sysinfo')->to('controller-sysinfo#default');

    # a self_check endpoint
    $r->get('/self_check')->to('controller-sysinfo#self_check');

    # redirects for the js and css bundles
    $r->route('/css/_bundle')->to('controller-sysinfo#css_bundle');
    $r->route('/js/_bundle')->to('controller-sysinfo#js_bundle');

    # search
    $r->get('/search')->to('controller-search#default');
    $r->route('/search')->via('IDENTIFY')->to('controller-search#identify');
    $r->route('/search')->via('OPTIONS')->to('controller-search#identify_options');

    # stream pages!
    $r->get('/streams/:page')->to('controller-stream#list');
    $r->get('/streams')->to('controller-stream#list');
    $r->get('/s/#stream_identifier')->name('get_stream')->to('controller-stream#default');
    $r->get('/s/#stream_identifier/m')->name('moderate_stream')->to('controller-moderatestream#default');
    $r->post('/s/#stream_identifier/profile_picture')->to('controller-moderatestream#update_profile_picture');
    $r->get('/s/#stream_identifier/e')->to('controller-stream#edit');

    $r->route('/s/#stream_identifier/:list_type/:page', list_type => [qw(subscribers authors moderators)])
      ->to('controller-stream#user_list');
    $r->route('/s/#stream_identifier/:list_type', list_type => [qw(subscribers authors moderators)])
      ->to('controller-stream#user_list');

    $r->post('/s/#stream_identifier/edit_details')->to('controller-stream#edit_details');
    $r->post('/s/#stream_identifier')->to('controller-stream#create');
    $r->post('/s/:do/:sub_aut_mod')->to('controller-stream#permissions_handler');

    # per-stream (or combo stream) rss feeds
    $r->get('/s/#stream_identifier/rss' => [ format => ['xml'] ])->to('controller-stream#rss');

    # single-message page!
    $r->get('/m/:message_identifier')->to('controller-message#default');

    # user profiles!
    $r->get('/u/:user')->name('get_profile')->to('controller-profile#show');
    $r->get('/u/:user/edit')->to('controller-profile#edit');
    $r->post('/u/:user/profile_picture')->to('controller-profile#update_profile_picture');
    $r->post('/u/:user/profile_attributes')->to('controller-profile#update_profile_attributes');

    # for routing identity requests
    $r->route('/u/:user')->via('OPTIONS')->to('controller-profile#identify_options');
    $r->route('/u/:user')->via('IDENTIFY')->to('controller-profile#identify');
    $r->route('/u/:user')->via('MAKEPROXY')->to('controller-profile#makeproxy');

    # user stream management!
    $r->get('/u/:user/s')->name('user_stream_management')->to('controller-mystreams#default');

    # acl!
    $r->route('/acl')->to('controller-acl#default');

    # inbound messages!
    $r->post('/inbound')->to('controller-inbound#default');
    $r->post('/inbound/attach')->to('controller-inbound#attach_file');

    # short to long!
    $r->route('/link/:short_loc')->to('controller-links#short_loc_redirect');
    $r->route('/superclick/:short_loc')->to('controller-links#superclick');
    $r->route('/unsuperclick/:short_loc')->to('controller-links#unsuperclick');

    # asset proxy!
    $r->route('/asset_proxy/:proxy_hmac/:encoded_url')->to('controller-links#asset_proxy');

    # session settings
    $r->route('/session_variable')->to('controller-settings#session_variable');
    $r->route('/user_config')->to('controller-settings#user_config');

    # get my websocket
    $r->route('/myws')->to('controller-mywebsocket#default');

    # session timed out route
    $r->route('/session_timed_out')->to('controller-auth#session_timed_out');

    $r->route('/examples/login')->to(
        cb => sub {
            shift->redirect_to('/examples/login.html');
        }
    );

    # AJAX Wrappers
    $r->get('/ajaxwrapper/flickr_photostream/:fid')->to('controller-ajaxwrapper#flickr_photostream');
    $r->get('/ajaxwrapper/wikipedia_userinfo/:uid')->to('controller-ajaxwrapper#wikipedia_userinfo');
    $r->get('/ajaxwrapper/reddit_userinfo/:uid')->to('controller-ajaxwrapper#reddit_userinfo');
    $r->get('/ajaxwrapper/stackoverflow_userinfo/:uid')->to('controller-ajaxwrapper#stackoverflow_userinfo');
    $r->get('/ajaxwrapper/github_userinfo/:uid')->to('controller-ajaxwrapper#github_userinfo');

    # votes!
    $r->route('/msg/vote')->to('controller-vote#vote');
    $r->route('/msg/voted')->to('controller-vote#voted');

    # for marking messages read!
    $r->route('/mark_message_read')->to('controller-message#mark_read');

    # Alias Management
    $r->route('/alias')->to('controller-alias#list');
    $r->route('/alias/list')->to('controller-alias#list');
    $r->route('/alias/delete/:id')->to('controller-alias#delete');
    $r->route('/alias/add')->to('controller-alias#add');
    $r->route('/alias/edit/:id')->to('controller-alias#edit');
    $r->route('/alias/edit')->to('controller-alias#edit');

    # MeritCommonscoins
    $r->route('/coins')->to('controller-coins#default');
    $r->route('/coins/transfer')->to('controller-coins#transfer');
    $r->route('/coins/request')->to('controller-coins#request');
    $r->route('/coins/admin')->to('controller-coins#admin');

    # scratch space for testing
    $r->route('/scratch')->to('controller-scratch#default');

    # for catchall..
    return $r;
}

1;
