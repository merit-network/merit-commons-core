define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrap',
    'bootstrap-dialog',
    'odometer'
], function($, _, Backbone, Bootstrap, BootstrapDialog, Odometer) {
    var TransferView = Backbone.View.extend({
        el: $('.coin-transfer'),
        events: {
            'click #transfer': 'transfer_event',
            'keydown': 'key_event',
        },
        dialog: '',
        transfer_event: function(ev) {
            if (/^[0-9,]*$/.exec($('#amount').val())) {
                var amount = parseInt($('#amount').val().replace(/,/g, ''));
            }
            var recipient = $('select[name=recipient]').select2('data')[0];
            var remaining_balance = MeritCommons.coin_balance - amount;

            var message;

            if (recipient.id != -1 && amount > 0 && remaining_balance >= 0) {
                $('#transfer').prop('disabled', true);

                message = 'Are you sure you want to transfer <b>' + amount + '</b> MeritCommonscoins to <b>' + recipient.text + '</b>? This action cannot be reversed. Your remaining balance will be <b>' + remaining_balance + '</b> MeritCommonscoins.';
                
                var self = this;
                this.dialog = BootstrapDialog.show({
                    title: 'Are You Sure?',
                    message: '<p>' + message + '</p>',
                    cssClass: 'transfer-dialog',
                    buttons: [
                        {
                            id: 'cancel',
                            label: 'Cancel',
                            action: function(dialog) {
                                $('#transfer').prop('disabled', false);
                                dialog.close();
                            }
                        },
                        {
                            id: 'understand',
                            label: 'I\'m Sure',
                            action: function(dialog) {
                                $('#transfer').prop('disabled', false);
                                $('#cancel').prop('disabled', true);
                                $('#understand').prop('disabled', true);
                                self.transfer(amount, recipient);
                                $('#amount').val('');
                                $('select[name=recipient]').select2('val', '');
                                $('#cancel').html('Close').prop('disabled', false);
                                $('#understand').remove();
                                $('#transfer').prop('disabled', false);
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
                } else if (remaining_balance < 0) {
                    message = 'You do not have enough MeritCommonscoins to complete this transfer. Please enter a smaller amount.';
                } else {
                    message = 'Please fill out all of the required fields.';
                }

                this.dialog = BootstrapDialog.show({
                    title: 'Error',
                    message: '<p>' + message + '</p>',
                    cssClass: 'transfer-dialog',
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
        transfer: function(amount, recipient) {
            this.dialog.$modalHeader.find('.bootstrap-dialog-title').html('Processing Transfer');
            this.dialog.$modalBody.html('<p><i class="fa fa-spinner fa-spin"></i> Processing your transfer...</p>');

            var data = {
                amount: amount,
                recipient_id: recipient.id,
            };

            var self = this;
            MeritCommons.WebSocket.conn.send("meritcommonscoin transfer " + JSON.stringify(data), {
                times: 1,
                callback: function(e, data) {
                    data = JSON.parse(data.body);
                    if (data.error) {
                        self.dialog.$modalHeader.find('.bootstrap-dialog-title').html('Error');
                        self.dialog.$modalBody.html('<p style="color: red;">Error: ' + data.error + '</p>');
                    } else {
                        self.dialog.$modalHeader.find('.bootstrap-dialog-title').html('Transfer Completed');
                        self.dialog.$modalBody.html('<p>Your transfer is complete.</p>');
                        var date = new Date();
                        $('<tr>' +
                            '<td>' + (date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear() + '</td>' +
                            '<td>' + recipient.text + '</td>' +
                            '<td>' + amount + '</td>' +
                        '</tr>').prependTo('tbody').slideDown('slow');
                        $('#coin-balance').html(MeritCommons.coin_balance - amount);
                    }
                }
            });
        },
        key_event: function(ev) {
            if (ev.keyCode == 13) {
                this.transfer_event();
            }
        },
    });

    return TransferView;
});