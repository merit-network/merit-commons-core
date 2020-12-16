  define([
    'jquery',
    'underscore',
    'backbone',
    'bootstrap-dialog',
], function($, _, Backbone, BootstrapDialog) {
    var Sidebar = Backbone.View.extend({
        el: '#sidebar',
        events: {
            'click .sidebar-section-header': 'collapseSidebarSection',
            'click .request-membership': 'requestPermission',
            'click .request-authorship': 'requestPermission',
            'click .request-subscription': 'requestPermission',
            'click .invite-to-stream': 'inviteToStream',
            'click .respond-to-invite': 'respondToInvite',
            'click .invite-dropdown': 'inviteDropdown',
        },
        inviteDropdown: function(e) {
            // Prevent the dropdown from closing when you click things inside of it.
            e.stopPropagation();
        },

        collapseSidebarSection: function(e) {
            var $current_target = $(e.currentTarget);
            console.log($current_target);
            var $sidebar_collapse;
            if ($current_target.is('.sidebar-section-header')) {
                $sidebar_collapse = $current_target.find('.sidebar-collapse');
            } else if ($current_target.is('.sidebar-collapse')) {
                $sidebar_collapse = $current_target;
            }

            if ($sidebar_collapse && $sidebar_collapse.is(':visible')) {
                var $sidebar_section = $sidebar_collapse.parent().parent();

                if ($sidebar_collapse.hasClass('sidebar-toggled')) {
                    $sidebar_section.removeClass('sidebar-opened');
                    $sidebar_collapse.removeClass('sidebar-toggled');
                } else {
                    $sidebar_section.addClass('sidebar-opened');
                    $sidebar_collapse.addClass('sidebar-toggled');
                }
            }
        },

        requestPermission: function(ev) {
            var data = $(ev.target).data();

            window.MeritCommons.WebSocket.conn.send('request_stream_permission ' + JSON.stringify(data), {
                callback: function(e, data) {
                    location.reload();
                }
            });
        },

        inviteToStream: function(ev) {
            var data = {};
            var invitees = $('[name=invitee-search]').val();
            $('[name=invitee-search]').val('').trigger('change');
            
            data.action = 'invite';
            data.invitees = invitees;
            data.streamId = stream;

            var self = this;

            if (Array.isArray(invitees)) {
                window.MeritCommons.WebSocket.conn.send('invite ' + JSON.stringify(data), {
                    times: invitees.length, // how many times should we allow websocket responses to trigger this action?
                    callback: function(e, data) {
                        self.afterInviteCallback(e, data);
                    }
                });

                var message = '';
                $.each(invitees, function(key, uuid) {
                    var invitee_name = $('[name=invitee-search]').children('[value=' + uuid + ']').html();
                    message += '<p class="' + uuid + '"><i class="fa fa-spinner fa-spin"></i> ' + invitee_name + '</p>';
                });

                self.dialog = BootstrapDialog.show({
                    title: 'Inviting Users To Stream...',
                    message: message,
                    cssClass: 'invite-dialog',
                    buttons: [{
                        id: 'error-ok',
                        label: 'Ok',
                        action: function(dialog) {
                            dialog.close();
                        }
                    }]
                });
            }

            $(ev.target).blur();
        },

        respondToInvite: function(ev) {
            var data = $(ev.target).data();
            window.MeritCommons.WebSocket.conn.send("invite " + JSON.stringify(data), {
                callback: function(e, data) {
                    location.reload();        
                }
            });
        },

        afterInviteCallback: function(ev, data) {
            var body = JSON.parse(data.body);

            var $invitee = this.dialog.$modalBody.find('p.' + body.invitee);
            if (data.ws_msgtype == 'invite:error') {
                $invitee.children('i').removeClass('fa-spinner fa-spin').addClass('fa-times');
                $invitee.append(' could not be invited. (' + body.error + ')');
                $invitee.css('color', 'red');
            } else {
                $invitee.children('i').removeClass('fa-spinner fa-spin').addClass('fa-check');
                $invitee.append(' has been invited!');
                $invitee.css('color', 'green');
            }
        }
    });

    return Sidebar;
});