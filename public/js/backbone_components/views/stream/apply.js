define([
    'jquery',
    'underscore',
    'backbone',
    'backbone_components/views/common/hydrant'
], function($, _, Backbone, Hydrant) {
    var StreamApplyView = Backbone.View.extend({
        el: $('#acl-form'),
        events: {
            'click #acl-form-submit': 'requestPermission',
            'click .respond-to-invite': 'respondToInvite',
        },

        initialize: function() {
            window.MeritCommons.WebSocket.on('invite:responded', function(ev, data) {
                this.afterInviteResponseCallback(ev, data);
            }, this);

            window.MeritCommons.WebSocket.on('membership:added', function(ev, data) {
                this.afterRequestPermissionCallback(ev, data, 'membership');
            }, this);

            window.MeritCommons.WebSocket.on('subscription:added', function(ev, data) {
                this.afterRequestPermissionCallback(ev, data, 'subscription');
            }, this);

            window.MeritCommons.WebSocket.on('authorship:added', function(ev, data) {
                this.afterRequestPermissionCallback(ev, data, 'authorship');
            }, this);
        },

        respondToInvite: function(ev) {
            var data = $(ev.target).data();

            $(ev.target).html('<i class="fa fa-spinner fa-spin"></i> Processing...');
            
            window.MeritCommons.WebSocket.conn.send('invite ' + JSON.stringify(data));
        },

        afterInviteResponseCallback: function(ev) {
            location.reload();
        },

        requestPermission: function(data) {
             $('#acl-form-container form').hide();

            if ($('#subscribe-option').is(":checked")) {
                var data = {
                    action: 'add',
                    permission: 'subscription',
                    streamId: $('#stream-id').val(),
                };
                
                window.MeritCommons.WebSocket.conn.send('request_stream_permission ' + JSON.stringify(data));
            }

            if ($('#author-option').is(":checked")) {
                var data = {
                    action: 'add',
                    permission: 'authorship',
                    streamId: $('#stream-id').val(),
                };

                window.MeritCommons.WebSocket.conn.send('request_stream_permission ' + JSON.stringify(data));
            }

            if ($('#membership-option').is(":checked")) {
                 var data = {
                    action: 'add',
                    permission: 'membership',
                    streamId: $('#stream-id').val(),
                };

                window.MeritCommons.WebSocket.conn.send('request_stream_permission ' + JSON.stringify(data));
            }

            event.preventDefault(); 
        },

        afterRequestPermissionCallback: function(ev, data, permission) {
            if (permission == 'subscription') {
                if ($("#requires-subscriber-authorization").val() == 1) {
                    $('#acl-form-panel').removeClass('panel-danger');
                    $('#acl-form-panel').addClass('panel-warning');
                    $('#acl-form-panel-title').text('Pending Moderator Approval');
                    $('#acl-form-container').append("<p><i class='fa fa-check-circle-o fa-lg'></i> Subscriber Access Requested</p>");
                } else {
                    $('#acl-form-panel').removeClass('panel-danger');
                    $('#acl-form-panel').addClass('panel-success');
                    $('#acl-form-panel-title').text('Access Enabled');
                    $('#acl-form-container').append("<p><i class='fa fa-check-circle-o fa-lg'></i> Subscriber Access Enabled, <a href=''>Click Here</a> to view stream.</p>");
                }
            } else if (permission == 'authorship') {
                if ($("#requires-author-authorization").val() == 1) {
                    $('#acl-form-panel').removeClass('panel-danger');
                    $('#acl-form-panel').addClass('panel-warning');
                    $('#acl-form-panel-title').text('Pending Moderator Approval');
                    $('#acl-form-container').append("<p><i class='fa fa-check-circle-o fa-lg'></i> Author Access Requested</p>");
                } else {
                    $('#acl-form-panel').removeClass('panel-danger');
                    $('#acl-form-panel').addClass('panel-success');
                    $('#acl-form-panel-title').text('Access Enabled');
                    $('#acl-form-container').append("<p><i class='fa fa-check-circle-o fa-lg'></i> Author Access Enabled</p>");
                }
            } else if (permission == 'membership') {
                if ($("#requires-author-authorization").val() == 1) {
                    $('#acl-form-panel').removeClass('panel-danger');
                    $('#acl-form-panel').addClass('panel-warning');
                    $('#acl-form-panel-title').text('Pending Moderator Approval');
                    $('#acl-form-container').append("<p><i class='fa fa-check-circle-o fa-lg'></i> Membership Requested</p>");
                } else {
                    $('#acl-form-panel').removeClass('panel-danger');
                    $('#acl-form-panel').addClass('panel-success');
                    $('#acl-form-panel-title').text('Membership Granted');
                    $('#acl-form-container').append("<p><i class='fa fa-check-circle-o fa-lg'></i> Membership Granted</p>");
                }
            }
        }
    });
    // Our module now returns our view
    return StreamApplyView;
});
