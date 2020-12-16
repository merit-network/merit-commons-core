define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrap',
    'bootstrap-dialog',
    'websocket',
], function($, _, Backbone, Bootstrap, BootstrapDialog, WebSocket) {
    var AdminView = Backbone.View.extend({
        el: $('.coin-admin'),
        events: {
            'click .check-all': 'check_all',
            'change .request': 'update_check_all',
            'click .respond-multiple': 'respond_multiple',
            'click .respond': 'respond_single',
            'click #credit': 'credit_event',
            'keydown': 'key_event',
        },
        dialog: '',
        credit_event: function(ev) {
            var amount = 0;
            if (/^[0-9,]*$/.exec($('#amount').val())) {
                var amount = parseInt($('#amount').val().replace(/,/g, ''));
            }
            var recipient = $('select[name=recipient]').select2('data')[0];

            var message;

            if (recipient.id != -1 && amount > 0) {
                $('#credit').prop('disabled', true);

                message = 'Are you sure you want to credit <b>' + amount + '</b> MeritCommonscoins to <b>' + recipient.text + '</b>? This action cannot be reversed.';
                
                var self = this;
                this.dialog = BootstrapDialog.show({
                    title: 'Are You Sure?',
                    message: '<p>' + message + '</p>',
                    cssClass: 'credit-dialog',
                    buttons: [
                        {
                            id: 'cancel',
                            label: 'Cancel',
                            action: function(dialog) {
                                $('#credit').prop('disabled', false);
                                dialog.close();
                            }
                        },
                        {
                            id: 'understand',
                            label: 'I\'m Sure',
                            action: function(dialog) {
                                $('#credit').prop('disabled', false);
                                $('#cancel').prop('disabled', true);
                                $('#understand').prop('disabled', true);
                                self.credit(amount, recipient.id);
                                $('#amount').val('');
                                $('select[name=recipient]').select2('val', '');
                                $('#cancel').html('Close').prop('disabled', false);
                                $('#understand').remove();
                                $('#credit').prop('disabled', false);
                            }
                        },
                    ],
                });
            } else {
                if (recipient.id == -1) {
                    message = 'Please provide a recipient.';
                } else if ($('#amount').val() && !(amount > 0)) {
                    message = 'Please specify an amount using only numeric characters.';
                } else if (!(amount > 0)) {
                    message = 'Please provide an amount greater than 0.';
                } else {
                    message = 'Please fill out all of the required fields.';
                }

                this.dialog = BootstrapDialog.show({
                    title: 'Error',
                    message: '<p>' + message + '</p>',
                    cssClass: 'credit-dialog',
                    buttons: [
                        {
                            label: 'Okay',
                            action: function(dialog) {
                                dialog.close();
                            }
                        },
                    ],
                });
            }
        },
        respond_single: function(ev) {
            $('.respond').prop('disabled', true);
            var request_id = $(ev.target).parent().parent().attr('id');
            var approve = $(ev.target).data('approve');

            this.dialog = BootstrapDialog.show({
                title: 'Coin Request',
                message: '',
                cssClass: 'credit-dialog',
                buttons: [
                    {
                        id: 'close',
                        label: 'Close',
                        action: function(dialog) {
                            $('.respond').prop('disabled', false);
                            dialog.close();
                        }
                    },
                ],
            });

            this.respond(request_id, approve);
        },
        respond_multiple: function(ev) {
            var approve = $(ev.target).data('approve');

            this.dialog = BootstrapDialog.show({
                title: 'Coin Request',
                message: '',
                cssClass: 'credit-dialog',
                buttons: [
                    {
                        id: 'close',
                        label: 'Close',
                        action: function(dialog) {
                            $('#credit').prop('disabled', false);
                            dialog.close();
                        }
                    },
                ],
            });

            var self = this;
            $('input:checkbox.request').each(function () {
               if (this.checked) {
                    var request_id = $(this).val();
                    self.respond(request_id, approve);
                }
            });

            $('.check-all').prop('checked', false);
        },
        update_check_all: function(ev) {
            var checked = 0;
            $('input:checkbox.request').each(function () {
                if (this.checked) {
                    checked++;
                }
            });

            if (checked) {
                $('.respond-multiple').prop('disabled', false);
            } else {
                $('.respond-multiple').prop('disabled', true);
            }

            $('.check-all').prop('checked', false);
        },
        check_all: function(ev) {
            var checked = ev.target.checked;
            $('input:checkbox.request').each(function () {
                $(this).prop('checked', checked);
            });

            if (checked) {
                $('.respond-multiple').prop('disabled', false);
            } else {
                $('.respond-multiple').prop('disabled', true);
            }
        },
        credit: function(amount, recipient_id) {
            this.dialog.$modalHeader.find('.bootstrap-dialog-title').html('Processing Credit');
            this.dialog.$modalBody.html('<p><i class="fa fa-spinner fa-spin"></i> Processing...</p>');

            var data = {
                amount: amount,
                recipient_id: recipient_id,
            };

            var self = this;
            MeritCommons.WebSocket.conn.send("meritcommonscoin credit " + JSON.stringify(data), {
                times: 1,
                callback: function(e, data) {
                    data = JSON.parse(data.body);
                    if (data.error) {
                        self.dialog.$modalHeader.find('.bootstrap-dialog-title').html('Error');
                        dialog.$modalBody.html('<p style="color: red;">Error: ' + data.error + '</p>');
                    } else {
                        self.dialog.$modalHeader.find('.bootstrap-dialog-title').html('User Credited');
                        self.dialog.$modalBody.html('<p>You have succesfully credited the user.</p>');
                    }
                }
            });
        },
        respond: function(request_id, approve) {
            var data = {
                request_id: request_id,
                approve: approve,
            };

            this.dialog.$modalBody.append('<p id="' + request_id + '"><i class="fa fa-spinner fa-spin"></i> Processing...</p>');

            var self = this;
            MeritCommons.WebSocket.conn.send("meritcommonscoin respond " + JSON.stringify(data), {
                times: 1,
                callback: function(e, data) {
                    data = JSON.parse(data.body);
                    if (data.error) {
                        self.dialog.$modalHeader.find('.bootstrap-dialog-title').append('Error');
                        self.dialog.$modalBody.find('#' + data.request_id).replaceWith('<p style="color: red;">Error: ' + data.error + '</p>');
                    } else {
                        self.dialog.$modalBody.find('#' + data.request_id).replaceWith('<p>' + data.success + '</p>');
                        $('tr#' + data.request_id).fadeOut('slow').remove();
                    }
                }
            });
        },
        key_event: function(ev) {
            if (ev.keyCode == 13) {
                this.credit_event();
            }
        },
    });

    return AdminView;
});