define([
    'underscore',
    'backbone',
    'backbone_components/models/profile/profile_attribute'
], function(_, Backbone, ProfileAttributeModel){
    var ProfileAttributeCollection = Backbone.Collection.extend({
        model: ProfileAttributeModel,
    });

    return ProfileAttributeCollection;
});