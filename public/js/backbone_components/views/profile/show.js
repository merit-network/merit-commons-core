define([
    'jquery',
    'underscore',
    'backbone',
    'backbone_components/views/common/hydrant',
    'backbone_components/views/common/thread',
    'mustache',
    'bootstrap-dialog',
    'bootstrap'
], function($, _, Backbone, Hydrant, Message, Mustache, BootstrapDialog) {
    // this was in the HTML and was throwing an error, not sure why it was there, but moving here to get rid of the error.
    $('button').tooltip();

    var ProfileShowView = Backbone.View.extend({
        el: $('#content-wrapper'),
        events: {
            'click .respond-to-invite': 'respondToInvite',
        },
        dialog: '',
        initialize: function() {
            hydrant = new Hydrant(); 

            /* If we can enhance a value, do so */
            this.checkForReplacements( $(".profile-field") );

            $("#to-top").click(function () {
              $(document).off("scroll");
              $("body").animate(
                {scrollTop: 0},
                500,
                "swing", 
                function() {
                    $(document).scroll(function() {
                        if ($("body").scrollTop() != 0 ) {
                            $("#to-top").slideDown();
                        }
                        else {
                            $("#to-top").slideUp();
                        }
                    });
                }
              );
              $("#to-top").slideUp();
            });

            $(document).scroll(function() {
                if ($("body").scrollTop() != 0 ) {
                    $("#to-top").slideDown();
                }
                else {
                    $("#to-top").slideUp();
                }
            });

        },
        checkForReplacements: function(fields) {
            psv = this;
            fields.each(function() {
                // Is this a Flickr feed?
                var flickrval_re = /\d{8}\@\S{3}/;
                var flickrtitle_re = /Flickr/;
                if (
                    flickrval_re.exec($(this).children(".profile-field-value").html()) && 
                    flickrtitle_re.exec($(this).children(".profile-field-key").html())
                ) {
                    psv.loadFlickrStream($(this).children(".profile-field-value"));
                    return true;
                }

                // Load a little Wikipedia information if they gave their username
                var wikititle_re = /Wikipedia User/;
                if ( wikititle_re.exec($(this).children(".profile-field-key").html()) ) {
                    psv.loadWikipediaUserInfo($(this).children(".profile-field-value"));
                    return true;
                }

                // When does the narwhale bac... oh, nevermind
                var reddittitle_re = /Reddit (User|Account)/;
                if ( reddittitle_re.exec($(this).children(".profile-field-key").html()) ) {
                    psv.loadRedditUserInfo($(this).children(".profile-field-value"));
                    return true;
                }

                // Load links for book titles
                var favbookstitle_re = /Favorite Books/;
                if ( favbookstitle_re.exec($(this).children(".profile-field-key").html()) ) {
                    psv.loadBooksInfo($(this).children(".profile-field-value"));
                    return true;
                }

                // Check if it's a StackOverflow.com account id
                var stackoverflowtitle_re = /StackOverflow (User|Account)/;
                var stackoverflowval_re   = /stackoverflow\.com\/users\/\d+?\//;
                if (
                    stackoverflowtitle_re.exec($(this).children(".profile-field-key").html()) &&
                    stackoverflowval_re.exec($(this).children(".profile-field-value").html())
                ) {
                    psv.loadStackoverflowUserInfo($(this).children(".profile-field-value"));
                    return true;
                }

                // Check if it's a GitHub account
                var ghtitle_re = /Github/;
                var ghval_re   = /github\.com\/(\w+)\/?/;
                if (
                    ghtitle_re.exec($(this).children(".profile-field-key").html()) &&
                    ghval_re.exec($(this).children(".profile-field-value").html())
                ) {
                    psv.loadGithubUserInfo($(this).children(".profile-field-value"));
                    return true;
                }

            });
        },
        loadStackoverflowUserInfo: function(element) {
            var sourl    = element.html().trim();
            var re       = />stackoverflow\.com\/users\/(\d+?)\/.+?<\/a>/;
            var reresult = re.exec(sourl);
            var soid     = reresult[1];

            var tdata = {
                    soid: soid,
                };
            var t = '<a href="http://stackoverflow.com/users/{{soid}}"><img src="http://stackoverflow.com/users/flair/{{soid}}.png" '
                    +'width="208" height="58" alt="profile at Stack Overflow, Q&amp;A for professional and enthusiast programmers" '
                    +'title="profile  at Stack Overflow, Q&amp;A for professional and enthusiast programmers"></a>'

            element.html(Mustache.to_html(t, tdata));

        },
        loadBooksInfo: function(element) {
            var books_list  = element.html().trim();
            var books       = books_list.split(',');

            var tdata = {
                    books: books,
                };
            var t = '<ul class="book-list">{{#books}}<li>{{.}} <a href="https://www.goodreads.com/search?query={{.}}" title="{{.}} on Goodreads">GR</a>'
                   +'<a href="http://www.amazon.com/s/ref=sr_nr_n_0?ie=UTF8&keywords={{.}}" title="{{.}} on Amazon">A</a>'
                   +'<a href="http://www.gutenberg.org/ebooks/search/?query={{.}}" title="{{.}} on Project Gutenberg">G</a>'
                   +'<a href="https://play.google.com/store/search?q={{.}}" title="{{.}} on Google Books">GB</a>'
                   +'</li>{{/books}}</ul>';

            element.html(Mustache.to_html(t, tdata));

        },
        loadGithubUserInfo: function(element) {
            var ghurl    = element.html().trim();
            var re       = /github\.com\/(\w+)\/?/;
            var reresult = re.exec(ghurl);
            var ghid     = reresult[1];

            $.get("/ajaxwrapper/github_userinfo/"+ghid, function(data) {

                var t = '<img src={{avatar_url}} alt="login" style="float:left; margin-right: 5px" /> <a href="{{html_url}}">{{name}} ({{login}})</a> <br />'
                       +'{{public_repos}} public repositories<br />'
                       +'{{followers}} followers<br />';
                element.html(Mustache.to_html(t, data));
            },"json");

        },
        loadWikipediaUserInfo: function(element) {
            var wikipediaid = element.html().trim();
            $.get("/ajaxwrapper/wikipedia_userinfo/"+wikipediaid, function(data) {

                var tdata = {
                    wikiid: wikipediaid,
                    edits: data.query.users[0].editcount
                };
                var t = '<a href="https://en.wikipedia.org/wiki/User:{{wikiid}}">{{wikiid}}</a> ({{edits}} edits)';
                element.html(Mustache.to_html(t, tdata));
            },"json");

        },
        loadRedditUserInfo: function(element) {
            var redditid = element.html().trim();
            $.get("/ajaxwrapper/reddit_userinfo/"+redditid, function(data) {

                // Get the account creation date
                var created = new Date(data.data.created_utc * 1000);
                var dd = created.getDate();
                var mm = created.getMonth()+1;//January is 0!`
                var yyyy = created.getFullYear();
                if(dd<10) {dd='0'+dd}
                if(mm<10) {mm='0'+mm}
                var created_str = mm+'/'+dd+'/'+yyyy;

                var tdata = {
                    id: redditid,
                    link_karma: data.data.link_karma,
                    comment_karma: data.data.comment_karma,
                    created_at: created_str
                };
                var t = '<a href="http://www.reddit.com/user/{{id}}">{{id}}</a> '
                        +'({{link_karma}}/{{comment_karma}} karma, created {{created_at}})';

                element.html(Mustache.to_html(t, tdata));
            },"json");

        },
        loadFlickrStream: function(element) {
            var flickrid = element.html().trim();
            element.html("Loading Flickr Photos...");
            $.get("/ajaxwrapper/flickr_photostream/"+flickrid, function(data) {
                    var tdata = {
                        link: data.link,
                        title: data.title,
                        items: []
                    };
                    [0,1,2,3,4,5].forEach(function(i) {
                        tdata.items[i] = data.items[i];
                    });

                    var t = '<a href="{{link}}">{{title}}</a><br />'
                        +'{{#items}}<div class="flickr_thumb">'
                        +'<a href="{{link}}"><img class="flickr_thumb" alt="{{title}}" src="{{media.m}}" />'
                        +'<span class="flickr_cap">{{title}}</span></a></div>{{/items}}';

                    element.html(Mustache.to_html(t, tdata));

                    $("div.flickr_thumb").hover(
                        function() {
                            $("div.flickr_thumb").css("opacity","0.7");
                            $(this).css("opacity","1");
                        },
                        function() {
                            $("div.flickr_thumb").css("opacity","1");
                        }
                    );
                },"json");

        },
        respondToInvite: function(ev) {
            $('.respond-to-invite').prop('disabled', true);
            var data = $(ev.target).data();

            var self = this;
            MeritCommons.WebSocket.conn.send("invite " + JSON.stringify(data), {
                times: 1,
                callback: function(e, data) {
                    data = JSON.parse(data.body);
                    if (data.error) {
                        self.dialog = BootstrapDialog.show({
                            title: 'Error',
                            message: 'An error occurred: ' + data.error,
                            cssClass: 'credit-dialog',
                            buttons: [
                                {
                                    id: 'close',
                                    label: 'Close',
                                    action: function(dialog) {
                                        $('.respond-to-invite').prop('disabled', false);
                                        dialog.close();
                                    }
                                },
                            ],
                        });
                    } else {
                        var response = data.response === "accept" ? "accepted" : "declined";
                        $('tr#' + data.stream_id).find('.response').html('Invite ' + response + '!');
                    }
                }
            });
        }
        
    });
    // Our module now returns our view
    return ProfileShowView;
});