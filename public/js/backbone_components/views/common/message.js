  define([
    'jquery',
    'underscore',
    'backbone',
    'mustache',
    'htmlsanitizer',
    'websocket',
    'backbone_components/models/common/message',
    'noty',
    'spin',
    'text!templates/common/advanced_message_info.mustache',
    'readmore',
    'bootstrap'
], function($, _, Backbone, Mustache, HTMLSanitizer, WebSocket, MessageModel, Noty, Spinner, AdvancedInfoTemplate) {
    var Message = Backbone.View.extend({
        className: 'feed message',
        events: {
            'click .feed-message-upvote-link' : 'onClickUpvote',
            'click .feed-message-downvote-link' : 'onClickDownvote',
            'click .unlink-message' : 'onClickDelete',
            'click .unlink-reply' : 'onClickDeleteReply',
            'click .stream-summary-link' : 'onClickDropdown',
            'click .subscribe' : 'onClickSubscribe',
            'click .unsubscribe' : 'onClickUnsubscribe',
            'click .message-advanced-info' : 'onClickAdvancedInfo',
            'click .unwatch-message' : 'onClickUnwatchMessage',
            'click .feed-message-options-link' : 'onClickOptions',
            'click .get-message-info' : 'getMessageInfo',
            'click .edit-message' : 'editMessage',
        },
        initialize: function(opts) {
            this.message = opts.message;
            this.threadView = opts.threadView;

            if (show_deletes) {
                this.message.set({ show_delete: true });
            }

            this.message.bind('change', function() {
                var i_am_parent = false;
                if (this.threadView.parentMessage) {
                    if (this.message.get('message_id') == this.threadView.parentMessage.get('message_id')) {
                        i_am_parent = true;
                    }
                }

                if (!i_am_parent) {
                    this.render.apply(this);
                }
            }, this);

            this.rendered = false;

            // recursive setTimeout keeps the message time up to date every second.
            var self = this;
            var m_abbr = new Array("Jan", "Feb", "Mar",  "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec");
            function abbr_ago_loop () {
                setTimeout(function() {
                    var post_time = new Date(self.message.get('post_time') * 1000);
                    var now = new Date();
                    var ssp = Math.floor((now.getTime() - post_time.getTime()) / 1000);

                    var abbr_ago;
                    var sec = ssp % 60;
                    var min = Math.floor(ssp / 60);

                    var hrs;
                    var day;
                    var yrs;
                    if (min >= 60) {
                        hrs = Math.floor(min / 60);
                        min = min % 60;
                        if (hrs >= 24) {
                            day = Math.floor(hrs / 24);
                            hrs = hrs % 24;
                            if (day >= 365) {
                                yrs = Math.floor(day / 365);
                                day = day % 365;
                            }
                        }
                    }

                    var zp_day;
                    if (yrs >= 1 || day >= 1) {
                        var post_day = post_time.getDate();
                        if (post_day < 10) {
                            zp_day = "0" + post_day;
                        } else {
                            zp_day = post_day;
                        }
                    }

                    if (yrs >= 1) {
                        abbr_ago = m_abbr[post_time.getMonth()] + " " + zp_day + " " + post_time.getFullYear();
                    } else if (day >= 1) {
                        abbr_ago = m_abbr[post_time.getMonth()] + " " + zp_day;
                    } else if (hrs >= 1) {
                        abbr_ago = hrs + "h";
                    } else if (min >= 1) {
                        abbr_ago = min + "m";
                    } else if (sec <= 0) {
                        abbr_ago = "Just now";
                    } else {
                        abbr_ago = sec + "s";
                    }

                    if (typeof self.message.get('message_id') != "undefined") {
                        // set the model
                        self.message.set({ abbr_ago: abbr_ago });
                        abbr_ago_loop();
                    }
                }, 60000);
            }
            abbr_ago_loop();

            this.$('a.stream-link').tooltip({
                trigger: "hover"
            });

            this.vote_animator = {
                animate_upvote: function (upvote) {
                    upvote.html('+1');
                    upvote.css({color: "#0C5449"});
                    upvote.animate({
                        top: "-=20px",
                        opacity: "toggle",
                    }, 'slow', function() {
                        $(this).css({top: ""}).hide();
                    });
                },
                animate_downvote: function (downvote) {
                    downvote.html("+1");
                    downvote.css({color: "#65132F"});
                    downvote.animate({
                        top: "+=20px",
                        opacity: "toggle",
                    }, 'slow', function() {
                        $(this).css('top', '').hide();
                    });
                },
                animate_upvote_undo: function (upvote) {
                    upvote.css({top: "-=20px", display: 'block', color: '#65132F'});
                    upvote.html('-1');
                    upvote.animate({
                        top: "+=20px",
                        opacity: "toggle",
                    }, 'slow', function() {
                        $(this).css({top: ""}).hide();
                    });
                },
                animate_downvote_undo: function(downvote) {
                    downvote.css({top: "+=20px", display: 'block', color: '#0C5449'});
                    downvote.html("-1");
                    downvote.animate({
                        top: "-=20px",
                        opacity: "toggle",
                    }, 'slow', function() {
                        $(this).css({top: ""}).hide();
                    });
                },
                animate_upvote_change: function(upvote, downvote) {
                    this.animate_downvote_undo(downvote);
                    this.animate_upvote(upvote);
                },
                animate_downvote_change: function(upvote, downvote) {
                    this.animate_upvote_undo(upvote);
                    this.animate_downvote(downvote);
                }
            };

            this.animation_queue = [];

            // bind written_to_dom event for readmore
            this.bind('message:written_to_dom', this.writtenToDom);

        },
        writtenToDom: function($el, message_id, where) {
            // actually query the DOM for it.
            if ($.contains(document, $el[0])) {
                if ($('div[data-readmore].body.message-read', $el).length == 0) {
                    var time_to_wait = 0;
                    var time_waited = 0;
                    var start_readmore = function() {
                        time_waited += time_to_wait;
                        // see if content has all been loaded yet.
                        var all_images_complete = true;
                        $el.find("img").filter(function(index, img) {
                            if (!img.complete) {
                                all_images_complete = false;
                            }
                        });

                        if (all_images_complete) {
                            $('.body.message-read', $el).readmore({
                                speed: 150,
                                moreLink: '<a class="message-read-more" href="#">Read more</a>',
                                lessLink: '<a class="message-read-less" href="#">Read less</a>',
                                collapsedHeight: MOBILE_PLATFORM ? 800 : 390,
                                collapsedMargin: 50,
                                afterToggle: function(t, ele, expanded) {
                                    // this was a toggle close
                                    if (!expanded) {
                                        $('html, body').animate( { scrollTop: $(ele).closest('.feed-message').offset().top - 65}, {duration: 100 } );
                                    }
                                }
                            });
                            if (time_waited > 0 && MERITCOMMONS_DEBUG) {
                                console.log('[message:writtenToDom] message_id ' + message_id + ' successfully loaded all images in ' + time_waited + 'ms');
                            }
                        } else {
                            time_to_wait += 100;
                            if (time_to_wait < 1000) {
                                if (MERITCOMMONS_DEBUG) {
                                    console.log('[message:writtenToDom] message_id ' + message_id + ' has images that are still loading; waiting ' + time_to_wait + 'ms');
                                }
                                setTimeout(start_readmore, time_to_wait);
                            } else {
                                if (MERITCOMMONS_DEBUG) {
                                    console.log('[message:writtenToDom] message_id ' + message_id + " still hasn't loaded all images after " + time_waited + "ms; giving up");
                                }
                            }
                        }
                    };

                    start_readmore();
                }

                if (MERITCOMMONS_DEBUG) {
                    console.log("[message:writtenToDom] " + message_id + " " + where);
                }
            }
        },
        onClickAdvancedInfo: function(e) {
            $('#info-modal-title').html("Advanced Message Info");

            $('#info-modal-content').html(Mustache.render(AdvancedInfoTemplate, {
                message_id: this.message.get('message_id'),
                thread_id: this.message.get('thread_id'),
                submitter: this.message.get('submitter'),
                submitter_userid: this.message.get('submitter_userid'),
                submitter_profile_url: this.message.get('submitter_profile_url'),
                streams: this.message.get('streams'),
                number_of_replies: this.message.get('number_of_replies'),
                reply_word: this.message.get('number_of_replies') == 1 ? "Reply" : "Replies",
                thread_replies: this.message.get('thread_replies'),
                post_time: new Date(this.message.get('post_time') * 1000).toLocaleString(),
            }));

            $('#info-modal').modal({
                show: true,
                backdrop: 'static',
            });
        },
        onClickUnwatchMessage: function(e) {
            var message_id = this.message.get('message_id');
            var thread_id = this.message.get('thread_id');

            var status_message;
            if (message_id == thread_id) {
                status_message = "Notifications canceled for this thread.";
            } else {
                status_message = "Notifications canceled for this comment.";
            }

            window.MeritCommons.WebSocket.conn.send("unwatch " + JSON.stringify({
                message: message_id
            }));

            window.MeritCommons.WebSocket.once('unwatch:response', function(e, data) {
                var n = noty({
                    layout: 'topCenter',
                    theme: 'relax',
                    type: 'success',
                    text: "<i class='fa fa-check'></i> " + status_message,
                    timeout: 3500,
                    closeWith: ['click'],
                    maxVisible: 1,
                    animation: {
                        open: {height: 'toggle'},
                        close: {height: 'toggle'},
                        easing: 'swing',
                        speed: 250
                    }
                });
            });            

            e.preventDefault();
        },
        onClickDeleteReply: function(e) {
            var message_id = this.message.get('message_id');
            var thread_id = this.threadView.parentMessage.get('message_id');

            window.MeritCommons.WebSocket.conn.send("unlink_from_thread " + JSON.stringify({
                thread: thread_id,
                message: message_id
            }));
            
            e.preventDefault();
        },
        onClickDelete: function(e) {
            var message_id = this.message.get('message_id');
            var streams = $(e.currentTarget).attr('stream').split(',');

            if (streams.length > 0) {
                window.MeritCommons.WebSocket.conn.send("unlink_from_stream " + JSON.stringify({
                    streams: streams,
                    message: message_id
                }));
            }
            e.preventDefault();
        },
        onClickUpvote: function(e) {
            var self = this;
            window.MeritCommons.WebSocket.conn.send("vote " + JSON.stringify({ message_id: this.message.get('message_id'), vote: '1' }));
            window.MeritCommons.WebSocket.once('vote:response', function(e, data) {
                self.voteAnimation($.parseJSON(data.body));
            });
            $(e.currentTarget).blur();
            e.preventDefault();
        },
        onClickDownvote: function(e) {
            var self = this;
            window.MeritCommons.WebSocket.conn.send("vote " + JSON.stringify({ message_id: this.message.get('message_id'), vote: '-1' }));
            window.MeritCommons.WebSocket.once('vote:response', function(e, data) {
                self.voteAnimation($.parseJSON(data.body));
            });
            $(e.currentTarget).blur();
            e.preventDefault();
        },
        voteAnimation: function(data) {
            if (data.upvote) {
                this.animation_queue.push({ animation: "animate_upvote", args: [this.$el.find('.upvote-animation')] });
            } else if (data.upvote_undo) {
                this.animation_queue.push({ animation: "animate_upvote_undo", args: [this.$el.find('.upvote-animation')] });
            } else if (data.downvote) {
                this.animation_queue.push({ animation: "animate_downvote", args: [this.$el.find('.downvote-animation')] });
            } else if (data.downvote_undo) {
                this.animation_queue.push({ animation: "animate_downvote_undo", args: [this.$el.find('.downvote-animation')] });
            } else if (data.upvote_change) {
                this.animation_queue.push({ animation: "animate_upvote_change", args: [this.$el.find('.upvote-animation'), this.$el.find('.downvote-animation')] });
            } else if (data.downvote_change) {
                this.animation_queue.push({ animation: "animate_downvote_change", args: [this.$el.find('.upvote-animation'), this.$el.find('.downvote-animation')] });
            }
        },
        onClickOptions: function(e) {
            var button = this.$(e.target).parents('.btn-group').children('button');

            if (button.parent().hasClass('open')) {
                button.parent().removeClass('open');

                // prevent bootstrap from handling this click, it's OURS.
                e.stopImmediatePropagation();
            } else {
                // Empty previously rendered dropdown options.
                button.next('ul').remove();

                var old_html = $(button).html();
                window.MeritCommons.WebSocket.conn.send("options_dropdown " + this.message.get('message_id'), {
                    callback: function(e, data) {
                        var dropdown_html = data.body;
                        button.parent().append(dropdown_html);

                        if (!button.parent().hasClass('open')) {
                            button.parent().addClass('open');
                        }

                        button.html(old_html);
                    },
                    times: 1
                });
            }
        },
        getMessageInfo: function(e) {
            var self = this;
            window.MeritCommons.WebSocket.conn.send("get_message_info " + this.message.get('message_id'), {
                callback: function(e, data) {
                    var info_html = data.body;
                    self.$el.find('.feed-message-info').filter(':first').html(info_html).show('fast').find('.dropdown-toggle').dropdown();
                },
                times: 1
            });
            e.preventDefault();
        },
        onClickDropdown: function(e) {
            var summary = $(e.currentTarget);
            e.preventDefault();

            if (summary.parent().hasClass('open')) {
                summary.parent().removeClass('open');

                // prevent bootstrap from handling this click, it's OURS.
                e.stopImmediatePropagation();
            } else {
                // clean up old data...
                summary.next('ul').remove();

                window.MeritCommons.WebSocket.conn.send("stream_dropdown " + summary.data('for-message'), {
                    callback: function(e, data) {
                        var dropdown_html = data.body;
                        summary.parent().append(dropdown_html);

                        if (!summary.parent().hasClass('open')) {
                            summary.parent().addClass('open');
                        }
                    },
                    times: 1
                });
            }
        },
        onClickSubscribe: function(e) {
            var stream_id = this.$(e.target).data('stream-id');
            var stream_name = this.$(e.target).data('stream-name');
            $.get('/acl', { user: userId, stream: stream_id, action: 'add', permission: 'sub' }, function(data) {
                var text;
                var type;
                if (data.error) {
                    text = data.error;
                    type = 'error';
                } else {
                    text = "<i class='fa fa-check'></i> Ok, you will now see posts from <strong>" + stream_name + "</strong> on your home page";
                    type = 'success';
                }
                var n = noty({
                    layout: 'topCenter',
                    theme: 'relax',
                    type: type,
                    text: text,
                    timeout: 3500,
                    closeWith: ['click'],
                    maxVisible: 1,
                    animation: {
                        open: {height: 'toggle'},
                        close: {height: 'toggle'},
                        easing: 'swing',
                        speed: 250
                    }
                });
            });
            e.preventDefault();
        },
        onClickUnsubscribe: function(e) {
            var stream_id = this.$(e.target).data('stream-id');
            var stream_name = this.$(e.target).data('stream-name');
            $.get('/acl', { user: userId, stream: stream_id, action: 'remove', permission: 'sub' }, function(data) {
                var text;
                var type;
                if (data.error) {
                    text = data.error;
                    type = 'error';
                } else {
                    text = "<i class='fa fa-times'></i> You will no longer see posts from <strong>" + stream_name + "</strong> on your home page";
                    type = 'success';
                }
                var n = noty({
                    layout: 'topCenter',
                    theme: 'relax',
                    type: type,
                    text: text,
                    timeout: 3500,
                    closeWith: ['click'],
                    maxVisible: 1,
                    animation: {
                        open: {height: 'toggle'},
                        close: {height: 'toggle'},
                        easing: 'swing',
                        speed: 250
                    }
                }, 'json');
            });
            e.preventDefault();
        },
        render: function(callback) {
            var self = this;

            var messageAttributes = self.message.attributes;

            // Get the new numberOfReplies from the client (specifically, the thread view).  The message
            // model data may be stale if there were replies to this message since it was loaded.
            var messageId = self.message.get('message_id');
            var numberOfReplies = self.threadView.numberOfReplies[messageId];
            messageAttributes.number_of_replies = (numberOfReplies) ? numberOfReplies : 0;

            if (MERITCOMMONS_DEBUG) {
                console.log("[message:render] running render on message_id " + messageId);
            }

            require(['text!templates/message/' + self.message.get('render_as') + ".mustache"], function(t) {
                renderedTemplate = Mustache.render(t, {
                    message : messageAttributes
                });

                if (self.rendered) {
                    if (messageAttributes.message_id) {
                        // copy over the rendered header
                        $('div.feed-message-header', self.$el).html($('div.feed-message-header', renderedTemplate).html());
                        var changed = self.message.changedAttributes();

                        // did the number of upvotes change?
                        if (typeof changed['upvotes'] != "undefined") {
                            $('div.upvote', self.$el).html($('div.upvote', renderedTemplate).html());
                        }
                        
                        // how about the number of downvotes?
                        if (typeof changed['downvotes'] != "undefined") {
                            $('div.downvote', self.$el).html($('div.downvote', renderedTemplate).html());
                        }

                        // or the number of comments?
                        if (typeof changed['number_of_replies'] != "undefined") {
                            $('a.feed-message-comments-link', self.$el).html($('a.feed-message-comments-link', renderedTemplate).html());
                        }

                        // or the stream badges
                        if (typeof changed['streams'] != "undefined") {
                            $('div.message-streams', self.$el).html($('div.message-streams', renderedTemplate).html());
                        }

                        // and if the body changed (from an edit), update it.  note: this will stop a playing video always and forever.
                        if (typeof changed['body'] != "undefined") {
                            $('div.feed-message-body', self.$el).html($('div.feed-message-body', renderedTemplate).html());
                        }

                        if (typeof changed['abbr_ago'] != "undefined") {
                            $('div.feed-time-stamp', self.$el).html($('div.feed-time-stamp', renderedTemplate).html());
                        }

                        if (typeof changed['read_only'] != "undefined") {
                            $('div.feed-message-footer', self.$el).html($('div.feed-message-footer', renderedTemplate).html());
                        }

                        if (typeof changed['edited'] != "undefined") {
                            $('span.feed-edited', self.$el).html($('span.feed-edited', renderedTemplate).html());
                        }
                    } else {
                        this.threadView.remove();
                    }
                } else {
                    var $rt = $(renderedTemplate);
                    if (self.threadView.threadReplyViews[0] && self.threadView.threadReplyViews[0].message.get('message_id') == messageId) {
                        $('.feed-message', $rt).addClass('first-comment');
                        self.threadView.$el.find('.feed-comment').removeClass('no-first-comment');
                    }

                    // render and insert the rendered HTML
                    self.$el.html($rt);
                    self.rendered = true;

                    if (MERITCOMMONS_DEBUG) {
                        console.log("[message:render] finished rendering mustache template for message " + messageId);
                    }
                }

                // call our callback
                if ($.isFunction(callback)) {
                    callback();
                }  

                // run animations
                while (self.animation_queue.length > 0) {
                    var anim = self.animation_queue.shift();
                    var new_args = [];
                    $.each(anim.args, function(i, ele) {
                        new_args.push(self.$el.find(ele.selector));
                    });

                    self.vote_animator[anim.animation].apply(self.vote_animator, new_args);
                }               

                // refresh likes / message info if it's visible                
                if (self.$el.find('.feed-message-info:visible').length > 0) {
                    window.MeritCommons.WebSocket.conn.send("get_message_info " + self.message.get('message_id'), {
                        callback: function(e, data) {
                            var info_html = data.body;
                            self.$el.find('.feed-message-info').filter(':first').html(info_html).show('fast').find('.dropdown-toggle').dropdown(); 
                        },
                        times: 1
                    });
                }

                self.$el.find('[data-toggle="tooltip"]').tooltip();
            });
        },
        editMessage: function(ev) {
            var msg = this.message;

            MeritCommons.editMessage.set({ 
                 message_id: msg.get('message_id'),
                 thread_id: msg.get('thread_id'),
                 render_as: msg.get('render_as'),
                 serialized: msg.get('serialized'),
                 subject: msg.get('subject'),
                 body: msg.get('body'),
                 streams: msg.get('streams'),
                 read_only: msg.get('read_only'),
                 public: msg.get('public'),
                 in_reply_to: msg.get('in_reply_to'),
                 submitter_mask: msg.get('submitter_mask'),
                 timestamp: new Date(), // this is here so that the model "changes" when we try to edit the same one
            });
        },
    });

    return Message;
});
