  define([
    'jquery',
    'underscore',
    'backbone',
    'mustache',
    'websocket',
    'backbone_components/models/common/message',
    'backbone_components/collections/messages',
    'backbone_components/views/common/message',
    'text!templates/common/thread.mustache',
    'backbone_components/views/common/websocket_file_upload',
    'backbone_components/views/common/inbound_preprocess',
    'bootstrap',
    'summernote',
    'summernoteRecipientAutocomplete',
    'summernoteImageUpload',
    'summernoteKeyHandler'
], function($, _, Backbone, Mustache, WebSocket, MessageModel, MessageCollection, MessageView, ThreadTemplate, FileUploadHandler, IPP) {
    var Thread = Backbone.View.extend({
        className: 'thread',
        events: {
            'click .feed-message-comments-link' : 'onClickCommentsLink',
            'click .submit-reply-btn' : 'onClickSubmitReply',                  
            'click .feed-message-collapse-link' : 'onClickCollapse',
            'click .thread-expand-collapse > .btn' : 'onClickExpand',
            'click .collapse-message' : 'onClickCollapse',
        },
        initialize: function(opts) {
            var threadView = this;

            this.singleThread = (opts && opts.singleThread && (opts.singleThread == true)) ? true : false;

            this.parentMessage = opts.message;
            this.parentMessageView = new MessageView({threadView : this, message : this.parentMessage});

            this.threadReplies = new MessageCollection(this.parentMessage.get('thread_replies'));

            this.threadReplyViews = [];

            this.threadReplies.each(function(threadReply) {
                var replyView = new MessageView({threadView : threadView, message : threadReply});
                threadView.threadReplyViews.push(replyView);
            });

            this.parentMessage.bind('change', this.render, this);

            if (this.singleThread == true) {
                this.inReplyTo = this.parentMessage.get('message_id');
                if (this.parentMessage.get('public') == 0) {
                    this.parentWasPrivate = true;
                } else {
                    this.parentWasPrivate = false;
                }
                this.$el.addClass('expanded');
                this.showComments = true;
            } else {
                this.showComments = false;
            }
            this.rendered = false; // keep track of if the view has been rendered before

            $(window).on('show.bs.dropdown', function(e) {        
                dropdownButton = $(e.target);
                dropdownMenu = $(e.target).find('.dropdown-menu');

                if (dropdownButton.parents('.thread').length) {
                    var rect = dropdownButton[0].getClientRects()[0];

                    dropdownMenu.css('position', 'fixed');
                    dropdownMenu.css('top', rect.height + rect.top + "px");
                    dropdownMenu.css('left', rect.left + "px"); 

                    $(window).one('scroll', function(e) {
                        if (dropdownButton.parents('.thread').length) {
                            dropdownButton.removeClass('open');
                        }
                    });
                }
              }); 
        },
        scrollToCommentBox: function() {
            var comment_box = this.$el.find('.feed-comment'); 
            var pos = comment_box.offset().top - $(window).height() + comment_box.outerHeight();

            $('html, body').animate({ scrollTop: pos });
        },
        addReplyObject: function(messageObject) {
            var threadReply = new MessageModel(messageObject);
            this.threadReplies.add(threadReply);

            var replyView = new MessageView({threadView : this, message : threadReply});
            this.threadReplyViews.push(replyView);

            // this should trigger a render since it's a change to the parent message.
            this.parentMessage.set('number_of_replies', this.threadReplies.length);
        },
        onClickExpand: function(e) {
            var threadView = this;

            // Toggle comments
            if (this.showComments == false) {
                // By default, reply to the parent message
                this.inReplyTo = this.parentMessage.get('message_id');
                
                // keep track of parent public...
                if (this.parentMessage.get('public') == 0) {
                    this.parentWasPrivate = true;
                } else {
                    this.parentWasPrivate = false;
                }

                this.$el.addClass('expanded');

                this.showComments = true;
                this.scrollComments = false;
            } else {
                this.$el.removeClass('expanded');
                this.showComments = false;
            }

            this.render();
            e.preventDefault();
        },
        onClickCommentsLink: function(e) {
            var threadView = this;

            // Toggle comments
            if (this.showComments == false) {
                // By default, reply to the parent message
                this.inReplyTo = this.parentMessage.get('message_id');
                
                // keep track of parent public...
                if (this.parentMessage.get('public') == 0) {
                    this.parentWasPrivate = true;
                } else {
                    this.parentWasPrivate = false;
                }

                this.$el.addClass('expanded');

                this.scrollComments = true;
                this.showComments = true;           
            } else {
                this.$el.removeClass('expanded');
                this.scrollComments = false;
                this.showComments = false;
            }

            this.render(function() {
                if (threadView.scrollComments) {
                    threadView.scrollToCommentBox();
                    $('.feed-message-reply + .note-editor .note-editable', threadView.$el).focus();
                }
            });

            e.preventDefault();
        },
        onClickSubmitReply: function(e) {
            var threadView = this;
            var body = IPP($('.feed-message-reply', this.$el).code(), true);

            if (body.match(/^\s*$/)) {
                $('.feed-message-reply', this.$el).code('');
            } else {
                // disable buttan.
                $('.submit-reply-btn', this.$el).attr('disabled', 'disabled');

                // run this when MeritCommons says it has the message.
                window.MeritCommons.WebSocket.once('inbound:messagerecv', function(e, data) { 
                    $('.feed-message-reply', threadView.$el).code('');
                    $('.submit-reply-btn', threadView.$el).removeAttr('disabled');
                });

                window.MeritCommons.WebSocket.conn.send("inbound " + JSON.stringify({
                    render_as: "generic",
                    body: body,
                    in_reply_to: this.inReplyTo,
                    public: this.parentWasPrivate ? "0" : "1"
                }));
            }
        },  
        onClickCollapse: function(e) {
            this.showComments = false;
            this.$el.removeClass('expanded');

            // sub to check if scrolling is necessary
            var isElementInViewport = function (el) {

                //special bonus for those using jQuery
                if (typeof jQuery === "function" && el instanceof jQuery) {
                    el = el[0];
                }

                var rect = el.getBoundingClientRect();

                return (
                    rect.top >= 0 &&
                    rect.left >= 0 &&
                    rect.bottom <= (window.innerHeight || document.documentElement.clientHeight) && /*or $(window).height() */
                    rect.right <= (window.innerWidth || document.documentElement.clientWidth) /*or $(window).width() */
                );
            };

            var offset_top = (this.$el.offset().top - 50) + "px";
            var element_in_viewport = isElementInViewport(this.$el);
            this.render(function () {
                if (!element_in_viewport) {
                    // put the collapsed message at the top of the screen. (unless we are already at the top)
                    $('html, body').animate({ scrollTop: offset_top });
                }
            });

            // blur the textarea
            this.$el.find('.feed-message-reply + .note-editor .note-editable').blur();

            e.preventDefault();
        },            
        // Render only messages, not components like composition, etc
        renderMessages: function(callback) {
            var threadView = this;

            this.parentMessageView.render(function() {   
                threadView.onTemplateLoad(callback);
            });

            _.each(this.threadReplyViews, function(threadReplyView) {
                threadReplyView.render(function() {                    
                    threadView.onTemplateLoad(callback);
                });
            });
        },
        // Determines if all of the async templates have been loaded and calls a callback if so
        onTemplateLoad: function(callback) {
            this.threadMessagesLoaded++;

            if (MERITCOMMONS_DEBUG) {
                console.log("[thread:onTemplateLoad] " + this.threadMessagesLoaded + " of " + this.threadCount + 
                    " message templates loaded and rendered for thread_id " + this.parentMessage.get('message_id'));
            }

            if ((this.threadMessagesLoaded == this.threadCount) && ($.isFunction(callback))) {
                callback();
            }                         
        },
        render: function(callback) {
            var threadView = this;

            if (MERITCOMMONS_DEBUG) {
                console.log("[thread:render] running render on thread_id " + threadView.parentMessage.get('message_id'));
            }

            // keep track of reply counts on the client side to avoid costly queries on the server side
            this.numberOfReplies = {};
            this.threadCount = 1 + this.threadReplies.length;
            this.threadReplies.each(function(threadReply) {
                if (!threadView.numberOfReplies[threadReply.get('in_reply_to')]) {
                    threadView.numberOfReplies[threadReply.get('in_reply_to')] = 0;
                }
                threadView.numberOfReplies[threadReply.get('in_reply_to')]++;
            });

            // Keep track of async template loads to be aware of when render completes
            this.threadMessagesLoaded = 0;

            // Postpone render of thread until its child message templates all load
            this.renderMessages(function() {
                var just_toggled = false;
                threadView.first_render = false;
                if (threadView.rendered) {                    
                    // Show comments if expanded
                    var feedComments = $('.feed-comments', threadView.$el);

                    if (threadView.showComments != feedComments.is(":visible")) {
                        if (threadView.showComments == true) {
                            feedComments.slideDown(250);
                        } else {
                            feedComments.slideUp(250);
                        }
                        just_toggled = true;
                    }
                } else {
                    // we are just now rendering this, let's count this as a "toggle"
                    just_toggled = true;
                    threadView.first_render = true;

                    var show_mentions = false;
                    $.each(threadView.parentMessage.get('streams'), function(i, ele) {
                        if (ele.no_dropdown) {
                            show_mentions = true;
                            return false;
                        }
                    });
                    var renderedTemplate = Mustache.render(ThreadTemplate, {
                        showComments: threadView.showComments,
                        show_mentions: show_mentions,
                        streams: threadView.parentMessage.get('streams'),
                        submitter_profile_url: threadView.parentMessage.get('submitter_profile_url'),
                        submitter_common_name: threadView.parentMessage.get('submitter_common_name'),
                        submitter_userid: threadView.parentMessage.get('submitter_userid')
                    });

                    // Render for the first time only
                    threadView.$el.html(renderedTemplate);                                 
                    threadView.rendered = true;      

                    // only do this once.
                    var $prepended = $('.thread-parent', threadView.$el).prepend(threadView.parentMessageView.$el);

                    threadView.parentMessageView.trigger('message:written_to_dom', $prepended, 
                        threadView.parentMessage.get('message_id'), 'thread_after_templates_loaded');

                    threadView.parentMessageView.delegateEvents();
                }

                // do we show the expand collapse widget on hover or at all?
                if (threadView.threadReplies.length > 0) {
                    var expandCollapse = $('div.thread-expand-collapse-off', threadView.$el);
                    if (expandCollapse.length > 0) {
                        expandCollapse.removeClass('thread-expand-collapse-off');
                        expandCollapse.addClass('thread-expand-collapse');
                    }
                } else {
                    // since we have no replies.. make sure .feed-comment (the summernote instance) has the
                    // no-first-comment class.
                    threadView.$el.find('.feed-comment').addClass('no-first-comment');
                }

                var expandCollapse = $('div.thread-expand-collapse a.btn', threadView.$el);
                if (threadView.showComments && just_toggled) {
                    var toolbar;
                    if (window.MOBILE_PLATFORM) {
                        toolbar = [
                            ['style', ['style']],
                            ['style', ['bold', 'italic']],
                            ['para', ['ul', 'ol']],
                            ['insert', ['imageMobile']]
                        ];
                    } else {
                        toolbar = [
                            ['style', ['style']],
                            ['style', ['bold', 'italic']],
                            ['para', ['ul', 'ol']],
                            ['insert', ['image', 'link', 'hr']]
                        ];
                    }

                    $('.feed-message-reply', threadView.$el).summernote({
                        styleWithSpan: false,
                        toolbar: toolbar,
                        submitPost: function() {
                            if ($('.submit-reply-btn', threadView.$el).attr('disabled') == undefined) {
                                $('.submit-reply-btn', threadView.$el).click();
                            }
                        },
                        onKeydown: function(e) {
                            if (e.which == 27) {
                                // collapse this thread if it's focused!
                                if ($('.feed-message-reply + .note-editor .note-editable', threadView.$el).is(":focus")) {
                                    threadView.onClickCollapse(e);
                                }
                            }
                        },
                    });

                    $('.feed-message-reply', threadView.$el).code('');
                    expandCollapse.html('<i class="fa fa-arrow-up"></i> Collapse Post');
                } else if (threadView.showComments) {
                    expandCollapse.html('<i class="fa fa-arrow-up"></i> Collapse Post');
                } else {
                    $('.feed-message-reply', threadView.$el).destroy();
                    expandCollapse.html('<i class="fa fa-arrow-down"></i> Expand Post');
                }
            
                var replyAdded = false;
                _.each(threadView.threadReplyViews, function(threadReplyView) {
                    // only append replies that aren't already on the DOM
                    if (!$.contains(threadView.el, threadReplyView.el)) {
                        $('.feed-comments-container', threadView.$el).append(threadReplyView.$el);
                        replyAdded = true;
                    }

                    if (threadView.showComments) {
                        threadReplyView.trigger('message:written_to_dom', threadReplyView.$el, threadReplyView.message.get('message_id'), 
                            'thread_render_reply');            
                    }

                    threadReplyView.delegateEvents();
                });   

                // If a new reply was added, and the reply box is focused, then scroll relative the the reply textarea
                if (replyAdded && $('.feed-message-reply + .note-editor .note-editable', threadView.$el).is(":focus")) {

                    var screenTop = $(window).scrollTop();
                    var screenBottom = screenTop + $(window).height();
                    var lastReplyTop = threadView.threadReplyViews[threadView.threadReplyViews.length - 1].$el.position().top;

                    // Only scroll if the most recent message is visible on the screen.  If it's not, the user has likely
                    // scrolled away and isn't actively participating in chat
                    if ((screenTop < lastReplyTop) && (screenBottom > lastReplyTop)) {
                        threadView.scrollToCommentBox();
                    }
                }

                if ($.isFunction(callback)) {
                    callback();
                }                  
            });
        }        
    });
    return Thread;
});
