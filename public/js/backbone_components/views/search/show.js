define([
    'jquery',
    'underscore',
    'backbone',
    'backbone_components/views/common/hydrant',
    'bootstrap-dialog',
    'bootstrap'
], function($, _, Backbone, Hydrant, BootstrapDialog) {
    var SearchShowView = Backbone.View.extend({
        initialize: function() {
            hydrant = new Hydrant(
                {
                    searchOptions: searchOptions, 
                    getMoreImmediate: true
                }
            );
            
            $('a.superclick').click(function(e) {

                MeritCommons.WebSocket.conn.send(
                    "superclick " + JSON.stringify({ short_loc: $(e.currentTarget).data('shortloc') }), 
                    {
                        callback: function(ws_e, data) {
                            var link_text = $('a:first', $(e.currentTarget).parent('div')).html();

                            BootstrapDialog.show({
                                title: "Pin Link: Success",
                                message: "You have successfully pinned the link to <strong>" + link_text + "</strong> to your 'My Frequent Links'.",
                                buttons: [{
                                    label: 'Close',
                                    action: function(bsd) {
                                        bsd.close();
                                    }
                                }]
                            });
                        },
                        times: 1
                    }
                );
                e.preventDefault();
            });
        },
    });
    // Our module now returns our view
    return SearchShowView;
});