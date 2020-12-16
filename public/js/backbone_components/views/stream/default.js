define([
    'jquery',
    'underscore',
    'backbone',
    'websocket',
    'backbone_components/views/common/hydrant',
    'backbone_components/views/common/navlist',
    'backbone_components/views/common/inbound',
    'backbone_components/views/common/thread'
], function($, _, Backbone, WebSocket, Hydrant, NavList, Inbound, Message) {
    var StreamShowView = Backbone.View.extend({
        events: {
        },

        el: $('#content-wrapper'),

        initialize: function() {
            new Hydrant({getMoreImmediate : true});  
            new NavList();
            new Inbound();

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
    });
    // Our module now returns our view
    return StreamShowView;
});
