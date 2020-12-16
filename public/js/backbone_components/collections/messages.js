define([
    'underscore',
    'backbone',
    'backbone_components/models/common/message'
], function(_, Backbone, MessageModel){
    var MessageCollection = Backbone.Collection.extend({
        model: MessageModel
    });

    return MessageCollection;
});