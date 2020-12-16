define([
    'jquery',
    'underscore',
    'backbone',
    'mustache',
    'typeahead',
    'text!templates/profile/edit_attribute_row.mustache',
    'text!templates/profile/edit_attribute_row_alert.mustache',
    'tagsInput',
], function($, _, Backbone, Mustache, Typeahead, editAttributeRowTemplate, editAttributeRowAlertTemplate) {
    var ProfileEditAttributeRowView = Backbone.View.extend({
        tagName: 'tr',
        events: {
            'keydown input' : 'onKeyDownInput',
            'keydown .attribute-values' : 'onKeyDownAttributeValues',
            'click .convert-to-list-link' : 'onClickConvertToListLink',
            'change .attribute-label' : 'onAttributeLabelChange',
        },
        initialize: function(options) {
            if (options != undefined) { 
                this.profileAttribute = options.profileAttribute;
                this.parentView = options.parentView;
            }

            this.alertRendered = false;
        },   
        // Keep the model in sync with newly entered input
        onKeyDownInput: function(e) {
            label = $('.attribute-label', this.$el).val();
            attributeVal = $('.attribute-values', this.$el).val();  
            this.profileAttribute.set('label', label);
            this.profileAttribute.set('values', attributeVal);
        },
        onKeyDownAttributeValues: function(e) {
            // Watch for situations where the data type is unknown and the user enters a comma.  If this occurs,
            // prompt the user to check if they may be trying to enter a list
            if ((e.keyCode == 188) && (this.profileAttribute.get('unknownDataType') == true)) {

                // Render an alert if one has not been rendered yet
                if (this.alertRendered == false) {
                    alertBox = Mustache.render(editAttributeRowAlertTemplate, {});
                    $(e.target).after(alertBox);
                    this.alertRendered = true;
                }
            }
        },
        onAttributeLabelChange: function() {
            newAttributeLabel = $('.attribute-label', this.$el).val();

            standardProfileAttributeSearch = this.parentView.standardProfileAttributes.where({
                "label" : newAttributeLabel
            })

            // There is a standard attribute where the label matches the inputted label.  Use the data type
            // of that standard attribute
            if (standardProfileAttributeSearch.length == 1) {
                standardProfileAttribute = standardProfileAttributeSearch[0];

                // This standard attribute has a different data type, change the text field
                if (standardProfileAttribute.get('dataType') != this.profileAttribute.get('dataType')) {
                    this.profileAttribute.set('label', standardProfileAttribute.get('label'));

                    if (standardProfileAttribute.get('dataType') == "S") {
                        this.profileAttribute.set('dataType','S');
                    } else {
                        this.profileAttribute.set('dataType','M');
                    }

                this.profileAttribute.set('unknownDataType', false);

                this.render();

                if (this.profileAttribute.get('dataType') == 'M') {
                    $('.attribute-values-list', this.$el).tagsInput({
                        defaultText: '',
                        });                
                    }
                }
            }
        },
        // Called if the user identifies the attribute list as a list
        onClickConvertToListLink: function() {
            this.profileAttribute.set('unknownDataType', false);
            this.profileAttribute.set('dataType', 'M');
            this.render();

            $('.attribute-values-list', this.$el).tagsInput({
                defaultText: '',
            });
        },    
        // Render the mustache template and update the element
        render: function() {
            profileAttribute = this.profileAttribute.toJSON();
            profileAttribute.isList = (this.profileAttribute.get('dataType') == 'M');
            profileAttribute.isString = (this.profileAttribute.get('dataType') == 'S');

            compiledTemplate = Mustache.render(editAttributeRowTemplate, {profileAttribute : profileAttribute});
            this.$el.html( compiledTemplate );         

            var attribute_labels = new Bloodhound({
                datumTokenizer: function(d) { return Bloodhound.tokenizers.whitespace(d.label); },
                queryTokenizer: Bloodhound.tokenizers.whitespace,
                local: standardProfileAttributes
            });

            attribute_labels.initialize();

            // Enable typeahead on the row
            $('.attribute-label', this.$el).typeahead(null, {
                source: attribute_labels.ttAdapter(),
                displayKey: 'label'
            });               
        }
    });
    // Our module now returns our view
    return ProfileEditAttributeRowView;
});