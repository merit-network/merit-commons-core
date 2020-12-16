  define([
    'jquery',
    'underscore',
    'backbone',
], function($, _, Backbone) {
    var Message = Backbone.Model.extend({
        url: '/inbound'
    });

    return Message;
});