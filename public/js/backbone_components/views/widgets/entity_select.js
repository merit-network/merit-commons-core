define([
    'jquery',
    'underscore',
    'backbone',
    'websocket',
    'backbone_components/views/widgets/select2_recipient_search_websocket_adapter',
    'select2/select2/selection/multiple',
    'select2/select2/selection/single',
    'select2/select2/utils',
    'select2',
    'bootstrap'
], function($, _, Backbone, WebSocket, WebSocketAdapter, MultipleSelection, SingleSelection, Utils) {
    var EntitySelectView = Backbone.View.extend({
        el: 'form.entity-select',

        initialize: function(es_config) {
            // propagate config down
            WebSocketAdapter.es_config = es_config;
            this.es_config = es_config;
        },

        render: function() {
            var self = this;
            var placeholder = {
                id: "",
                text: $('.meritcommons-entity-select', this.$el).prop('multiple') ? "Select some users..." : "Select a user..."
            }

            if (this.es_config.placeholder) {
                placeholder["text"] = this.es_config.placeholder;
            } else {
                this.es_config.placeholder = placeholder.text;
            }

            $('.meritcommons-entity-select', this.$el).select2({
                width: "100%",
                dataAdapter: WebSocketAdapter,
                placeholder: placeholder,
                allowClear: true,
                templateSelection: function(selection) {
                    var match_item = WebSocketAdapter.matches[selection.id];
                    if (match_item) {
                        return self.item_template_for(match_item, selection.text, 16);
                    } else {
                        return selection.text;
                    }
                },
                templateResult: function(result) {
                    var match_item = WebSocketAdapter.matches[result.id];
                    if (match_item) {
                        return self.result_template_for(match_item, result.text);
                    } else {
                        return result.text;
                    }
                }
            });
        },
        item_template_for: function(match, text, img_height) {
            // sensible default, makes img_height optional
            if (typeof(img_height) === "undefined") {
                img_height = 20;
            }

            var template = '<span>';
            if (match.entity_type == "user") {
                template += "<i class='fa fa-user'></i> " + text;
            } else if (match.entity_type == "stream") {
                var label = text;
                if (match.personal && match.author_count == 1) {
                    label = "My Followers";
                }
                template += "<i class='fa fa-streams'></i> " + label + " (" + match.subscriber_count + ")";
            } else {
                template += text;
            }

            template += '</span>';
            return $(template);
        },
        result_template_for: function(match, text) {
            // sensible default, makes img_height optional
            if (typeof(img_height) === "undefined") {
                img_height = 20;
            }

            var template = '<span>';
            if (match.entity_type == "user") {
                template += "<i class='fa fa-user'></i> <b>" + text + 
                    "</b>; " + match.title + ", " + match.organization;
            } else if (match.entity_type == "stream") {
                var subscriber_word = match.subscriber_count == 1 ? "subscriber" : "subscribers";
                var label = text;
                if (match.personal && match.author_count == 1) {
                    label = "My Followers";
                    match.description = "People following your personal stream";
                }
                template += "<i class='fa fa-streams'></i> <b>" + label + 
                    "</b>; " + match.subscriber_count + " " + subscriber_word;
                if (match.description != null) {
                    template += "; " + match.description;
                }
            } else {
                template += text;
            }

            template += '</span>';
            return $(template);
        }
    });

    // Our module now returns our view
    return EntitySelectView;
});