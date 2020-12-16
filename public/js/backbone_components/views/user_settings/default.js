define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrapSwitch'
], function($, _, Backbone) {
    var UserSettingsView = Backbone.View.extend({
        el: 'div.user-settings',
        initialize: function() {
            var userSettingsView = this;

            // get and set state
            $.ajax('/user_config', {
                type: "POST",
                dataType: "json",
                success: function(data, status, xhr) {
                    $.each(Object.keys(data), function(i, ele) {
                        userSettingsView.setState(ele, data[ele][0]);
                    });
                    // turn this stuff on.
                    $(".btn").button();
                    $(".config-switch").bootstrapSwitch();
                    $("div.user-settings").show();
                }
            });

            // handle the switch changes
            $('.config-switch').on('switchChange.bootstrapSwitch', function(e, data) { 
                var config = 0;
                if (data) {
                    config = 1;
                }
                /*
                if ($(e.target).attr('name') == "links-on-left" && data) {
                    $('.config-switch[name=narrow-message-column]').bootstrapSwitch('state', false);
                } else if ($(e.target).attr('name') == "narrow-message-column" && data) {
                    $('.config-switch[name=links-on-left]').bootstrapSwitch('state', false);
                }
                */

                var submit_data = {};
                submit_data[$(e.target).attr('name')] = config;

                $.ajax('/user_config', {
                    type: "POST",
                    dataType: "json",
                    data: submit_data,
                });
            });

            // handle the radio buttons
            $('.btn').click(function() {
                var $radio = $(this).find('input');
                var submit_data = {};
                submit_data[$radio.attr('name')] = $radio.val();
                $.ajax('/user_config', {
                    type: "POST",
                    dataType: "json",
                    data: submit_data,
                });
            });
        },
        setState: function(option, value) {
            var $option = $('#' + option + "-" + value);
            if (value) {
                $option.attr('checked', true);
                if ($option.attr('type') == "radio") {
                    $option.parent('.btn').addClass('active');
                }
            }
        }
    });
    // Our module now returns our view
    return UserSettingsView;
});