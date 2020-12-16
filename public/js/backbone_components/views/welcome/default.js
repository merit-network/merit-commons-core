define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrap'
], function($, _, Backbone) {
    var Welcome = Backbone.View.extend({
        initialize: function() {
            $('.alert').alert();
        },
    });
    // Our module now returns our view
    return Welcome;
});
