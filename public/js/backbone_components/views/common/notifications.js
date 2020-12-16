  define([
    'jquery',
    'underscore',
    'backbone',
    'mustache',
    'modernizr',
    'websocket',
    'emoji',
    'noty',
    'backbone_components/views/common/scrollbar',
    'backbone_components/views/common/notification',
    'backbone_components/models/common/message',    
    'backbone_components/collections/messages',    
    'select2'
], function($, _, Backbone, Mustache, Modernizr, WebSocket, Noty, Emoji, Scrollbar, NotificationView, MessageModel, MessageCollection) {
    var Notification = Backbone.View.extend({
        el: '#notifications-go-here',
        events: {
            'mousewheel': 'preventPageScroll',
            'DOMMouseScroll': 'preventPageScroll'
        },
        initialize: function(opts) {
            var notificationsView = this;

            // Browser notifications.
            if (userId) { // don't bother people with notifications unless they're logged in
                if (!("Notification" in window)) {
                    console.log("Notifications are not supported in this browser.");
                } else if (window.Notification.permission !== 'denied') {
                    // Ask for permission to use browser notifications.
                    window.Notification.requestPermission();
                }
            }

            if (Modernizr.websockets && typeof notifications != 'undefined') {
                // Load notifications already embedded in the HTML
                this.notifications = new MessageCollection(notifications);

                // for storing instantiated views
                this.notificationViews = [];

                // we is not rendered.
                this.rendered = false;

                if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                    this.subscribeToNotificationInbox();
                } else {
                    // WebSocket isn't ready, so when it is let's subscribe then.
                    window.MeritCommons.WebSocket.on('websocket:open', function() {
                        notificationsView.subscribeToNotificationInbox();
                    });
                }
                
                // render notifications
                notificationsView.render();

                window.MeritCommons.WebSocket.on('message:subscribed', this.mergeNotification, this);
            }

            this.$el.parent('.notification-dropdown').bind("scroll", _.bind(this.onScroll, this));
            $('.notification-section').bind("shown.bs.dropdown", _.bind(this.markNotificationsRead, this));
        },
        markNotificationsRead: function(e, bse, toMarkRead, callback) {
            if (typeof(toMarkRead) == 'undefined') {
                toMarkRead = {};
                this.notifications.each(function(notification) {
                    if (notification.get('read') != 1) {
                        toMarkRead[notification.get('message_id')] = "_read";
                    }
                });
            }

            if (Object.keys(toMarkRead).length > 0) {
                window.MeritCommons.WebSocket.conn.send("mark_message " + JSON.stringify({mark_payload: toMarkRead}));
            }

            // clear badge
            $('.unseen-notifications').remove();

            // clear title indicator
            var title = $('title').html();
            title = title.replace(/\(\d+\) /, '');
            $('title').html(title);
            if ($.isFunction(callback)) {
                callback();
            }
        },
        onScroll: function() {
            if (this.$el.parent('.notification-dropdown').scrollTop() + this.$el.parent('.notification-dropdown').outerHeight() > this.$el.parent('.notification-dropdown')[0].scrollHeight - 125) {
                window.MeritCommons.WebSocket.conn.send("get_more_notifications " + JSON.stringify({ 
                    beforeId: _.last(this.notificationViews).notification.get('message_id')
                }));
            }
        },
        mergeNotification: function(e, container) {
            // unpack the actual notification from the hydrant message
            data = $.parseJSON(container.body);

            // we only handle notifications
            if (data.render_as != "notification") {
                return false;
            }

            // no, this.
            notificationsView = this;

            var matchedNotificationView;
            var insertAfterNotificationView;
            _.each(this.notificationViews, function(notificationView) {
                if (data.message_id == notificationView.notification.get('message_id')) {
                    matchedNotificationView = notificationView;
                } else if (data.post_time <= notificationView.notification.get('post_time')) {
                    insertAfterNotificationView = notificationView;
                }
            });

            notificationPreviouslyExisted = false;
            // get rid of what's here, and let the rest of the code put it where it goes now.
            if (matchedNotificationView) {
                // here we subtract from the count, a notification was marked as read.
                if (!matchedNotificationView.notification.get('read')) {
                    var new_count = parseInt($('.unseen-notifications').html()) - 1;
                    if (new_count == 0) {
                        // clear badge
                        $('.unseen-notifications').remove();

                        // clear title indicator
                        var title = $('title').html();
                        title = title.replace(/\(\d+\) /, '');
                        $('title').html(title);
                    } else {
                        $('.unseen-notifications').html(new_count);
                        
                        var title = $('title').html();
                        var tinc = title.match(/^\(*(\d*)\)*/);
                        var old_val = tinc[1];
                        title = title.replace("\(" + old_val + "\)", "\(" + new_count + "\)");
                        $('title').html(title);
                    }
                }

                notificationPreviouslyExisted = true;
                notificationsView.notifications.remove(matchedNotificationView.notification);
                matchedNotificationView.remove();

                // remove this from the list!
                notificationsView.notificationViews.splice(notificationsView.notificationViews.indexOf(matchedNotificationView), 1);
            }

            // it's new, let's add it to the bundle.
            var notification = new MessageModel(data);
            notificationsView.notifications.add(notification);

            if ($('#no-notifications').is(':visible')) {
                // hide since we're about to add notifications.
                $('#no-notifications').hide();
            }

            // create the container where it goes
            if (insertAfterNotificationView) {
                insertAfterNotificationView.$el.after('<a id="' + notification.get('message_id') + '" href="' + notification.get("notification_href") + '" class="notification media dropdown-block-section"></a>');

                // create the view
                var notificationView = new NotificationView({
                    el: '#' + notification.get('message_id'), 
                    notification: notification 
                });

                // put this in the right spot in the array.
                notificationsView.notificationViews.splice(notificationsView.notificationViews.indexOf(insertAfterNotificationView) + 1, 0, notificationView);
            } else {
                $('#notifications-go-here').prepend('<a id="' + notification.get('message_id') + '" href="' + notification.get("notification_href") + '" class="notification media dropdown-block-section"></a>');
                
                // create the view
                var notificationView = new NotificationView({
                    el: '#' + notification.get('message_id'), 
                    notification: notification 
                });

                // append this to the array.
                notificationsView.notificationViews.push(notificationView);
            }

            notificationView.render();

            // new notification, window's focused.
            if (!notificationPreviouslyExisted && !notification.get('read')) {
                
                var noty_text = '<div class="pull-left" style="padding-right: 3px;"><img class="media-object img-rounded" src="' + 
                    notification.get('submitter_profile_tiny_url') + '"/></div><div>' + 
                    notification.get('body') + '</div><i style="padding-bottom: 5px;" class="pull-right ' + notification.get('notification_icon') + '"></i>';
                if (window.NOTIFICATION_SOUNDS) {
                    noty_text += '<audio autoplay src="/audio/bip.mp3"></audio></div>';
                }

                var n = noty({
                    layout: 'bottomRight',
                    theme: 'defaultTheme',
                    type: 'information',
                    text: noty_text,
                    timeout: 10000,
                    maxVisible: 5,
                    callback: {
                        onCloseClick: function() {
                            var toMarkRead = {};
                            toMarkRead[notification.get('message_id')] = '_read';
                            notificationsView.markNotificationsRead(false, false, toMarkRead, function() {
                                document.location = notification.get("notification_href");
                            });
                        }
                    }
                });
            }

            if (notification.get('read') != 1) {
                if ($('.unseen-notifications').length) {
                    var new_count = parseInt($('.unseen-notifications').html()) + 1;
                    $('.unseen-notifications').html(new_count);
                    
                    var title = $('title').html();
                    var tinc = title.match(/^\(*(\d*)\)*/);
                    var old_val = tinc[1];
                    title = title.replace("\(" + old_val + "\)", "\(" + new_count + "\)");
                    $('title').html(title);
                } else {
                    $('.notification-badge-goes-here').after('<span class="unseen-notifications notification-badge badge pull-right">1</span>');
                    $('title').html("(1) " + $('title').html());
                }
                if ($('.notification-dropdown').is(':visible')) {
                    this.markNotificationsRead();
                }
            }

            // Browser notification
            
            if ("Notification" in window) {
                if (window.Notification.permission === "granted" && notification.get('read') != 1 && !notificationPreviouslyExisted) {
                    var browserNotification = new window.Notification('MeritCommons', {
                        body: notification.get('stripped_body'),
                        icon: notification.get('submitter_profile_thumb_url'),
                        tag: notification.get('message_id'),
                    });

                    setTimeout(function() {
                        browserNotification.close();
                    }, 5000);
                }
            }
        },
        preventPageScroll: function(e) {
            var scrollTo = null;

            if (e.type == 'mousewheel') {
                scrollTo = (e.originalEvent.wheelDelta * -1);
            }
            else if (e.type == 'DOMMouseScroll') {
                scrollTo = 40 * e.originalEvent.detail;
            }

            if (scrollTo) {
                e.preventDefault();
                this.$el.parent('.notification-dropdown').scrollTop(scrollTo + this.$el.parent('.notification-dropdown').scrollTop());
            }
        },
        render: function() {
            var notificationsView = this;

            if (!notificationsView.rendered) {
                if (this.notifications.length > 0) {
                    // Hide the no notifications message.
                    $('#no-notifications').hide();
                }

                this.notifications.each( function(notification) {
                    $('#notifications-go-here').append('<a id="' + notification.get('message_id') + '" href="' + notification.get("notification_href") + '" class="notification media dropdown-block-section"></a>')
                    var notificationView = new NotificationView({
                        el: '#' + notification.get('message_id'),
                        notification: notification
                    });

                    notificationView.render();
                    notificationsView.notificationViews.push(notificationView);
                    if (notification.get('read') != 1) {
                        if ($('.unseen-notifications').length) {
                            // update the badge
                            var new_count = parseInt($('.unseen-notifications').html()) + 1;
                            $('.unseen-notifications').html(new_count);
                            
                            // update the title
                            var title = $('title').html();
                            var tinc = title.match(/^\(*(\d*)\)*/);
                            var old_val = tinc[1];
                            title = title.replace("\(" + old_val + "\)", "\(" + new_count + "\)");
                            $('title').html(title);
                        } else {
                            $('.notification-badge-goes-here').after('<span class="unseen-notifications notification-badge badge">1</span>');

                            $('title').html("(1) " + $('title').html());
                        }
                    }
                });
                notificationsView.rendered = true;
            }

        },
        subscribeToNotificationInbox: function() {
            window.MeritCommons.WebSocket.conn.send("subscribe " + my_notification_inbox);
        }
    });

    return Notification;
});