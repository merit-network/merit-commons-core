define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrap'
], function($, _, Backbone) {
    var MyStreamsView = Backbone.View.extend({
        initialize: function() {
            $('button').bind('click', function(e) {
                $('#' + e.target.getAttribute('sub_aut_mod') + '_' + e.target.getAttribute('stream_id')).prop('checked', true);
            });

            $('#create-button').bind('click', function(e) {
                window.location = '/s/' + $('#create-input-stream-name').val();
            });

            $('#create-input-stream-name').keypress(function(event) {
                if(event.keyCode == 13) {
                    $('#create-button').click();
                }
            });
        },
    });
    // Our module now returns our view
    return MyStreamsView;
});
