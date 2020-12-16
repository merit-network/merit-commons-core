  define([
    'jquery',
    'underscore',
    'backbone'
], function($, _, Backbone, Mustache) {
    var Scrollbar = Backbone.View.extend({
        initialize: function() {
            $(window).bind("scroll", _.bind(this.onScroll, this));
            this.inFetchZone = false;
        },
        onScroll: function() {            
            if ($(window).scrollTop() + $(window).height() > $(document).height() - 2600) { 
                if (!this.inFetchZone) {
                    this.inFetchZone = true;
                    this.trigger('scrollfetch');
                }

                // 2600 px is a lot, so we might need to trigger this here, too!
                if ($(window).scrollTop() == 0) {
                    this.trigger('scrolltop');
                }
            } else {
                if (this.inFetchZone) {
                    this.inFetchZone = false;
                }

                if ($(window).scrollTop() == 0) {
                    this.trigger('scrolltop');
                }
            }
        }
    });

    return Scrollbar;
});