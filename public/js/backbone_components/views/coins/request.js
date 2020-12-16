define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrap',
    'bootstrap-dialog',
    'websocket',
], function($, _, Backbone, Bootstrap, BootstrapDialog, WebSocket) {
    var TransferView = Backbone.View.extend({
        el: $('.coin-request'),
        events: {
            'click #request': 'request_event',
            'keydown': 'key_event',
        },
        dialog: '',
        request_event: function(ev) {
            var amount = 0;
            if (/^[0-9,]*$/.exec($('#amount-requested').val())) {
                var amount = parseInt($('#amount-requested').val().replace(/,/g, ''));
            }
            var reason = $('#reason').val();
            var future_balance = MeritCommons.coin_balance + amount;

            var message;

            if (reason && amount > 0 && amount < 2500000) {
                $('#request').prop('disabled', true);
                message = 'Are you sure you want to request <b>' + amount + '</b> MeritCommonscoins? If your request is approved, your new balance will be <b>' + future_balance + '</b> MeritCommonscoins.';

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
                                $('#request').prop('disabled', false);
                                dialog.close();
                            }
                        },
                        {
                            id: 'understand',
                            label: 'I\'m Sure',
                            action: function(dialog) {
                                $('#cancel').prop('disabled', true);
                                $('#understand').prop('disabled', true);
                                self.request(amount, reason);
                                $('#amount-requested').val('');
                                $('#reason').val('');
                                $('#cancel').html('Close').prop('disabled', false);
                                $('#understand').remove();
                                $('#request').prop('disabled', false);
                            }
                        },
                    ],
                });
            } else {
                if ($('#amount-requested').val() && !(amount > 0)) {
                    message = 'Please specify an amount using only numeric characters.';
                } else if (!(amount > 0)) {
                    message = 'Please provide an amount greater than 0.';
                } else if (amount > 2500000) {
                    message = 'The maximum number of coins that may be requested at a time is 2.5 million.';
                } else if (!reason) {
                    message = 'Please provide a reason for your request.';
                } else {
                    message = 'Please fill out all of the required.';
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
        request: function(amount, reason) {
            this.dialog.$modalHeader.find('.bootstrap-dialog-title').html('Processing Request');
            this.dialog.$modalBody.html('<p><i class="fa fa-spinner fa-spin"></i> Processing your request...</p>');

            var data = {
                amount: amount,
                reason: reason,
            };

            var self = this;
            MeritCommons.WebSocket.conn.send("meritcommonscoin request " + JSON.stringify(data), {
                times: 1,
                callback: function(e, data) {
                    data = JSON.parse(data.body);
                    if (data.error) {
                        self.dialog.$modalHeader.find('.bootstrap-dialog-title').html('Error');
                        self.dialog.$modalBody.html('<p style="color: red;">Error: ' + data.error + '</p>');
                    } else {
                        self.dialog.$modalHeader.find('.bootstrap-dialog-title').html('Request Submitted');
                        self.dialog.$modalBody.html('<p>Your request has been submitted.</p>');
                        var date = new Date();
                        $('<tr>' +
                            '<td>' + (date.getMonth() + 1) + '/' + date.getDate() + '/' + date.getFullYear() + '</td>' +
                            '<td>' + amount + '</td>' +
                            '<td>Pending</td>' +
                        '</tr>').prependTo('tbody').slideDown('slow');
                    }
                }
            });
        },
        key_event: function(ev) {
            if (ev.keyCode == 13 && ev.target.nodeName != "TEXTAREA") {
                this.request_event();
            }
        },
    });
    
    return TransferView;
});