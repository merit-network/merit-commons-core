define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrap',
    'bootstrap-dialog',
    'odometer',
], function($, _, Backbone, Bootstrap, BootstrapDialog, Odometer) {
    var CoinsDefaultView = Backbone.View.extend({
        el: $('.coin-default'),
    });

    return CoinsDefaultView;
});