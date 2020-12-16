define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrap',
    'bootstrap-dialog'
], function($, _, Backbone, Bootstrap, BootstrapDialog) {
    var ScratchView = Backbone.View.extend({
        initialize: function() {
            // BootstrapDialog.show({
            //     title: 'Hydrant Error: Broken pipe',
            //     message: "There was an error doing a thing with the thing.",
            //     buttons: [{
            //         id: 'error-ok',
            //         label: 'Ok',
            //         action: function(dialog) {
            //             dialog.close();
            //         }
            //     }]
            // });
        },
    });
    // Our module now returns our view
    return ScratchView;
});