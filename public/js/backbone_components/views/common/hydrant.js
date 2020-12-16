  define([
    'jquery',
    'underscore',
    'backbone',
    'mustache',
    'modernizr',
    'websocket',
    'emoji',
    'htmlsanitizer',
    'backbone_components/views/common/scrollbar',
    'backbone_components/views/common/thread',    
    'backbone_components/models/common/message',    
    'backbone_components/collections/messages',
    'hashchange',    
    'select2'
], function($, _, Backbone, Mustache, Modernizr, WebSocket, Emoji, HTMLSanitizer, Scrollbar, ThreadView, MessageModel, MessageCollection, HashChange) {
    var sub_message_ids = [];
    var sub_tick = 0;
    function sub_spooled_messages() {
        if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
            if (sub_message_ids.length > 0) {
                sub_tick++;
                if (MERITCOMMONS_DEBUG) {
                    console.log('[hydrant:subscribeMessageSpool] subscribing a batch of ' + sub_message_ids.length + 
                        ' messages; ' + "sub tick #" + sub_tick);
                }
                window.MeritCommons.WebSocket.conn.send("subscribe_to_messages " + JSON.stringify({ messages: sub_message_ids }));
                sub_message_ids = [];
            }
        } else {
            if (MERITCOMMONS_DEBUG) {
                console.log("[hydrant:subscribeMessageSpool] WebSocket unavailable, deferring subscription.  Queue size: " + sub_message_ids.length)
            }
        }
        setTimeout(sub_spooled_messages, 200);
    }
    
    // kick things off...
    setTimeout(sub_spooled_messages, 200);
    
    var Hydrant = Backbone.View.extend({
        el: '#messages-go-here',
        initialize: function(opts) {
            if (Modernizr.websockets) {
                if (MERITCOMMONS_DEBUG) {
                    console.log("[hydrant:init] hydrant initializing");
                }
                if (REPLACE_EMOJI) {
                    $('#messages-go-here').html(Emoji.replace($('#messages-go-here').html()));
                }

                // If getMoreImmediate is passed, a requestMessages call will be made immediately after loading
                this.getMoreImmediate = (opts && opts.getMoreImmediate) ? true : false;
                this.getMoreImmediateComplete = false;

                if (opts && opts.searchOptions && opts.searchOptions.query) {
                    this.searchFilter = opts.searchOptions.query;
                } else {
                    this.searchFilter = undefined;                
                }

                // Instantiate the Scrollbar view, which watches for various scroll gestures.
                // Bind desired Hydrant actions to those scroll gestures.
                this.scrollbarView = new Scrollbar();

                // debuggery.
                //localStorage.removeItem("_this_browser");
                //localStorage.removeItem("_me");

                this.singleThread = (opts && opts.singleThread && (opts.singleThread == true)) ? true : false;
                if (!this.singleThread) {
                    this.scrollbarView.bind('scrolltop', this.addQueuedMessages, this);
                    this.scrollbarView.bind('scrollfetch', this.requestMessages, this);
                }
                this.hydrantPrependQueue = [];

                var hydrantView = this;
                this.subscriptionList = [];
                $.each(subscriptions, function(k, v) {
                    hydrantView.subscriptionList.push(k);
                });

                // Instantiate bootstrapped messages that have already been rendered
                this.messages = new MessageCollection(messages);

                this.threadViews = [];
                this.messages.each( function(message) {
                    var threadView = new ThreadView({
                        el: '#' + message.get('message_id'), 
                        message : message,
                        singleThread : hydrantView.singleThread
                    });                    

                    threadView.render(function() {
                        if (hydrantView.singleThread) {
                            // It's safe to show the merge container at this point, since the message has been rendered.
                            // We avoid rendering early, since the non-JS version will render slightly different than the
                            // Backbone variation, and we don't want the HTML to flash with changes
                            $('.merge-container').show();
                        }
                        
                        // these need to be triggered after the render's done
                        $.each(HashChange.parsed_hash, function(k, v) {
                            if (k == "m") {
                                HashChange.trigger(k + ":add", window.MeritCommons.HashChange.parsed_hash[k]);
                            }
                        });                     
                    }); // Rerender DOM element so that it's driven by Backbone and comments are loaded
                    
                    hydrantView.threadViews.push(threadView);
                });

                var lastMessage = this.messages.last();
                this.lastThreadDate = (lastMessage) ? lastMessage.get('post_time') : undefined;
                this.lastThreadId = (lastMessage) ? lastMessage.get('message_id') : undefined;

                var start_hydrant = function() {
                    hydrantView.addSubscriptions();
                    hydrantView.subscribeToMessages(hydrantView.messages);

                    if (hydrantView.getMoreImmediate && !hydrantView.getMoreImmediateComplete) {
                        hydrantView.requestMessages();
                        hydrantView.getMoreImmediateComplete = true;
                    }
                };

                // websockets and stacking paper.  all day.
                window.MeritCommons.WebSocket.on('message:subscribed', this.mergeMessage, this);
                window.MeritCommons.WebSocket.on('cmdresponse:success', this.logCommands, this);
                window.MeritCommons.WebSocket.on('cmdresponse:error', this.logCommands, this);
                window.MeritCommons.WebSocket.on('websocket:open', start_hydrant, this);

                // If the WebSocket is already open, add subscriptions and start pings immediately as
                // websocket:open will never fire.
                if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                    if (MERITCOMMONS_DEBUG) {
                        console.log("[hydrant:webSocketConnected] connection readyState is now 1");
                    }
                    start_hydrant();
                }                 
            }

            // added or changed!
            HashChange.on('m:add m:change', function(v) {
                var threadView;
                // scroll to this message
                $.each(this.threadViews, function(i, ele) {
                    if (ele.parentMessageView.message.get('message_id') == v) {
                        threadView = ele;
                        return false;
                    } else {
                        $.each(ele.threadReplyViews, function(i, reply) {
                            if (reply.message.get('message_id') == v) {
                                threadView = ele;
                                return false;
                            }
                        });
                        if (typeof threadView != "undefined") {
                            return false;
                        }
                    }
                });

                if (threadView) {
                    threadView.showComments = true;
                    threadView.render(function() {
                        $.each(threadView.threadReplyViews, function(i, reply) {
                            if (reply.message.get('message_id') == v) {
                                $('html, body').animate({ scrollTop: reply.$el.position().top });
                                return false;
                            }
                        });
                    });
                }
            }, this);
        },
        
        renderMessage: function(newThreadView) {
            var newMessageDate = newThreadView.parentMessage.get('post_time');
            var insertAfterThread;
            var insertAfterThreadDate;

            // Find the last rendered message that is newer, or the same time, as the incoming message
            _.each(this.threadViews, function(existingThreadView) {
                var existingThreadMessageDate = existingThreadView.parentMessage.get('post_time');                

                // Determine if there's a better candidate for the new message to be placed under.  To qualify,
                // the candidate must be newer than the new message.  There must also be no other previous candidate, or
                // the new candidate must have an equal or older post_time relative to the last selected candidate. 
                if ((newMessageDate <= existingThreadMessageDate) && 
                    (!insertAfterThread || (insertAfterThreadDate >= existingThreadMessageDate))) {
                    insertAfterThread = existingThreadView;
                    insertAfterThreadDate = insertAfterThread.parentMessage.get('post_time');
                }
            });
            
            var animate = false;
            var hydrantView = this;

            if ($(window).scrollTop() == 0 || MOBILE_PLATFORM) {
                if (insertAfterThread) {
                    if (MERITCOMMONS_DEBUG) {
                        console.log("[hydrant:renderMessage] merging message_id " + newThreadView.parentMessage.get('message_id') + " after thread " + 
                            insertAfterThread.parentMessage.get('message_id'));
                    }
                    insertAfterThread.$el.after(newThreadView.$el);
                } else {
                    // we are at the top
                    if (MERITCOMMONS_DEBUG) {
                        console.log("[hydrant:renderMessage] adding message_id " + newThreadView.parentMessage.get('message_id') + " to the top of #messages_go_here");
                    }
                    newThreadView.$el.prependTo('#messages-go-here');
                }
            } else {
                if (insertAfterThread) {
                    // insert after the appropriate message
                    if (MERITCOMMONS_DEBUG) {
                        console.log("[hydrant:renderMessage] merging message_id " + newThreadView.parentMessage.get('message_id') + " after thread " + 
                            insertAfterThread.parentMessage.get('message_id'));
                    }
                    insertAfterThread.$el.after(newThreadView.$el);               
                } else {
                    // topward bound, but we aren't at the top, don't move the content.
                    if (MERITCOMMONS_DEBUG) {
                        console.log("[hydrant:renderMessage] queueing message_id " + newThreadView.parentMessage.get('message_id') + 
                            " for later insertion at the top of #messages_go_here");
                    }
                    hydrantView.hydrantPrependQueue.push(newThreadView);
                }
            }

            // Hide the no-messages div if the div was previously empty.  This clears 
            // out any type of "no results found" content.
            if ($('#no-messages').is(':visible')) {
                $('#no-messages').hide();
            }
        },
        // Add new, queued messages to the top
        addQueuedMessages: function() {
            if (this.hydrantPrependQueue.length > 0) {
                while ((threadView = this.hydrantPrependQueue.pop()) != null) {
                    threadView.parentMessageView.trigger('message:written_to_dom', 
                        threadView.$el.prependTo('#messages-go-here').css("display", "none").animate(
                            {
                                opacity: "show",
                                height: "show"
                            }, 
                        500), threadView.parentMessage.get('message_id'), 'new_message_load_from_queue'
                    );                    
                }
            }
        },
        requestMessages: function() {
            // Fetch more results
            var getMoreParams = {
                searchFilter : (typeof(searchOptions) != "undefined") ? searchOptions.query : null,
                after : this.lastThreadDate,
                afterId : this.lastThreadId,
                streams : this.subscriptionList
            };            

            window.MeritCommons.WebSocket.conn.send("get_more " + JSON.stringify(getMoreParams));
        },
        logCommands: function(e, data) {
            console.log("command response: " + data.body);
        },
        passesFilter: function(data) {
            // Strip out HTML from message body
            var html = $("<div>" + data.body + "</div>");
            var body = html.text();

            searchContent = (data.submitter_common_name + " " + body).toLowerCase();

            // add stream names
            $.each(data.streams, function(i, ele) {
                searchContent += " " + ele.stream_name;
            });

            searchFilterTerms = this.searchFilter.split(" ");

            var passedFilter = true;

            _.each(searchFilterTerms, function(searchTerm) { 
                if (searchContent.match(searchTerm.toLowerCase()) == null) {
                    passedFilter = false;
                }
            })

            return passedFilter;
        },
        mergeMessage: function(e, container) {
            var hydrantView = this;

            // un-nest the message from the container
            data = $.parseJSON(container.body);

            if (MERITCOMMONS_DEBUG) {
                console.log("[hydrant:mergeMessage] message " + data.message_id + " of type '" + data.render_as + "' received from the hydrant");
            }

            // Handle notifications differently.
            if (data.render_as == "notification") {
                return false;
            }

            // Ignore new threads if there's a search filter defined and the message doesn't pass it
            if ((typeof hydrantView.searchFilter != "undefined") && (!data.in_reply_to)) {
                if (!hydrantView.passesFilter(data)) {
                    return false;
                } 
            } 

            // If this is an update, try to find and update the model
            var matchedMessage;
            var matchedThreadView;
            var matchedMessageView;
            _.each(this.threadViews, function(threadView) {
                // Check if the message matches a parent thread
                if (data.message_id == threadView.parentMessage.get('message_id')) {
                    matchedMessage = threadView.parentMessage;
                    matchedThreadView = threadView;
                    matchedMessageView = threadView.parentMessageView;
                }

                if (data.thread_id == threadView.parentMessage.get('message_id')) {
                    matchedThreadView = threadView;
                }

                // Check if the message matches a reply
                _.each(threadView.threadReplyViews, function(view) {                    
                    if (data.message_id == view.message.get('message_id')) {
                        matchedMessage = view.message;
                        matchedMessageView = view;
                    }
                });
            });

            if (matchedMessage) {
                var message_in_current_view = false;
                if (stream_context) {
                    // see if this message still belongs here.
                    $.each(data.streams, function (i, msg_stream) {
                        if (typeof subscriptions != "undefined") {
                            $.each(subscriptions, function (sub_stream) {
                                if (msg_stream.stream_id == sub_stream) {
                                    message_in_current_view = true;
                                    return false;
                                }
                            });
                        }
                        if (message_in_current_view) {
                            return false;
                        }
                    });
                } else {
                    // message -> stream membership cannot be determined, so all messages shown are in the 
                    // current view, unless they have no streams.
                    if (data.streams.length > 0) {
                        message_in_current_view = true;
                    }
                }

                if (!message_in_current_view) {
                    // remove from the message collection, and from the threadViews array
                    hydrantView.messages.remove(matchedMessage);

                    var removedView;
                    var toUnsubscribe = { messages: [] };
                    if (typeof matchedThreadView != "undefined") {
                        // remove this thread altogether
                        removedView = this.threadViews.splice(this.threadViews.indexOf(matchedThreadView), 1).shift();
                        toUnsubscribe.messages.push(matchedThreadView.parentMessage.get('message_id'));
                        matchedThreadView.threadReplies.each(function(reply) {
                            toUnsubscribe.messages.push(reply.get('message_id'));
                        });
                    } else {
                        // remove this reply from the thread
                        removedView = matchedMessageView.threadView.threadReplyViews.splice(matchedMessageView.threadView.threadReplyViews.indexOf(matchedMessageView), 1).shift();
                        toUnsubscribe.messages.push(matchedMessageView.message.get('message_id'));
                        matchedMessageView.threadView.threadReplies.remove(matchedMessage);
                        matchedMessageView.threadView.parentMessage.set('number_of_replies', matchedMessageView.threadView.threadReplies.length);
                    }       
                    
                    // unsubscribe from these messages (if we have any)
                    if (toUnsubscribe.messages.length > 0) {
                        window.MeritCommons.WebSocket.conn.send("unsubscribe " + JSON.stringify(toUnsubscribe));            
                    }

                    // delete the message if it's in the prepend queue (it hasn't been rendered yet)
                    _.each(hydrantView.hydrantPrependQueue, function(queuedView, index) {
                        if (queuedView.parentMessage.get('message_id') == matchedMessage.get('message_id')) {
                            hydrantView.hydrantPrependQueue.splice( index, 1);
                        }
                    });

                    // stash away these so we can style things after we remove the message.
                    var $nextView, $commentBox;
                    var adjust_first = false;

                    if ($('.feed-message', removedView.$el).hasClass("first-comment")) {
                        adjust_first = true;

                        if ($('.feed-message', removedView.$el.next()).length) {
                            $nextView = $('.feed-message', removedView.$el.next());
                        } else {
                            $commentBox = $('.feed-comment', removedView.threadView.$el);
                        }
                    }

                    removedView.$el.slideUp({
                        done: function() {
                            if (adjust_first) {
                                if ($nextView && $nextView.length) {
                                    $nextView.addClass('first-comment');
                                } else {
                                    $commentBox.addClass('no-first-comment');
                                }
                            }
                            removedView.remove();
                        }
                    });

                } else {
                    matchedMessage.set(data);
                    var changed = matchedMessage.changedAttributes();
                    if (typeof changed['streams'] != "undefined" && typeof matchedThreadView != "undefined") {
                        // if we changed a stream we have to re-render to reflect the new stream list
                        var pmv = matchedThreadView.parentMessageView;
                        pmv.render();
                    }
                }
            } else if (matchedThreadView) {
                // Instantitate a message model and message view, and keep track of the model in a collection
                var message = new MessageModel(data);
                hydrantView.messages.add(message);

                matchedThreadView.addReplyObject(data);

                // Subscribe to this message.
                sub_message_ids.push(data.message_id);
            } else if (data.in_reply_to) {
                // Ignore this message.  It's likely a reply to a message that's not on the DOM.
            } else {
                // This is a new message, add it to the merge
                // Instantitate a message model and message view, and keep track of the model in a collection
                var message = new MessageModel(data);
                hydrantView.messages.add(message);

                // Subscribe to this message.
                sub_message_ids.push(message.get('message_id'));

                if (typeof message.get('thread_replies') != "undefined") {
                    // Make sure to subscribe to all the threaded replies too...
                    $.each(message.get('thread_replies'), function(i, v) {
                        sub_message_ids.push(v.message_id);
                    });
                }

                var threadView = new ThreadView({message : message});
                threadView.render();
                hydrantView.renderMessage(threadView);

                hydrantView.threadViews.push(threadView);

                if (this.lastThreadDate >= message.get('post_time')) {
                    this.lastThreadDate = message.get('post_time');
                    this.lastThreadId = message.get('message_id');
                }                
            }
        },
        subscribeToMessages: function(messages) {
            messages.each(function(message) {
                // thread parent
                sub_message_ids.push(message.get('message_id'));

                if (message.get('thread_replies')) {
                    // each thread reply
                    $.each(message.get('thread_replies'), function(k, v) {
                        sub_message_ids.push(v.message_id);
                    });
                }                
            });
        },
        addSubscriptions: function() {
            if (typeof subscriptions != 'undefined') {
                $.each(subscriptions, function (k, v) {
                    window.MeritCommons.WebSocket.conn.send("subscribe " + k);
                });
            }
        }
    });

    return Hydrant;
});