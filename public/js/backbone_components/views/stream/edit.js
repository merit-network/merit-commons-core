define([
    'jquery',
    'underscore',
    'backbone',
    'websocket',
    'bootstrap-dialog',
    'bootstrapSwitch',
    'select2',
], function($, _, Backbone, WebSocket, BootstrapDialog) {
    var EditStreamView = Backbone.View.extend({
        self: this,
        el: $('.stream-editor'),
        events: {
            'click .save': 'edit',
            'keydown': 'key_event',
            'change #input-name': 'update_field',
            'change #input-url': 'update_field',
            'change #input-description': 'update_field',
            'change #input-keywords': 'update_field',
            'focus #input-name': 'clear_error',
            'focus #input-url': 'clear_error',
            'focus #input-description': 'clear_error',
            'focus #input-keywords': 'clear_error',
            'switchChange.bootstrapSwitch #streamPrivate': 'update_switch',
            'switchChange.bootstrapSwitch #streamList': 'update_switch',
            'switchChange.bootstrapSwitch #streamMember': 'update_switch',
            'switchChange.bootstrapSwitch #streamPost': 'update_switch',
            'switchChange.bootstrapSwitch #streamInvite': 'update_switch',
            'switchChange.bootstrapSwitch #streamInviteModerate': 'update_switch',
            'switchChange.bootstrapSwitch #streamListMembers': 'update_switch',
            'switchChange.bootstrapSwitch #streamRole': 'update_switch',
        },
        settings: {
            id: MeritCommons.stream_original_settings.id,
            name: MeritCommons.stream_original_settings.name,
            url: MeritCommons.stream_original_settings.url,
            description: MeritCommons.stream_original_settings.description, 
            keywords: MeritCommons.stream_original_settings.keywords,
            is_private: MeritCommons.stream_original_settings.is_private ? true : false,
            is_listed: MeritCommons.stream_original_settings.is_listed ? true : false,
            is_membership_open: MeritCommons.stream_original_settings.is_membership_open ? true : false,
            membership_includes_authorship: MeritCommons.stream_original_settings.membership_includes_authorship ? true : false,
            members_can_invite: MeritCommons.stream_original_settings.members_can_invite ? true : false,
            invites_require_approval: MeritCommons.stream_original_settings.invites_require_approval ? true : false,
            list_members: MeritCommons.stream_original_settings.list_members ? true : false,
            role_restricted: MeritCommons.stream_original_settings.role_restricted ? true : false,
            permitted_roles: MeritCommons.stream_original_settings.permitted_roles ? true : false,
        },
        previous_settings: {
            // for saving previous state when we do a toggle/disable
            is_listed: MeritCommons.stream_original_settings.is_listed ? true : false,
            is_membership_open: MeritCommons.stream_original_settings.is_membership_open ? true : false,
            invites_require_approval: MeritCommons.stream_original_settings.invites_require_approval ? true : false,
            permitted_roles: MeritCommons.stream_original_settings.permitted_roles ? true : false,
        },
        valid_settings: {
            name: true,
            url: true,
            description: true,
        },
        initialize: function() {
            console.log(this.settings);
            // initalize our role selector
            $roleSelector = $(".streamRole").select2({
                  placeholder: "All Roles",
            });

            // all of our switches
            $("#streamPrivate").bootstrapSwitch({
                onText: 'Private',
                onColor: 'danger',
                offText: 'Public',
                offColor: 'success',
                state: this.settings.is_private,
            });

            $("#streamList").bootstrapSwitch({
                onText: 'Yes',
                onColor: 'success',
                offText: 'No',
                offColor: 'danger',
                state: this.settings.is_listed,
            });

            $("#streamMember").bootstrapSwitch({
                onText: 'Yes',
                onColor: 'success',
                offText: 'No',
                offColor: 'danger',
                state: this.settings.is_membership_open,
            });

            $("#streamPost").bootstrapSwitch({
                onText: 'Yes',
                onColor: 'success',
                offText: 'No',
                offColor: 'danger',
                state: this.settings.membership_includes_authorship,
            });

            $("#streamInvite").bootstrapSwitch({
                onText: 'Yes',
                onColor: 'success',
                offText: 'No',
                offColor: 'danger',
                state: this.settings.members_can_invite,
            });

            $("#streamInviteModerate").bootstrapSwitch({
                onText: 'Yes',
                onColor: 'success',
                offText: 'No',
                offColor: 'danger',
                state: this.settings.invites_require_approval,
            });

            $("#streamListMembers").bootstrapSwitch({
                onText: 'Yes',
                onColor: 'success',
                offText: 'No',
                offColor: 'danger',
                state: this.settings.list_members,
            });

            $("#streamRole").bootstrapSwitch({
                onText: 'Yes',
                onColor: 'success',
                offText: 'No',
                offColor: 'danger',
                state: this.settings.role_restricted,
            });

            // these are valid when we load, so let's just update them, no need to verify
            if ($('#input_name').val()) {
                this.settings['name'] = $('#input_name').val();
            }
            if ($('#input_url').val()) {
                this.settings['url'] = $('#input_url').val();
            }

            if (this.settings.is_private) {
                $('.permInfo').text('Private streams can only be accessed by those you invite.')
                        
                $('#streamList').bootstrapSwitch('state', false);
                $('#streamList').bootstrapSwitch('disabled', true);
                
                $('#streamMember').bootstrapSwitch('state', false);
                $('#streamMember').bootstrapSwitch('disabled', true);
            }

            if (!this.settings.members_can_invite) {
                $('#streamInviteModerate').bootstrapSwitch('state', false);
                $('#streamInviteModerate').bootstrapSwitch('disabled', true);
            }

        },

        validate_input: function(setting, valid) {
            var hyphenated_setting = setting.replace(/_/g, '-');
            if (valid) {
                $('#input-' + hyphenated_setting).closest('.form-group').removeClass('has-error').addClass('has-success');
                $('#input-' + hyphenated_setting).closest('.form-group').find('.form-control-feedback').html('<i class="fa fa-check"></i>').show();
                $('#input-' + hyphenated_setting).closest('.form-group').find('.input-error').remove();
                $('#status-' + hyphenated_setting).html('(success)');
                if (setting in this.valid_settings) {
                    this.valid_settings[setting] = true;
                }
            } else {
                if (setting in this.valid_settings) {
                    $('#input-' + hyphenated_setting).closest('.form-group').removeClass('has-success').addClass('has-error');
                    $('#input-' + hyphenated_setting).closest('.form-group').find('.form-control-feedback').html('<i class="fa fa-times"></i>').show();
                    $('#status-' + hyphenated_setting).html('(error)');
                    this.valid_settings[setting] = false;
                } else {
                    $('#input-' + hyphenated_setting).closest('.form-group').removeClass('has-success');
                    $('#input-' + hyphenated_setting).parent().children('.form-control-feedback').hide();
                }
            }

            var total = 0;
            var num_invalid = 0;

            $.each(this.valid_settings, function(setting, isValid) {
                if (!isValid) {
                    num_invalid++;
                }
                total++;
            });

            if (num_invalid > 0) {
                $('.save').attr('disabled', 'disabled');
            } else {
                $('.save').removeAttr('disabled');
            }
        },

        clear_error: function(ev) {
            var setting = $(ev.target).data('update');
            $('#input-' + setting).closest('.form-group').removeClass('has-error');
            $('#input-' + setting).closest('.form-group').find('.form-control-feedback').html('');
            $('#input-' + setting).closest('.form-group').find('.input-error').remove();
            $('.save').prop('disabled', false);
        },

        error_handler: function(error_data) {
            var field_matches = /validation failed for field '([^']+)'/.exec(error_data.body);
            var validation_matches = /field is like \(\?\^\:([^\)]+)/.exec(error_data.body);

            if (field_matches && validation_matches) {
                var field = field_matches[1];
                var validation = validation_matches[1];

                if (field in this.valid_settings) {
                    this.valid_settings[field] = false;
                }

                $('#table-status-' + field).html('<i class="fa fa-times"></i>');
                $('#input-' + field).closest('.form-group').removeClass('has-success').addClass('has-error');
                $('#input-' + field).closest('.form-group').find('.form-control-feedback').html('<i class="fa fa-times"></i>').show();
                if (!$('#input-' + field).closest('.form-group').children('.input-error').length) {
                    var field_name = $('#input-' + field).closest('.form-group').find('label').html();
                    $('#input-' + field).closest('.form-group').append('<p class="help-block input-error"><small><strong>' + field_name + '</strong> requires ' + VALIDATION_ERRORS[validation] + '</small></p>');
                }
                $('#status-' + field).html('(error)');
                $('.save').prop('disabled', true).html('Save Changes');

                var collapse = $('#table-' + field).closest('tr').find('a').attr('href');
                if (!$($(collapse).collapse(parent)[0]).hasClass('in')) {
                    $('#table-' + field).closest('tr').find('a').trigger('click');
                }
            } else {
                this.dialog = BootstrapDialog.show({
                    title: 'An Error Has Occured',
                    message: '<p style="word-wrap: break-word;">' + error_data.body + '</p>',
                    cssClass: 'stream-editor-error-dialog',
                    buttons: [{
                        id: 'error-ok',
                        label: 'Ok',
                        action: function(dialog) {
                            dialog.close();
                        }
                    }],
                });
            }
        },

        edit: function() {
            var self = this;
            $('this').attr('disabled', 'disabled').html('Updating Stream... ').append('<i class="fa fa-spinner fa-spin"></i>');
            
            MeritCommons.WebSocket.conn.send("stream update " + JSON.stringify(this.settings), {
                callback: function(e, data) {
                    if (data.ws_msgtype == 'cmdresponse:error') {
                        self.error_handler(data);
                    } else {
                        var data = JSON.parse(data.body);
                        var message;
                        if (data.success) {
                            message = '<p style="word-wrap: break-word;">Stream updated succesfully.</p>';
                        } else if (data.error) {
                            message = '<p style="word-wrap: break-word; color: red;">An error has occurred: ' + data.error + '</p>';
                        } else {
                            message = '<p style="word-wrap: break-word; color: red;">An error has occurred.</p>';
                        }
                        self.dialog = BootstrapDialog.show({
                            title: 'Edit Stream',
                            message: message,
                            cssClass: 'stream-editor-response-dialog',
                            buttons: [{
                                id: 'response-ok',
                                label: 'Ok',
                                action: function(dialog) {
                                    dialog.close();
                                }
                            }],
                            onhide: function() {
                                if (data.url) {
                                    window.location.replace(data.url);
                                }
                            },
                        });
                        $('.save').prop('disabled', false).html('Save Changes');
                    }
                }   
            });
        },
        
        verify: function(data, isInput) {
            var self = this;
            MeritCommons.WebSocket.conn.send("stream verify " + JSON.stringify(data), {
                callback: function(e, data) {
                    data = JSON.parse(data.body);
                    var valid = data.valid;
                    var setting = data.verified;

                    if (valid) {
                        if (isInput) {
                            self.validate_input(setting, true);
                        }
                        $('#table_status_' + setting).html('<i class="fa fa-check"></i>');
                    } else {
                        if (isInput) {
                            self.validate_input(setting, false);
                        }
                        $('#table_status_' + setting).html('<i class="fa fa-times"></i>');
                    }
                }
            });
        },

        update: function(setting, val, isInput) {
            var hyphenated_setting = setting.replace(/_/g, '-');
            this.settings[setting] = val;

            if (typeof val == 'boolean') {
                val = val ? 'Yes' : 'No';
            }

            $('#table-' + hyphenated_setting).html(val);

            var valid = false;

            if (val.length > 0) {
                valid = true;
            }

            // handling url validation
            if (setting == 'url') {
                var data = {
                    attribute: 'url',
                    id: this.settings.id,
                    url: val,
                };

                this.verify(data, true);  
            } else {
                if (valid) {
                    if (isInput) {
                        this.validate_input(setting, true);
                    }
                    $('#table_status-' + hyphenated_setting).html('<i class="fa fa-check"></i>');
                } else {
                    if (isInput) {
                        this.validate_input(setting, false);
                    }
                    if (setting in this.valid_settings) {
                        $('#table_status-' + hyphenated_setting).html('<i class="fa fa-times"></i>');
                    } else {
                        $('#table_status-' + hyphenated_setting).html('N/A');
                    }
                }
            }
        },

        update_field: function(ev) {
            this.update($(ev.target).data('update'), $(ev.target).val(), true);
        },
        
        update_switch: function(ev) {
            var setting = $(ev.target).data('update');
            var state = $(ev.target).bootstrapSwitch('state');

            switch (setting) {
                case 'is_private':
                    if (state) {
                        $('.permInfo').text('Private streams can only be accessed by those you invite.')
                        
                        this.previous_settings.is_listed = $('#streamList').bootstrapSwitch('state');
                        $('#streamList').bootstrapSwitch('state', false);
                        $('#streamList').bootstrapSwitch('disabled', true);
                        this.update('is_listed', false);
                        
                        this.previous_settings.is_membership_open = $('#streamMember').bootstrapSwitch('state');
                        $('#streamMember').bootstrapSwitch('state', false);
                        $('#streamMember').bootstrapSwitch('disabled', true);
                        this.update('is_membership_open', false);
                    } else {
                        $('.permInfo').text('Public streams can be viewed by anyone.')
                        
                        $('#streamList').bootstrapSwitch('disabled', false);
                        $('#streamList').bootstrapSwitch('state', this.previous_settings.is_listed);
                        this.update('is_listed', this.previous_settings.is_listed);
                        
                        $('#streamMember').bootstrapSwitch('disabled', false);
                        $('#streamMember').bootstrapSwitch('state', this.previous_settings.is_membership_open);
                        this.update('is_listed', this.previous_settings.is_membership_open);
                    }
                    break;
                case 'members_can_invite':
                    if (state) {
                        $('#streamInviteModerate').bootstrapSwitch('disabled', false);
                        $('#streamInviteModerate').bootstrapSwitch('state', this.previous_settings.invites_require_approval);
                    } else {
                        this.previous_settings.invites_require_approval = $('#streamInviteModerate').bootstrapSwitch('state');
                        $('#streamInviteModerate').bootstrapSwitch('state', false);
                        $('#streamInviteModerate').bootstrapSwitch('disabled', true);
                    }
                    break;
                case 'role_restricted':
                    if (!state) {
                        $(".streamRole").prop('disabled', true);
                        $roleSelector.select2({
                            placeholder: "All Roles",
                        });
                    } else {
                        $(".streamRole").prop('disabled', false);
                        $roleSelector.select2({
                            placeholder: "Select Permitted Roles",
                        });
                    }
                    break;
            }

            this.update(setting, state);
        },

        key_event: function(ev) {
            if (ev.keyCode == 13 && ev.target.nodeName != "TEXTAREA") {
                this.update($(ev.target).data('update'), $(ev.target).val(), true);
                this.edit();
            }
        }
    });

    return EditStreamView;
});