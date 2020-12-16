define([
    'jquery',
    'underscore',
    'backbone',
    'backbone_components/views/common/hydrant',
    'backbone_components/views/common/navlist',
    'backbone_components/views/common/thread',
    'backbone_components/views/common/inbound',
], function($, _, Backbone, Hydrant, NavList, Message, Inbound) {
    var MessageShowView = Backbone.View.extend({
        initialize: function() {
            // open comments up on load!
            new Hydrant({
                singleThread : true
            });  

            new NavList();
            new Inbound();
        }
    });
    // Our module now returns our view
    return MessageShowView;
});