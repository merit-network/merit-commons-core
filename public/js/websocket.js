define([
    'jquery',
    'underscore',
    'backbone',
    'modernizr',
    'utf8'
], function($, _, Backbone, Modernizr, utf8) {
    if (Modernizr.websockets) {    
        // only do this one time.
        if (window.MeritCommons == undefined) {
            window.MeritCommons = {};
            window.MeritCommons.WebSocket = {};
        } else {
            window.MeritCommons.WebSocket = {};
        }

        // we can now register Backbone Events on the object!
        _.extend(window.MeritCommons.WebSocket, Backbone.Events);

        // maintain what state MeritCommons thinks the websocket is in...
        window.MeritCommons.WebSocket.state = "disconnected";
        window.MeritCommons.WebSocket.connection_attempts = 0;
        window.MeritCommons.WebSocket.error_events = 0;

        window.onbeforeunload = function() {
            if (window.MeritCommons.WebSocket.conn) {
                window.MeritCommons.WebSocket.conn.onclose = function () {};
                window.MeritCommons.WebSocket.conn.onopen = function() {};
                window.MeritCommons.WebSocket.conn.onerror = function() {};
            }
        };

        // uuid code defined just the one time
        if (typeof(window.MeritCommons.WebSocket.new_uuid) !== "function") {
            window.MeritCommons.WebSocket.new_uuid = (function() {
              function s4() {
                return Math.floor((1 + Math.random()) * 0x10000)
                           .toString(16)
                           .substring(1);
              }
              return function() {
                return s4() + s4() + '-' + s4() + '-' + s4() + '-' +
                       s4() + '-' + s4() + s4() + s4();
              };
            })();
        }

        // message queue..
        window.MeritCommons.WebSocket.mqueue = [];

        if (!window.DISABLE_WEBSOCKETS) {
            if (MERITCOMMONS_DEBUG) {
                console.log("[websocket:init] DISABLE_WEBSOCKETS is false.. that means it's go-time!")
            }
            var init_websocket; var send_ping; var connect_websocket;

            window.MeritCommons.WebSocket.on('system:hydrant_migration', function (e, container) {
                var data = $.parseJSON(container.body);
                if (data.replacement_hydrant && data.migrate_in) {
                    console.log("Migrating to " + data.replacement_hydrant + " in " + data.migrate_in + "ms");
                    setTimeout(function() {
                        // remove the onclose handler so it doesn't try and reconnect via /myws
                        if (window.MeritCommons.WebSocket.conn) {
                            window.MeritCommons.WebSocket.conn.onclose = function () {};
                            window.MeritCommons.WebSocket.conn.onopen = function() {};
                            window.MeritCommons.WebSocket.conn.onerror = function() {};
                        }

                        window.MeritCommons.WebSocket.conn.close(1000, "Migrating to another application server");
                        window.MeritCommons.WebSocket.state = "migrating";
                        connect_websocket(data.replacement_hydrant);
                    }, data.migrate_in);
                }
            });
            
            window.MeritCommons.WebSocket.on('ping:reply', function (e, data) {
                var time = Math.round(new Date().getTime());
                var pong_time = data.body.match(/^pong (\d+)/);
                var ms = time - pong_time[1];
                console.log("[pong]: ping reply in " + ms + "ms");
                window.MeritCommons.WebSocket.last_ping_reply = time;
                window.MeritCommons.WebSocket.last_ping_latency = ms;

                // clear these on every successful pong.                
                window.MeritCommons.WebSocket.connection_attempts = 0;
                window.MeritCommons.WebSocket.error_events = 0;
            });

            flush_queue = function () {
                if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                    while (window.MeritCommons.WebSocket.mqueue.length > 0) {
                        WebSocket.prototype.send.call(this, window.MeritCommons.WebSocket.mqueue.shift());
                    }
                }

                // if there's still stuff in the queue, schedule a flush for now + 1s
                if (window.MeritCommons.WebSocket.mqueue.length > 0) {
                    setTimeout(flush_queue, 1000);
                }
            };

            send_ping = function (initial) {
                // only start this process once per page load!
                if ((initial && !window.MeritCommons.WebSocket.last_ping_reply) || !initial) {
                    if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                        var time = Math.round(new Date().getTime());
                        window.MeritCommons.WebSocket.conn.send("ping " + time);
                        window.MeritCommons.WebSocket.last_ping_sent = time;
                        if (window.MeritCommons.WebSocket.state != "connected") {
                            console.log("[ping] WebSocket in state '" + window.MeritCommons.WebSocket.state + "' but connection is open, setting to state 'connected'");
                            window.MeritCommons.WebSocket.state = "connected";
                        }
                        // next ping in 5m
                        setTimeout(send_ping, 300000);
                    } else {
                        if (window.MeritCommons.WebSocket.state != "migrating" && window.MeritCommons.WebSocket.state != "reconnecting") {
                            console.log("[ping] WebSocket in state '" + window.MeritCommons.WebSocket.state + "' but connection is closed, setting to state 'disconnected'");
                            window.MeritCommons.WebSocket.state = "disconnected";
                        }
                        console.log("[ping]: WebSocket readyState is not '1', rescheduling for +5 seconds");
                        console.log("[ping]: last ping reply received at " + window.MeritCommons.WebSocket.last_ping_reply + "; last ping sent at " + window.MeritCommons.WebSocket.last_ping_sent);
                        setTimeout(function() {
                            if (!window.DISABLE_WEBSOCKETS) {
                                if ((window.MeritCommons.WebSocket.last_ping_sent - window.MeritCommons.WebSocket.last_ping_reply) > 310000) {
                                    if (window.MeritCommons.WebSocket.conn.readyState == 1) {
                                        // the last times could be stale, and it looks like the socket's up now, let's try sending the ping again.
                                        send_ping();
                                    } else {
                                        // we need to re-connect the websocket, it's been gone for at least 2 pings.
                                        if (window.MeritCommons.WebSocket.state != "reconnecting") {
                                            // this process isn't already running, take things into our own hands!
                                            console.log("[ping]: ping timeout, reconnecting...");
                                            if (window.MeritCommons.WebSocket.conn) {
                                                window.MeritCommons.WebSocket.conn.onclose = function () {};
                                                window.MeritCommons.WebSocket.conn.onopen = function() {};
                                                window.MeritCommons.WebSocket.conn.onerror = function() {};
                                            }
                                            init_websocket();
                                        }
                                    }
                                } else {
                                    send_ping();
                                }
                            }
                        }, 5000);
                    }
                }
            };

            connect_websocket = function (ws_address) {
                if (ws_address) {
                    // make a websocket connection!
                    try {
                        window.MeritCommons.WebSocket.conn = new WebSocket(ws_address);

                        // we want to get this handler installed right away to ensure it gets called
                        window.MeritCommons.WebSocket.conn.onopen = function(e) {
                            var check_ready = function() {
                                if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                                    window.MeritCommons.WebSocket.state = "connected";
                                    window.MeritCommons.WebSocket.trigger('websocket:open', e);
                                    send_ping(true);

                                    // websocket re-opened, all on open handlers called, let's flush our message queue
                                    while (window.MeritCommons.WebSocket.mqueue.length > 0) {
                                        WebSocket.prototype.send.call(this, window.MeritCommons.WebSocket.mqueue.shift());
                                    }
                                } else {
                                    // the connect loop should deadend here.
                                    console.log("websocket onopen fired, but connection isn't ready");
                                    window.MeritCommons.WebSocket.websocket_exception = "open but no connection";
                                    window.DISABLE_WEBSOCKETS = true;
                                }
                            };
                            if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                                check_ready();
                            } else {
                                // give the websocket 3s to get it together.
                                setTimeout(check_ready, 3000);
                            }
                        };

                        window.MeritCommons.WebSocket.conn.send = function(data, args) {
                            // include a uuid for this call
                            if (typeof(args) == "object") {
                                var uuid;
                                if (args["request_id"] != undefined) {
                                    uuid = args["request_id"];
                                } else {
                                    uuid = window.MeritCommons.WebSocket.new_uuid().toUpperCase();
                                }

                                if (typeof(args["callback"]) == "function") {
                                    if (args["times"]) {
                                        if (args["times"] == 1) {
                                            window.MeritCommons.WebSocket.once(uuid, function(e, data) {
                                                args["callback"](e, data);
                                            });
                                        } else {
                                            var i = 0;
                                            var reinstall_callback = function() {
                                                if (i < args["times"]) {
                                                    // re-install our event handler until i == args["times"] -1
                                                    window.MeritCommons.WebSocket.once(uuid, function(e, data) {
                                                        ++i;
                                                        args["callback"](e, data);
                                                        reinstall_callback();
                                                    });
                                                }
                                            };

                                            // install it the first time
                                            window.MeritCommons.WebSocket.once(uuid, function(e, data) {
                                                args["callback"](e, data);
                                                ++i;
                                                reinstall_callback();
                                            });
                                        }
                                    } else {
                                        window.MeritCommons.WebSocket.on(uuid, function(e, data) {
                                            args["callback"](e, data);
                                        });
                                    }
                                }

                                if (!args["verbatim"]) {
                                    data = uuid + " " + data;
                                }
                            } else {
                                var uuid = window.MeritCommons.WebSocket.new_uuid().toUpperCase();
                                data = uuid + " " + data;
                            }
                            if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                                // flush the queue right now.
                                while (window.MeritCommons.WebSocket.mqueue.length > 0) {
                                    WebSocket.prototype.send.call(this, window.MeritCommons.WebSocket.mqueue.shift());
                                }
                                WebSocket.prototype.send.call(this, data);
                            } else {
                                window.MeritCommons.WebSocket.mqueue.push(data);
                                setTimeout(flush_queue, 1000);
                            }
                        };

                        window.MeritCommons.WebSocket.conn.onmessage = function(e) {
                            if (e != undefined) {
                                if (e.data != undefined) {
                                    // not sure why we need to utf8.decode() here, it is my understanding that websocket data should
                                    // be decoded by the time it gets in to the js interpreter.
                                    // var data = jQuery.parseJSON(e.data);
                                    var data;
                                    try {
                                        data = jQuery.parseJSON(utf8.decode(e.data));
                                    } catch (exception) {
                                        console.log(exception);
                                        console.log(e.data);
                                        data = e.data;
                                    }

                                    window.MeritCommons.WebSocket.trigger(data.ws_msgtype, e, data);
                                    window.MeritCommons.WebSocket.trigger(data.hydrant_request_id, e, data);
                                } else {
                                    window.MeritCommons.WebSocket.trigger('message:unknown', e);
                                }
                            }
                        };

                        window.MeritCommons.WebSocket.conn.onclose = function(e) {
                            window.MeritCommons.WebSocket.connection_attempts++;
                            window.MeritCommons.WebSocket.trigger('websocket:close', e);
                            window.MeritCommons.WebSocket.conn.onclose = function () {};
                            window.MeritCommons.WebSocket.conn.onopen = function() {};
                            window.MeritCommons.WebSocket.conn.onerror = function() {};
                            window.MeritCommons.WebSocket.state = "disconnected";

                            // if GET fails, try again in (decaying seconds, twice as long)
                            if (window.MeritCommons.WebSocket.error_events <= 5 && !window.DISABLE_WEBSOCKETS) {
                                setTimeout(function() {
                                    init_websocket();
                                }, (2000 * window.MeritCommons.WebSocket.connection_attempts));
                            }
                        };

                        window.MeritCommons.WebSocket.conn.onerror = function(e) {
                            var readyState = window.MeritCommons.WebSocket.readyState;
                            if (!(readyState == 0) || (readyState == 1)) {
                                window.MeritCommons.WebSocket.connection_attempts++;
                                window.MeritCommons.WebSocket.error_events++;
                                if (window.MeritCommons.WebSocket.error_events <= 5) {
                                    console.log("websocket error, reconnecting [" + window.MeritCommons.WebSocket.error_events + " error event(s)]");
                                    window.MeritCommons.WebSocket.connect_exception = "general websocket error";
                                    if (window.MeritCommons.WebSocket.conn) {
                                        // let the on-close handler do the reconnect..
                                        window.MeritCommons.WebSocket.conn.close();
                                    } else {
                                        // presumably there is no on-close handler installed, so we'll do it ourselves.
                                        window.MeritCommons.WebSocket.trigger('websocket:close', e);
                                        if (!window.DISABLE_WEBSOCKETS) {
                                            setTimeout(function() {
                                                init_websocket();
                                            }, (2000 * window.MeritCommons.WebSocket.connection_attempts));
                                        }
                                    }
                                } else {
                                    window.DISABLE_WEBSOCKETS = true;
                                    console.log("sorry, but your browser isn't able to hold a websocket connection, giving up.  please contact meritcommons@wayne.edu");
                                }
                            }
                        }

                        // we will be sending Blob objects.
                        window.MeritCommons.WebSocket.conn.binaryType = "blob";

                    } catch (exception) {
                        window.MeritCommons.WebSocket.connection_attempts++;
                        console.log("error creating websocket instance: " + exception);
                        window.MeritCommons.WebSocket.connect_exception = exception;
                        window.MeritCommons.WebSocket.state = "reconnecting";
                        window.MeritCommons.WebSocket.conn.onclose = function () {};
                        window.MeritCommons.WebSocket.conn.onopen = function() {};
                        window.MeritCommons.WebSocket.conn.onerror = function() {};

                        // if GET fails, try again in (decaying seconds, twice as long)
                        setTimeout(function() {
                            init_websocket();
                        }, (2000 * window.MeritCommons.WebSocket.connection_attempts));
                    }
                } else {
                    // refresh, since we most likely don't have a session!
                    document.location = "/";
                }
            };

            init_websocket = function () {
                if (!((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1) && !window.DISABLE_WEBSOCKETS)) {
                    var cb = Math.round(new Date().getTime());
                    window.MeritCommons.WebSocket.connection_attempts++;

                    // build the URL, it's getting complicated
                    var myws_url = "/myws?page_load_id=" + PAGE_LOAD_ID + "&_cb=" + cb + "&ws_state=" + window.MeritCommons.WebSocket.state;
                    if (window.MeritCommons.WebSocket.connect_exception) {
                        myws_url = myws_url + "&websocket_exception=" + window.MeritCommons.WebSocket.connect_exception;
                    }

                    $.get(myws_url, connect_websocket).fail(function() {
                        // if GET fails, try again in (decaying seconds)
                        setTimeout(function() {
                            window.MeritCommons.WebSocket.state = "reconnecting";
                            window.MeritCommons.WebSocket.conn.onclose = function () {};
                            window.MeritCommons.WebSocket.conn.onopen = function() {};
                            window.MeritCommons.WebSocket.conn.onerror = function() {};
                            init_websocket();
                        }, 1000 * window.MeritCommons.WebSocket.connection_attempts);
                    });
                }
            };

            init_websocket();
        } else {
            if (MERITCOMMONS_DEBUG) {
                console.log('[websocket:init] DISABLE_WEBSOCKETS is true; standing down!');
            }
        }
        return window.MeritCommons.WebSocket;
    }
});