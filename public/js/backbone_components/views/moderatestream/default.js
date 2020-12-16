define([
    'jquery',
    'underscore',
    'backbone',
    'websocket',
    'mustache',
    'text!templates/moderatestream/author_row.mustache',
    'text!templates/moderatestream/moderator_row.mustache',
    'text!templates/moderatestream/moderator_row_remove_button.mustache',
    'text!templates/moderatestream/subscription_table.mustache',
    'text!templates/moderatestream/authorship_table.mustache',
    'text!templates/moderatestream/moderatorship_table.mustache',
    'text!templates/moderatestream/invite_table.mustache',
    'text!templates/moderatestream/invite_row.mustache',
    'bootstrapFileinput',
    'bootstrap',
], function(
    $,
    _,
    Backbone,
    WebSocket,
    Mustache,
    AuthorRowTemplate,
    ModeratorRowTemplate,
    ModeratorRowRemoveButtonTemplate,
    SubscriptionTableTemplate,
    AuthorshipTableTemplate,
    ModeratorshipTableTemplate,
    InviteTableTemplate,
    InviteRowTemplate,
    BootstrapFileinput
) {
    var ModerateStreamView = Backbone.View.extend({
        el: $('#content-wrapper'),

        currentPages: {
            subscription: 1,
            authorship: 1,
            moderatorship: 1,
            invite: 1,
        },

        events: {
            // For subs and auts
            'click .stream-moderate-remove': 'removePermission',
            'click .stream-moderate-authorize': 'authorizePermission',
            'click .stream-moderate-add': 'addPermission',
            
            // For invites.
            'click .stream-invite-add': 'addInvite',
            'click .stream-moderate-approve-invite': 'approveInvite',

            // For removing one's own mod
            'click #save-moderator-clobber-ok': 'removePermission',

            // For toggling another user's supermod
            'change .stream-moderate-super-moderator': 'toggleSuperModerator',

            // For toggling your own supermod
            'change .stream-moderate-super-moderator-myself': function(ev) {
                if (!$(ev.target).is(':checked')) {
                    this.$('#save-moderator-toggle-modal').modal();
                }
            },

            // For recovering after canceling a toggle of your own supermod
            'click #save-moderator-toggle-cancel': function(ev) {
                this.$('.stream-moderate-super-moderator-myself').prop('checked', true);
            },

            // For verifying that you want to toggle your own supermod
            'click #save-moderator-toggle-ok': 'toggleSuperModerator',

            // Pagination
            'click .moderation-first-page': function(ev, data) {
                var target = $(ev.currentTarget);
                //this.changePage($(ev.currentTarget), 1);
                this.changePage(target.data('what'), 1);
                target.blur();
            },
            'click .moderation-previous-page': function(ev, data) {
                var target = $(ev.currentTarget);
                // We also block < 1 pagenums in the controller because dbix::class hateses it
                var page = this.currentPages[target.data('what')] - 1;
                if (page >= 1) {
                    this.changePage(target.data('what'), this.currentPages[target.data('what')] - 1);
                }
                target.blur();
            },
            'click .moderation-next-page': function(ev, data) {
                var target = $(ev.currentTarget);
                var page = this.currentPages[target.data('what')] + 1;
                if (page <= target.siblings('.moderation-last-page').data('last-page')) {
                    this.changePage(target.data('what'), page);
                }
                target.blur();
            },
            'click .moderation-last-page': function(ev, data) {
                var target = $(ev.currentTarget);
                this.changePage(target.data('what'), target.data('last-page'));
                target.blur();
            },
        },

        initialize: function() {
            // These callbacks are for fixing up the UI as requested changes come back from the websocket controller
            window.MeritCommons.WebSocket.on('subscriber:removed', function(ev, data) {
                this.afterRemoveCallback(ev, data, 'subscriber-tab', 'subscription');
            }, this);
            window.MeritCommons.WebSocket.on('author:removed', function(ev, data) {
                this.afterRemoveCallback(ev, data, 'author-tab', 'authorship');
            }, this);
            window.MeritCommons.WebSocket.on('moderator:removed', function(ev, data) {
                this.afterRemoveCallback(ev, data, 'moderator-tab', 'moderatorship');
            }, this);

            window.MeritCommons.WebSocket.on('subscriber:authorized', function(ev, data) {
                this.afterAuthCallback(ev, data, 'subscriber-tab');
            }, this);
            window.MeritCommons.WebSocket.on('author:authorized', function(ev, data) {
                this.afterAuthCallback(ev, data, 'author-tab');
            }, this);

            window.MeritCommons.WebSocket.on('author:added', function(ev, data) {
                this.afterAddCallback(ev, data, 'author-tab');
            }, this);
            window.MeritCommons.WebSocket.on('moderator:added', function(ev, data) {
                this.afterAddCallback(ev, data, 'moderator-tab');
            }, this);
            window.MeritCommons.WebSocket.on('moderator:error:added', function(ev, data) {
                // There is already a mod for that user; flash it green
                var duplicateTr = this.$('#moderator-tab tr[user="' + data.body.user_unique_id + '"]');
                duplicateTr.addClass('success');
                _.delay(function(tr) {
                    tr.removeClass('success');
                }, 2000, duplicateTr);
            }, this);

            window.MeritCommons.WebSocket.on('invite:added', function(ev, data) {
                this.afterAddCallback(ev, data, 'invite-tab');
            }, this);
            window.MeritCommons.WebSocket.on('invite:approved', function(ev, data) {
                this.afterApproveCallback(ev, data);
            }, this);

            window.MeritCommons.WebSocket.on('moderator:powerup', function(ev, data) {
            }, this);
            window.MeritCommons.WebSocket.on('moderator:powerdown', function(ev, data) {
                // Reload moderation page if the user downgrades his own supermod to just mod
                if (_.has(data.body, 'redirect_to')) {
                    window.location.replace(data.body.redirect_to);
                }
            }, this);

            window.MeritCommons.WebSocket.on('moderator:lastsupermod', function(ev, data) {
                data.body = JSON.parse(data.body);
                // Make it harder to attempt to remove the last supermod (forbidden on controller end of course)
                var lastSupermodTr = this.$(
                    '#moderator-tab tr[user="' + data.body.user_unique_id + '"]'
                );
                lastSupermodTr.find('input.stream-moderate-super-moderator, input.stream-moderate-super-moderator-myself').prop('disabled', true);
                lastSupermodTr.find('button.stream-moderate-remove, button.stream-moderate-remove-myself').replaceWith(
                    'Can\'t remove the last moderator with &quot;Can manage moderators&quot;!'
                );
            }, this);
            window.MeritCommons.WebSocket.on('moderator:more_than_one_supermod', function(ev, data) {
                data.body = JSON.parse(data.body);
                // Remove any restrictions on removing/downgrading supermods if there are more than one
                this.$('#moderator-tab tr input.stream-moderate-super-moderator, input.stream-moderate-super-moderator-myself').prop('disabled', false);
                var tdsToFix = this.$('#moderator-tab tr td:nth-child(3)');
                _.each(tdsToFix, function(td) {
                    var userUniqueId = $(td).parent('tr').attr('user');
                    $(td).html(Mustache.render(ModeratorRowRemoveButtonTemplate, {
                        my_own_mod: data.body.active_user_id == userUniqueId,
                        meritcommons_user: {
                            unique_id: userUniqueId,
                        },
                        stream: {
                            unique_id: data.body.stream_id,
                        },
                    }));
                }, this);
            }, this);

            window.MeritCommons.WebSocket.on('permission_page:fetched', function(ev, data) {
                data.body = JSON.parse(data.body);
                var typeInfo = {
                    subscribers: {
                        id: 'subscriber',
                        template: SubscriptionTableTemplate,
                        renderArgs: {
                            subs: data.body.permissions,
                        },
                        renderPartials: {
                        },
                        pageLabelEl: '#subscriber-page',
                    },
                    authors: {
                        id: 'author',
                        template: AuthorshipTableTemplate,
                        renderArgs: {
                            auts: data.body.permissions,
                        },
                        renderPartials: {
                            row: AuthorRowTemplate,
                        },
                        pageLabelEl: '#author-page',
                    },
                    moderators: {
                        id: 'moderator',
                        template: ModeratorshipTableTemplate,
                        renderArgs: {
                            mods: data.body.permissions,
                        },
                        renderPartials: {
                            row: ModeratorRowTemplate,
                            remove_button: ModeratorRowRemoveButtonTemplate,
                        },
                        pageLabelEl: '#moderator-page',
                    },
                    invites: {
                        id: 'invite',
                        template: InviteTableTemplate,
                        renderArgs: {
                            invs: data.body.permissions,
                        },
                        renderPartials: {
                            row: InviteRowTemplate,
                        },
                        pageLabelEl: '#invite-page',
                    }
                }
                this.$('#' + typeInfo[data.body.type]['id'] + '-tab table').replaceWith(
                    Mustache.render(
                        typeInfo[data.body.type]['template'],
                        typeInfo[data.body.type]['renderArgs'],
                        typeInfo[data.body.type]['renderPartials']
                    )
                );
                this.$(typeInfo[data.body.type]['pageLabelEl']).text(data.body.page);
            }, this);
        },

        // Start methods for requesting permission changes
        removePermission: function(ev) {
            $(ev.target).parent('td').parent('tr').addClass('danger');
            this.changePermission($(ev.target).data());
        },

        authorizePermission: function(ev) {
            this.changePermission($(ev.target).data());
        },

        addPermission: function(ev) {
            var data = $(ev.target).data();
            var self = this;

            if (data.what === 'moderatorship') {
                $.each($(ev.target).siblings("form").find("[name='add-moderatorship-input']").val(), function(i, ele) {
                    data['user_id'] = ele;
                    data['add_other_moderators'] = $(ev.target).siblings('#add-moderatorship-add-moderators-checkbox').is(':checked');
                    self.changePermission(data);            
                });

                $(ev.target).siblings("form").find("[name='add-moderatorship-input']").val('').trigger('change');
                $(ev.target).siblings('#add-moderatorship-add-moderators-checkbox').prop('checked', false);
            } else if (data.what === 'authorship') {
                data['user_id'] = $(ev.target).siblings('#add-authorship-input').val();
                $(ev.target).siblings('#add-authorship-input').val('');
                this.changePermission(data);
            }

            $(ev.target)[0].blur();
        },

        toggleSuperModerator: function(ev) {
            var data = _.clone($(ev.target).data());
            if (
                !$(ev.target).is(':checked') ||
                _.has(data, 'reload') // it's coming from a self-powerdown modal
            ) {
                data['action'] = 'powerdown';
            }
            this.changePermission(data);
        },

        addInvite: function(ev) {
            var data = $(ev.target).data();
            if (data.what === 'invite') {
                data['invitee'] = $(ev.target).siblings('#add-invite-input').val();
                $(ev.target).siblings('#add-invite-input').val('');
            }

            this.changePermission(data);
        },

        approveInvite: function(ev) {
            var data = $(ev.target).data();

            this.changePermission(data);
        },

        changePermission: function(data) {
            window.MeritCommons.WebSocket.conn.send('change_stream_permission ' + JSON.stringify(data));
        },
        // End methods for requesting permission changes

        // Start methods for fixing UI after permission change request comes back
        afterAddCallback: function(ev, data, tabName) {
            data.body = JSON.parse(data.body);
            var tableBody = this.$('#' + tabName + ' tbody');
            var trs = tableBody.find('tr');
            // Add a new row to the moderator table
            if (tabName === 'moderator-tab') {
                tableBody.append(Mustache.render(ModeratorRowTemplate,
                    {
                        // Impossible to be adding my own
                        my_own_mod: false,
                        meritcommons_user: {
                            unique_id: data.body.user_unique_id,
                            common_name: data.body.user_common_name,
                        },
                        stream: {
                            unique_id: data.body.stream_id,
                        },
                        allow_add_moderator: data.body.allow_add_moderator,
                        // It's never going to be the last supermod
                        last_moderator: false,
                    },
                    {
                        remove_button: ModeratorRowRemoveButtonTemplate,
                    }
                ));
            } else if (tabName === 'author-tab') {
                tableBody.append(Mustache.render(AuthorRowTemplate, {
                    authorized: true,
                    meritcommons_user: {
                        unique_id: data.body.user_unique_id,
                        common_name: data.body.user_common_name,
                    },
                    stream: {
                        unique_id: data.body.stream_id,
                    },
                    // This actually doesn't matter - anything that depends on this also requires that authorized be
                    // false (and it won't be because a mod is adding it and it's authorized immediately
                    requires_author_authorization: false,
                }));
            } else if (tabName === 'invite-tab') {
                tableBody.append(Mustache.render(InviteRowTemplate, {
                    invitee: {
                        unique_id: data.body.invitee_unique_id,
                        common_name: data.body.invitee_common_name,
                    },
                    inviter: {
                        unique_id: data.body.inviter_unique_id,
                        common_name: data.body.inviter_common_name,
                    },
                    stream: {
                        unique_id: data.body.stream_id,
                    },
                    approved: data.body.approved,
                }));
            }
        },

        afterRemoveCallback: function(ev, data, tabName, what) {
            data.body = JSON.parse(data.body);
            if (_.has(data.body, 'redirect_to')) {
                window.location.replace(data.body.redirect_to);
            } else if (_.has(data.body, 'error')) {
                // Assuming the only error that can happen here is last moderator refusal.  Shouldn't happen anymore now
                // that we're catching this earlier, right?
                var tr = this.$('#' + tabName + ' tr[user="' + data.body.user_unique_id + '"]');
                tr.removeClass('danger');
                tr.find('button.stream-moderate-remove').replaceWith(
                    'Can\'t remove the last moderator of a stream!'
                );
            } else {
                this.$('#' + tabName + ' tr[user="' + data.body.user_unique_id + '"]').hide(
                    'slow',
                    $.proxy(function() {
                        $('#' + tabName + ' tr[user="' + data.body.user_unique_id + '"]').remove();
                        this.changePage(what, this.currentPages[what]);
                    }, this)
                );
            }
        },

        afterAuthCallback: function(ev, data, tabName) {
            data.body = JSON.parse(data.body);
            var tableRow = this.$('#' + tabName + ' tr[user="' + data.body.user_unique_id + '"]');
            tableRow.removeClass('warning');
            tableRow.find('button[data-action="authorize"]').remove();
            tableRow.find('button[data-action="remove"]').text('Remove');
        },

        afterApproveCallback: function(ev, data) {
            data.body = JSON.parse(data.body);
            var tableRow = this.$('#invite-tab tr[invitee="' + data.body.invitee + '"]');
            tableRow.find('button[data-action="approve"]').replaceWith('Invite Approved.');
            tableRow.addClass('success');
            _.delay(function(tr) {
                tr.removeClass('success');
            }, 2000, tableRow);
        },
        // End methods for fixing UI after permission change request comes back

        // Start methods for pagination via websocket
        changePage: function(what, page) {
            this.currentPages[what] = page;
            window.MeritCommons.WebSocket.conn.send('get_moderation_page ' + JSON.stringify({
                streamId: this.$el.data('streamId'),
                type: what,
                page: page
            }));
        },
        // End methods for pagination via websocket

    });
    // Our module now returns our view
    return ModerateStreamView;
});
