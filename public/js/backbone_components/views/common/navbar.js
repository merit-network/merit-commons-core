define([
    'jquery',
    'underscore',
    'backbone',
    'backbone_components/models/common/message',
    'backbone_components/views/common/notifications',
    'mustache',
    'cron-parser',
    'bootstrap',
    'select2',
], function($, _, Backbone, Message, NotificationView, Mustache, Cron) {
    var NavbarView = Backbone.View.extend({
        el: "#navbar",
        events: {
            "click ul.navbar-nav.pull-right li a": "clearTooltip",
            "click .navbar-search-selection": "selectSearch",
            "click #navbar-submit-search": "submitSearch",
            "submit #navbar-search-form" : "submitSearch"
        },
        initialize: function() {
            var navbarView = this;
            new NotificationView();
            $('#navbar ul.navbar-nav.pull-right li').tooltip();
            $('#navbar-message-post-to').select2();
            if (window.show_navbar_popover == true) {
                $('#navbar-logo').popover('show');
                setTimeout(function() {
                    $('#navbar-logo').popover('hide');
                }, 7000);
            }
            if (window.EXTERNAL_BADGES) {
                if (typeof(navbarBadges) != "undefined" && window.navbarBadges.length) {
                    $.each(window.navbarBadges, function(i, ele) {
                        navbarView.updateNavbarBadge(ele.navlink_class, ele.badge_class, ele.badge_url, ele.badge_poll_interval, ele.badge_preflight_url);
                    });
                }
            }
            if (userId != undefined) {
                this.mindSessionTimeout();
            }

            var $primary_banner;
            $('.maintenance-alert').each(function() {
                var cron_expression = $(this).data('time');
                var timezone = $(this).data('timezone') ? $(this).data('timezone') : 'America/Detroit';

                if (cron_expression) {
                    var now = new Date();
                    var cron = cron_expression.split('+')[0];
                    var duration = cron_expression.split('+')[1];
                    var duration_stripped = duration ? parseInt(duration.replace(/\D/g,'')) : 1;

                    if (duration && duration.substr(-1) == 'h') {
                        duration_stripped = duration_stripped * 3600;
                    }

                    var start_time = new Date(Cron.parseExpression(cron, { currentDate: new Date(now.setSeconds(now.getSeconds() - duration_stripped)).toISOString(), tz: timezone }).next().toString());
                    var end_time = new Date(start_time);
                    end_time = new Date(end_time.setSeconds(end_time.getSeconds() + duration_stripped));

                    if (new Date() >= start_time && new Date() <= end_time) {
                        if ($primary_banner) {
                            $primary_banner.append('<hr />' + $(this).html());
                        } else {
                            $(this).fadeIn();
                            $primary_banner = $(this);
                        }
                    }
                }
            });
        },
        submitSearch: function(e) {
            e.preventDefault();
            $(e.currentTarget).blur();
            $('#navbar-submit-search > i').removeClass('fa-search').addClass('fa-spinner').addClass('fa-spin');

            var template = $('#navbar-search-form').data('as-template');
            if (template) {
                document.location = Mustache.render(template, { query: $('input.search-query').val() });
            } else {
                $('#navbar-search-form')[0].submit();
            }
        },
        selectSearch: function(e) {
            var selected = $(e.currentTarget).data('search');
            var sp = window.MeritCommons.search_providers[selected];

            if (sp) {
                $('.search-query', this.$el).attr('placeholder', sp.placeholder);
                $('.navbar-search-extra-placeholder').html('');
                if (sp.extra) {
                    $.each(sp.extra, function(k, v) {
                        $('.navbar-search-extra-placeholder').append('<input type="hidden" name="' + k + '" value="' + v + '"/>')
                    });
                }
                $('#navbar-search-form').data('as-template', '');
                if (sp.anchor_search) {
                    $('#navbar-search-form').data('as-template', sp.anchor_template);
                } else {
                    $('#navbar-search-form', this.$el).attr('action', sp.action);
                    $('.search-query', this.$el).attr('name', sp.query_param);
                }
            }

            e.preventDefault();
        },
        showTimeoutModal: function(counter) {
            var navbarView = this;

            $('#session-timeout-modal').modal({
                show: true,
                backdrop: 'static',
                keyboard: false,
            });

            $('#session-timeout-modal').on('hidden.bs.modal', function(e) {
                navbarView.mindSessionTimeout();
            });

            var modal_id = Math.round(new Date().getTime());
            window.MODAL_ID = modal_id;

            $('#session-expire-seconds').html(counter);
            if (counter == 1) {
                $('#session-expire-seconds-word').html("second");
            }

            $('#session-expire-extend').click(function(e) {
                $.ajax('/auth/session_extend', {
                    type: "GET",
                    dataType: "text",
                    success: function(data, status, xhr) {
                        $('#session-timeout-modal').modal('hide');

                        // stop the counter!
                        window.MODAL_ID = Math.round(new Date().getTime());
                    }
                });
                e.preventDefault();
            });

            $('#session-expire-logout').click(function(e) {
                document.location = "/auth?logout=1&back=/login?message=User%20Closed%20Session";
                e.preventDefault();
            });

            var counterFunc = function() {
                // don't run if this is a new modal.
                if (modal_id != window.MODAL_ID) {
                    return;
                }
                var secs = $('#session-expire-seconds').html();
                secs -= 1;
                if (secs == 1) {
                    $('#session-expire-seconds').html(secs);
                    $('#session-expire-seconds-word').html("second");
                } else if (secs <= 0) {
                    $('#session-expire-seconds').html(secs);
                    $('#session-expire-seconds-word').html("seconds");
                    document.location = "/auth?logout=1&back=/login?message=Session%20Timeout";
                } else {
                    $('#session-expire-seconds').html(secs);
                }
                setTimeout(function() {
                    counterFunc();
                }, 1000);
            }
            counterFunc();
        },
        mindSessionTimeout: function() {
            var navbarView = this;

            $.ajax('/auth/session_poll', {
                type: "GET",
                dataType: "text",
                success: function(data, status, xhr) {
                    if (data > 0) {
                        if (data <= 300) {
                            // show the modal w/ countdown.
                            navbarView.showTimeoutModal(data);
                        } else {
                            // maximum poll interval is 15 minutes.
                            var wait = (data / 2) * 1000;
                            if (wait > 900000) {
                                wait = 900000;
                            }

                            // schedule the next call.
                            setTimeout(function() {
                                navbarView.mindSessionTimeout();
                            }, wait);
                        }
                    } else if (data == -1) {
                        // session already expired, logout.
                        document.location = "/login?message=Session%20Timeout";
                    }
                }
            });            
        },
        updateNavbarBadge: function(navlink_class, badge_class, badge_url, badge_poll_interval, badge_preflight_url) {
            var navbarView = this;
            var $navlink = $('.' + navlink_class);
            var $badge = $('.' + badge_class);
            
            var original_badge_url = badge_url;
            var original_badge_preflight_url = badge_preflight_url;

            var cb = Math.round(new Date().getTime());
            // used to setup sessions for whatever the url might be.
            if (badge_preflight_url) {
                if (badge_preflight_url.indexOf('?') < 0) {
                    badge_preflight_url += '?no_heartbeat=1&_cb=' + cb;
                } else {
                    badge_preflight_url += '&no_heartbeat=1&_cb=' + cb;
                }
                $.ajax(badge_preflight_url, {
                    type: "GET",
                    dataType: "text",
                    async: false,
                });
            }

            if (badge_url.indexOf('?') < 0) {
                badge_url += '?_cb=' + cb;
            } else {
                badge_url += '&_cb=' + cb;
            }
            $.ajax(badge_url + '?_cb=' + cb, {
                type: "GET",
                dataType: "text",
                xhrFields: {
                    withCredentials: true
                },
                success: function(data, status, xhr) {
                    if ($badge.length) {
                        // badge is on the dom.
                        if (data == 0) {
                            $badge.remove();
                        } else {
                            $badge.html(data);
                        }
                    } else {
                        // badge does not exist!
                        if (data.length <= 5 && data != 0) {
                            // only add badges with data 5 chars or less.
                            $navlink.append('<span class="' + badge_class + ' badge pull-right">' + data + '</span>');   
                        }
                    }
                },
                error: function(xhr, status, errorString) {
                    console.log(xhr.statusText + ", " + status + ", " + errorString);
                },
                statusCode: {
                    302: function(xhr, status, errorString) {
                        console.log(errorString);
                    }
                }
            });
            setTimeout(function() {
                navbarView.updateNavbarBadge(navlink_class, badge_class, original_badge_url, badge_poll_interval, original_badge_preflight_url);
            }, badge_poll_interval * 1000);
        },
        clearTooltip: function(e) {
            var $el = $(e.currentTarget).parent('li');

            if ($el.is('.dropdown')) {
                // hide and disable the tooltip when dropwdown shown
                $el.one('shown.bs.dropdown', function () {
                    $el.tooltip('hide');
                    $el.tooltip('disable');
                });

                // enable tooltip when we put dropdown away
                $el.one('hidden.bs.dropdown', function () {
                     $el.tooltip('enable');
                });
            } else {
                // blur everything!
                $.each($el.find(':focus').andSelf(), function(i, ele) {
                    ele.blur();
                });
            }

            return true;
        },
    });
    return NavbarView;
});