define([
    'underscore',
    'backbone',
    'backbone_components/models/profile/standard_profile_attribute'
], function(_, Backbone, StandardProfileAttributeModel) {
    var StandardProfileAttributeCollection = Backbone.Collection.extend({
        model: StandardProfileAttributeModel,
    });

    return StandardProfileAttributeCollection;
});