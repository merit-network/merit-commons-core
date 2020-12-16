define([
    'jquery',
    'underscore',
    'backbone',
    'modernizr'
], function($, _, Backbone, Modernizr) {
    var FeatureDetector = Backbone.View.extend({
        initialize: function() {

            var supported_list = ["features_detected=1"];

            // JavaScript is obviously supported if we're here.
            supported_list.push("javascript_supported=1");

            // hixie-76 browsers were giving us a hard time.  hey guys iOS7 and Mavericks are free!
            if (Modernizr.websockets && !window.hixie76) {
                supported_list.push("websockets_supported=1");
            }

            if (Modernizr.hashchange) {
                supported_list.push("hashchange_supported=1")
            }

            // detect mobile/tablets
            if (Modernizr.deviceorientation) {
                supported_list.push("orientation_supported=1");
            }
            if (Modernizr.touch) {
                supported_list.push("touch_supported=1");
            }
            var cb = Math.round(new Date().getTime());

            $.ajax({
                url: "/session_variable?_cb=" + cb + "&" + supported_list.join('&'),
                success: function() {
                    $("#detect-features-notice").html($("#detect-features-notice").html() + " Features Detected!");
                    if (window.backTo) {
                        document.location = window.backTo;
                    } else {
                        document.location = "/";
                    }
                },
                error: function(e, status, error) {
                    $("#detect-features-notice").html($("#detect-features-notice").html() + 
                        " Feature Detection Failed!<br/>" +
                        "Error (" + status + ") " + error + "<br/>" +
                        "Feature String: " + supported_list.join('&')
                    );
                    var back_to = window.backTo ? window.backTo : "/";
                    $('#detecting').append(
                        '<meta id="detect-features-meta-refresh" http-equiv="refresh" content="2;' + 
                        "URL='/session_variable?_cb=" + cb + "&" + supported_list.join('&') + "&features_detected=1" + 
                        "&back=" + back_to + "'" + '"/>'
                    );
                }
            });
        },
    });
    return FeatureDetector;
});