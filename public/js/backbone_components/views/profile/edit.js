define([
    'jquery',
    'underscore',
    'backbone',
    'backbone_components/collections/profile_attributes',
    'backbone_components/collections/standard_profile_attributes',
    'backbone_components/models/profile/profile_attribute',
    'backbone_components/views/profile/edit_attribute_row',
    'bootstrapFileinput',
    'websocket',
    'bootstrap',
], function($, _, Backbone, ProfileAttributeCollection, StandardProfileAttributeCollection, ProfileAttributeModel, ProfileEditAttributeRowView, FileInput, WebSocket) {
    var ProfileEditView = Backbone.View.extend({
        el: '#profile-attributes tbody',
        initialize: function() {
            // Collect the standard attribute labels for typeahead
            this.standardProfileAttributeLabels = $.map(standardProfileAttributes, function(n,i) { 
                return n.label; 
            });

            // Create a collection from the bootstrapped standard profile attributes
            this.standardProfileAttributes = new StandardProfileAttributeCollection(standardProfileAttributes);

            // Load the bootstrapped profile attributes
            this.profileAttributes = new ProfileAttributeCollection(profileAttributes);

            this.profileAttributes.bind("change", this.onProfileAttributesChange, this);

            $('#remove_profile_picture').click(function() {
                window.MeritCommons.WebSocket.conn.send('remove_profile_picture ' + JSON.stringify({}), {
                    callback: function(e, data) {
                        location.reload();
                    }
                });
            });
        },
        addBlankAttribute: function() {
            profileAttribute = new ProfileAttributeModel({
                id: undefined, // new ID
                dataType: "S", // string by default
                unknownDataType: true, // by default, data type is unknown for new rows                
                label: "",
                values: "",
            });

            this.profileAttributes.add(profileAttribute);

            profileEditAttributeRowView = new ProfileEditAttributeRowView({parentView : this, profileAttribute : profileAttribute});
            profileEditAttributeRowView.render();
            this.$el.append(profileEditAttributeRowView.el);            
        },
        onProfileAttributesChange: function() {
            // Add a new row if needed
            blankAttributesMatch = this.profileAttributes.where({
                "label" : "",
            });

            if (blankAttributesMatch.length == 0) {
                this.addBlankAttribute();
            }
        },  
        render: function() {
            var self = this;

            // Instantiate a row view for each model
            this.profileAttributes.each(function (profileAttribute) {
                profileEditAttributeRowView = new ProfileEditAttributeRowView({
                    parentView : self, 
                    profileAttribute : profileAttribute
                });

                profileEditAttributeRowView.render();
                self.$el.append(profileEditAttributeRowView.el);
            });          

            $('.attribute-values-list').tagsInput({
                defaultText: ''
            });

            // Add the first blank row in addition to the existing profile attributes
            this.addBlankAttribute();            
        }
    });
    // Our module now returns our view
    return ProfileEditView;
});