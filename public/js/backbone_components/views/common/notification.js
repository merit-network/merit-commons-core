  define([
    'jquery',
    'underscore',
    'backbone',
    'mustache',
    'backbone_components/models/common/message',
    'bootstrap'
], function($, _, Backbone, Mustache, MessageModel) {
    var Notification = Backbone.View.extend({
        className: 'notification',
        events: {
            //'click': 'toggleRead'
        },        
        initialize: function(opts) {
            this.notification = opts.notification;
            this.notification.bind('change', this.render, this);

            this.rendered = false;

            // recursive setTimeout keeps the notification time up to date every second.
            var self = this;
            var m_abbr = new Array("January", "February", "March",  "April", "May", "June", "July", 
                "August", "September", "October", "November", "December");
            function abbr_ago_loop () {
                setTimeout(function() {
                    var post_time = new Date(self.notification.get('post_time') * 1000);
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

                    var dayword = day > 1 ? "days" : "day";
                    var hrsword = hrs > 1 ? "hours" : "hour";
                    var minword = min > 1 ? "minutes" : "minute";
                    var secword = sec > 1 ? "seconds" : "second";

                    if (yrs >= 1) {
                        abbr_ago = m_abbr[post_time.getMonth()] + " " + zp_day + ", " + post_time.getFullYear();
                    } else if (day >= 1) {
                        abbr_ago = m_abbr[post_time.getMonth()] + " " + zp_day + ", " + post_time.getFullYear();
                    } else if (hrs >= 1) {
                        abbr_ago = hrs + " " + hrsword + " ago";
                    } else if (min >= 1) {
                        abbr_ago = min + " " + minword + " ago";
                    } else if (sec <= 0) {
                        abbr_ago = "Just now";
                    } else {
                        abbr_ago = sec + " " + secword + " ago";
                    }

                    // set the model
                    self.notification.set({ abbr_ago: abbr_ago });
                    
                    abbr_ago_loop();
                }, 60000);   
            }
            abbr_ago_loop();

            this.$('a.stream-link').tooltip({
                trigger: "hover"
            });            
        },

        render: function(callback) {
            var self = this;

            var notificationAttributes = self.notification.attributes;
            var messageId = self.notification.get('message_id');

            require(['text!templates/message/' + self.notification.get('render_as') + ".mustache"], function(t) {
                renderedTemplate = Mustache.render(t, {
                    message : notificationAttributes
                });

                self.$el.html(renderedTemplate);

                if ($.isFunction(callback)) {
                    callback();
                }                

                // mark us rendered.
                self.rendered = true;
            });
            
        }
    });        
    return Notification;
});
