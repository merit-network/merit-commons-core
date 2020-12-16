define([
    'jquery',
    'underscore',
    'backbone',
    'backbone_components/views/common/hydrant',
    'backbone_components/views/common/navlist',
    'backbone_components/views/common/inbound',
    'backbone_components/views/common/thread',
    'backbone_components/views/common/sidebar'
], function($, _, Backbone, Hydrant, NavList, Inbound, Message, Sidebar) {
    var MergeDefaultView = Backbone.View.extend({
        initialize: function() {
            new Hydrant();
            new NavList();
            new Inbound();
            new Sidebar();
        },
    });
    // Our module now returns our view
    return MergeDefaultView;
});