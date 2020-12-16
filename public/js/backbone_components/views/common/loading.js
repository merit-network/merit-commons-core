define([
    'jquery',
    'underscore',
    'backbone',
    'websocket'
], function($, _, Backbone, WebSocket) {
    var Loading = Backbone.View.extend({
        initialize: function() {
            var attempts = 0;
            var check_session;
            check_session = function() {
                MeritCommons.WebSocket.conn.send("session_notice " + JSON.stringify({ attempt_id: attempt_id }), {
                    times: 1,
                    callback: function(e, data) {
                        attempts++;
                        if (data.body) {
                            var info_notice = $.parseJSON(data.body);
                            document.cookie = info_notice.cookie_string;
                            document.location = info_notice.location;
                        } else {
                            setTimeout(check_session, 5000);
                            $('#tries').html("Made " + attempts + " attempt(s) to establish session");
                        }
                    }
                });
            };

            window.MeritCommons.WebSocket.on('websocket:open', check_session, this);

            if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                check_session();
            }     
        }
    });

    return Loading;
});