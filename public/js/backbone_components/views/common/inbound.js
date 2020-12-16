  define([
    'jquery',
    'underscore',
    'backbone',
    'mustache',
    'websocket',
    'backbone_components/models/common/message',
    'backbone_components/views/common/websocket_file_upload',
    'text!templates/common/error_modal.mustache',
    'backbone_components/views/common/inbound_preprocess',
    'bootstrap-dialog',
    'odometer',
    'backbone_components/views/widgets/select2_recipient_search_websocket_adapter',
    'bootstrap',
    'select2',
    'summernote',
    'summernoteRecipientAutocomplete',
    'summernoteImageUpload',
    'summernoteKeyHandler',
    'html-md',
    'bootstrapSwitch'
], function($, _, Backbone, Mustache, WebSocket, Message, FileUploadHandler, ErrorModalTemplate, IPP, BootstrapDialog, Odometer, RecipientSearchAdapter) {
    var Inbound = Backbone.View.extend({
        el: '.merge-container',
        events: {
            'click .inbound-modal-open': 'showInboundModal',
            'click .inbound-mode-tab': 'modeTabSwitch',
            'click #post-it' : 'postIt',
            'click #public-private' : 'publicPrivateToggle',
            'click #submit-post-placeholder' : 'toggleSubmit',
            'click #submit-post-collapse' : 'toggleSubmit',
            'click #edit-it': 'editIt',
        },
        initialize: function() {
            // The merge container has been hidden up until now to avoid
            // the disruptive shifting of the DOM caused by select2 loading.
            // Now that select2 is loaded, the merge container can be shown.
            $('.merge-container').show();

            $('div.meritcommons-filter-tabs-container > div', this.$el).on("hidden.bs.dropdown", function(e) {
                $('button.dropdown-toggle', this)[0].blur();
            });

            var editMessage = Backbone.Model.extend({});
            MeritCommons.editMessage = new editMessage;
            this.listenTo(MeritCommons.editMessage, 'change', this.editMessage);
        },
        editMessage: function(msg) {
            $('#inbound-modal').data('mode', 'edit');
            this.showInboundModal();
            $('#inbound-modal').data('mode', 'afterEdit');
        },
        initializeSelect2: function(init_options) {
            var $post_to = $('#post-to');
            
            if (typeof(init_options) === "undefined") {
                init_options = {};
            }
            
            if ($post_to.data('select2')) {
                $post_to.val('').trigger('change');
                $post_to.select2('destroy');
                $post_to = $('#post-to');
            }
            
            var opts = {
                width: '100%',
                placeholder: "To (click here for list)",
                disabled: Object.keys(subscriptions).length > 1 ? false : true,
                dropdownParent: $('#inbound-modal'),
                allowClear: true,
                escapeMarkup: function(markup) {
                    var replaceMap = {
                      '\\': '&#92;',
                      '<': '&lt;',
                      '>': '&gt;',
                    };
                    // Do not try to escape the markup if it's not a string
                    if (typeof markup !== 'string') {
                      return markup;
                    }
                    return String(markup).replace(/[<>\\]/g, function (match) {
                        return replaceMap[match];
                    });
                }
            };
            
            if (init_options.searchable == true) {
                var self = this;

                RecipientSearchAdapter.es_config = {
                    fire_when_empty: true,
                    placeholder: "To (click here for list)",
                    multiple: 1
                };
           
                if (init_options.my_authorships_only == true) {
                    RecipientSearchAdapter.es_config.search_contexts = [
                        {
                            "streams": {
                                "include_private": 1,
                                "my_authorships_only": 1
                            }
                        },
                        "subscribed_with_me", 
                        "global"
                    ];
                    
                    RecipientSearchAdapter.es_config.search_mode = "inbound";
                } else if (init_options.promotional == true) {
                    RecipientSearchAdapter.es_config.search_contexts = [
                        {
                            "streams": {
                                "include_private": 1,
                                "minimum_subscribers": 1,
                                "type_when_empty": "role"
                            }
                        },
                        "subscribed_with_me", 
                        "global"
                    ];
                    
                    RecipientSearchAdapter.es_config.search_mode = "inbound_promo";
                }                

                opts["templateSelection"] = function(selection) {
                    if (selection.id !== '') {
                        var match_item = RecipientSearchAdapter.matches[selection.id];
                        if (match_item) {
                            return self.item_template_for(match_item, selection.text, 16);
                        } else {
                            return selection.text;
                        }
                    }
                };
                
                opts["templateResult"] = function(result) {
                    var match_item = RecipientSearchAdapter.matches[result.id];
                    if (match_item) {
                        return self.result_template_for(match_item, result.text);
                    } else {
                        return result.text;
                    }
                };
                
                if (MERITCOMMONS_DEBUG) {
                    console.log("[inbound]: Search Adapter now in search mode " + RecipientSearchAdapter.es_config.search_mode);
                }
                
                // finally install our adapter, all up to date
                opts["dataAdapter"] = RecipientSearchAdapter;
            }
                        
            // actually initialize the select2
            $post_to.select2(opts);
            
            // when someone selects or remove a stream, update the recipient summary
            $post_to.change(function() {
                self.refreshRecipientSummary(); 
            });
        },
        showInboundModal: function(e) {
            // we'll need this later.
            var self = this;
            var $ct = e ? $(e.currentTarget) : $('#inbound-modal');
            
            // the best way to tell if this is a single stream page is to count the number of subs
            var single_stream = Object.keys(subscriptions).length > 1 ? false : true;

            // if we were just in edit mode
            if ($ct.data('mode') == 'afterEdit') {
                this.inboundModeToggle('simple');
            }

            if ($ct.data('mode') != 'edit') {
                $('#inbound-modal').on('show.bs.modal', function() {
                    if ($('#inbound-modal:visible').length == 0) {
                        $('#inbound-area').code('');
                        $('#message-subject').val('');
                        $('#inbound-simple-advanced').bootstrapSwitch('state', false);
                        $('#inbound-promo-toggle').bootstrapSwitch('state', false);
                        self.message_public = true;
                    }
                });
            }

            $('#inbound-modal').on('shown.bs.modal', function() {
                $('#inbound .note-editor > .note-editing-area > .note-editable')[0].focus();

                if ($ct.data('mode') == 'afterEdit') {
                    // This block of code places the cursor at the end of the text.
                    // Yeah I know, contenteditables...
                    var el = $('#inbound .note-editor > .note-editing-area > .note-editable')[0];
                    if (typeof window.getSelection != "undefined" && typeof document.createRange != "undefined") {
                        var range = document.createRange();
                        range.selectNodeContents(el);
                        range.collapse(false);
                        var sel = window.getSelection();
                        sel.removeAllRanges();
                        sel.addRange(range);
                    } else if (typeof document.body.createTextRange != "undefined") {
                        var textRange = document.body.createTextRange();
                        textRange.moveToElementText(el);
                        textRange.collapse(false);
                        textRange.select();
                    }
                }
            });

            $('#inbound-modal').on('hide.bs.modal', function(e) {
                var sn_modal_showing = false;
                if ($('#inbound-modal-content .note-editor .modal:visible').length > 0) {
                    sn_modal_showing = true;
                }

                if ($(e.currentTarget).is('#inbound-modal') && !sn_modal_showing) {


                    var content = $('#inbound-area').code();
                    if (content == "<br>") {
                        content = false;
                    }

                    var selected_streams = $('#post-to').val();

                    if (!self.close_no_warning) {
                        if (content || (selected_streams && !single_stream)) {
                            BootstrapDialog.confirm({
                                title: 'Unsaved Changes',
                                type: BootstrapDialog.TYPE_DANGER,
                                message: "Closing this window will erase all of the content in this form, are you sure you want to close?",
                                closeByBackdrop: false, 
                                callback: function(result) {
                                    if (result) {
                                        self.close_no_warning = true;
                                        if (!single_stream) {
                                            $('#post-to').val('').trigger('change');
                                        }
                                        $('#inbound-modal').modal('hide');
                                        $('#inbound-modal').off('show.bs.modal shown.bs.modal hide.bs.modal');
                                        self.close_no_warning = false;
                                    }
                                }
                            });
                            e.preventDefault();
                        } else {
                            $('#inbound-modal').off('show.bs.modal shown.bs.modal hide.bs.modal');
                        }
                    } else {
                        $('#inbound-modal').off('show.bs.modal shown.bs.modal hide.bs.modal');
                    }
                }                
            });

            if (!self.modal_initialized) {
                self.inboundMode = "normal";

                // initialize summernote
                var toolbar;
                if (window.MOBILE_PLATFORM) {
                    toolbar = [
                        ['style', ['style']],
                        ['style', ['bold', 'italic']],
                        ['para', ['ul', 'ol']],
                        ['insert', ['imageMobile']]
                    ];
                } else {
                    toolbar = [
                        ['style', ['style']],
                        ['style', ['bold', 'italic']],
                        ['para', ['ul', 'ol']],
                        ['insert', ['image', 'link', 'hr']]
                    ];
                }

                self.c_od = new Odometer({ el: $('#recipient-count .odometer')[0], value: 0, theme: 'minimal' });
                self.c_od.render();

                self.b_od = new Odometer({ el: $('#coin-balance .odometer')[0], value: 0, theme: 'minimal' });
                self.b_od.render();

                $('#inbound-area').summernote({
                    styleWithSpan: false,
                    toolbar: toolbar,
                    disableResizeImage: true, 
                    submitPost: function() {
                        if ($('#post-it').attr('disabled') == undefined) {
                            if ($('#inbound-modal').data('mode') == 'afterEdit') {
                                self.editIt();
                            } else { 
                                self.postIt();
                            }
                        }     
                    }
                });

                $('#inbound-area').on('summernote.insertrecipient summernote.removerecipient', function() {
                    self.refreshRecipientSummary();
                });

                self.modal_initialized = true;
            }

            $('.inbound-tabs .inbound-mode-tab', this.$el).removeClass("active");
            $('#inbound-' + $ct.data('mode') + '-tab').addClass("active");
            this.inboundModeToggle($ct.data('mode'));

            // show the modal
            $('#inbound-modal').modal({
                show: true,
                backdrop: 'static'
            });

            e && e.preventDefault();
        },
        refreshRecipientSummary: function() {
            // pull out mentions
            var body = IPP($('#inbound-area').code(), false);
            var mentions = body.match(/(?:^|\W+)\@((\w+\s\w+|\w+)(\=*)(\w*))/g);
            if (mentions) {
                $.each(mentions, function(i) {
                    mentions[i] = mentions[i].replace(/^.*\@/, '@');
                });
            } else {
                mentions = [];
            }

            var streams = $('#post-to').val();

            if (!streams) {
                streams = [];
            }

            var self = this;

            MeritCommons.WebSocket.conn.send("get_recipient_count " + JSON.stringify(
                {
                    mentions: mentions,
                    streams: streams
                }), 
                {
                    callback: function(e, data) {
                        var counts = JSON.parse(data.body);
                        self.c_od.update(counts.recipient_count);

                        if (self.inboundMode == "promo") {
                            self.b_od.update(counts.balance);
                            var remaining = counts.balance - counts.recipient_count;
                            if (remaining >= 0) {
                                var $cs = $('#inbound .cost-summary');
                                $('.inbound-message-price', $cs).html(counts.recipient_count);
                                $('.inbound-message-price-word', $cs).html(counts.recipient_count == 1 ? "coin" : "coins");
                                
                                
                                $('.inbound-sender-balance', $cs).html(remaining);
                                $('.inbound-sender-balance-word', $cs).html(remaining == 1 ? "coin" : "coins");
                            } else {
                                BootstrapDialog.show({
                                    title: 'Unable To Send Promotional Message',
                                    type: BootstrapDialog.TYPE_DANGER,
                                    message: "Sending to these streams would create a coin deficit of " + remaining + 
                                             ", you can request more coins by clicking <a target=\"_blank\" href=\"/coins/request\">here</a>.",
                                    closeByBackdrop: false,
                                    buttons: [{
                                        label: "Ok",
                                        action: function(dialog) {
                                            $('#post-to').val('').trigger('change');
                                            dialog.close();
                                        }
                                    }]
                                });
                            }
                        }
                    },
                    times: 1
                }
            );
        },
        modeTabSwitch: function(e) {
            var $ct = $(e.currentTarget);
            this.inboundModeToggle($ct.data('mode'));
            $('.inbound-tabs .inbound-mode-tab', this.$el).removeClass("active");
            $('#inbound-' + $ct.data('mode') + '-tab').addClass("active");
            e.preventDefault();
        },
        inboundModeToggle: function(mode) {
            var single_stream = Object.keys(subscriptions).length > 1 ? false : true;
            var self = this;

            if (MERITCOMMONS_DEBUG) {
                console.log("[inbound]: toggle to mode " + mode);
            }

            // reset this for all of them.
            $('#read-only-checkbox').attr('checked', false);

            // if we were just in edit mode, let's clean up
            if ($('#inbound-modal').data('mode') == 'afterEdit') {
                $('#inbound-edit-tab').hide();
                $('#inbound-simple-tab').show();
                $('#inbound-advanced-tab').show();
                $('#inbound-promo-tab').show();

                $('#inbound-modal-title').html('Create New Post');
                $('#edit-it').replaceWith('<button id="post-it" class="btn meritcommons-button"><i class="fa fa-paper-plane"></i> Post</button>');
                $('#message-from').val('').attr('disabled', false);

                $('#inbound-selector-container').show();
                $('#inbound-from-selector-container').show();

                $('message-from').val('');
            }

            if (mode == "advanced") {
                $('.advanced-element', this.$el).css('display', 'block');
                $('.promo-element', this.$el).css('display', 'none');
                $('#submit-post-wrapper', this.$el).removeClass('col-md-offset-1').removeClass('col-md-10').addClass('col-md-8');
                $('#inbound-modal .note-editable').css('min-height', '50px');

                if (single_stream) {
                    //
                    // Single stream interface does not use a searchable inbound...
                    //
                    self.initializeSelect2();
                } else {
                    //
                    // Searchable select2 to field, advanced mode
                    //
                    
                    self.initializeSelect2({
                        searchable: true,
                        my_authorships_only: true 
                    });
                }

                this.inboundMode = "normal";

                MeritCommons.WebSocket.conn.send("get_recipient_count " + JSON.stringify({
                    streams: []
                }), {
                    times: 1,
                    callback: function(e, data) {
                        var counts = JSON.parse(data.body);
                        if (counts.balance <= 0) {
                            // no coins, no promo messages.
                            $('#promo-message-toggle-container').css('display', 'none');
                        }
                    }
                });
                
                this.refreshRecipientSummary();
            } else if (mode == "promo") {
                if (single_stream) {
                    //
                    // Single stream mode has no promotional messaging
                    //
                    this.inboundModeToggle("advanced");
                } else {
                    $('.promo-element, .advanced-element', this.$el).css('display', 'block');
                    $('#submit-post-wrapper', this.$el).removeClass('col-md-offset-1').removeClass('col-md-10').addClass('col-md-8');
                    $('#inbound-modal .note-editable').css('min-height', '50px');
                    //
                    // Promotional, searchable select2
                    //
                    self.initializeSelect2({
                        searchable: true,
                        promotional: true 
                    });
                    
                    this.refreshRecipientSummary();
                    this.inboundMode = "promo";
                }
            } else if (mode == "simple") {
                $('.promo-element, .advanced-element', this.$el).css('display', 'none');

                $('#inbound-modal .note-editable').css('min-height', '207px');
                $('#submit-post-wrapper', this.$el).removeClass('col-md-8').addClass('col-md-10').addClass('col-md-offset-1');

                if (single_stream) {
                    //
                    // Single stream interface does not use a searchable inbound...
                    //
                    self.initializeSelect2();
                } else {
                    //
                    // Searchable select2 to field, advanced mode
                    //
                    self.initializeSelect2({
                        searchable: true,
                        my_authorships_only: true 
                    });
                }
                
                this.inboundMode = "normal";
            } else if (mode == "edit") {
                var msg = MeritCommons.editMessage;

                // show/hide tabs
                $('#inbound-edit-tab').show();
                $('#inbound-simple-tab').hide();
                $('#inbound-advanced-tab').hide();
                $('#inbound-promo-tab').hide();

                // change title
                $('#inbound-modal-title').html('Edit Post');

                // set subject
                $('#message-subject').val(msg.get('subject'));

                // set body
                $('#inbound-area').code(msg.get('body'));

                // change button
                $('#post-it').replaceWith('<button id="edit-it" class="btn meritcommons-button"><i class="fa fa-pencil"></i> Save</button>');

                // read only checkbox
                if (msg.get('read_only')) {
                    $('#read-only-checkbox').prop('checked', true);
                }

                // initialize message from selector
                $('#message-from').select2({
                    width: '100%',
                    placeholder: "From (click here for list)",
                    dropdownParent: $('#inbound-modal'),
                    escapeMarkup: function(markup) {
                        var replaceMap = {
                          '\\': '&#92;',
                          '<': '&lt;',
                          '>': '&gt;',
                        };

                        // Do not try to escape the markup if it's not a string
                        if (typeof markup !== 'string') {
                          return markup;
                        }

                        return String(markup).replace(/[<>\\]/g, function (match) {
                            return replaceMap[match];
                        });
                    }
                });

                // set and disable message from selector
                $('#message-from').val(msg.get('submitter_mask'));
                $('#message-from').attr('disabled', true);

                // disable/enable features based on if the message is a thread parent
                if (msg.get('message_id') == msg.get('thread_id')) {
                    $('.advanced-element', this.$el).css('display', 'block');
                    $('.promo-element', this.$el).css('display', 'none');
                    $('#submit-post-wrapper', this.$el).removeClass('col-md-offset-1').removeClass('col-md-10').addClass('col-md-8');
                    $('#inbound-modal .note-editable').css('min-height', '50px');
                } else {
                    $('.promo-element, .advanced-element', this.$el).css('display', 'none');
                    $('#inbound-modal .note-editable').css('min-height', '207px');
                    $('#submit-post-wrapper', this.$el).removeClass('col-md-8').addClass('col-md-10').addClass('col-md-offset-1');
                }

                // get streams so that we can initialize the recipient count correctly
                var streams = [];

                $.each(msg.get('streams'), function(i, v) {
                    streams.push(v.stream_id);
                });

                $('#inbound-selector-container').hide();
                $('#inbound-from-selector-container').hide();
            }
        },
        postIt: function(e) {
            $('#post-it').attr('disabled','disabled');

            var body = IPP($('#inbound-area').code(), true);

            // check and see if this message is actually going to anyone...
            var tokens = body.match(/(?:^|\W+)\@((\w+\s\w+|\w+)(\=*)(\w*))/g);
            if (tokens) {
                $.each(tokens, function(i) {
                    tokens[i] = tokens[i].replace(/^.*\@/, '@');
                });
            } else {
                // at least make it an empty array... i guess people can just create private notes to themselves?
                tokens = [];
            }

            var to_streams = $('#post-to').val();
            var message_from = $('#message-from').val();

            // always an empty array, for the check below.
            if (to_streams == null) {
                to_streams = [];
            }

            if (to_streams.length == 0 && tokens.length == 0) {
                // populate modal info
                $('#info-modal-title').html("Send Message Error");

                $('#info-modal-content').html(Mustache.render(ErrorModalTemplate, {
                    error_title: "Message Has No Recipients",
                    error_message: 
                        "The message you just tried to send has no recipients.  Please specify recipients individually with <span class='label label-primary'>" +
                        "@mention</span> tags in your message, or by using the <span class='label label-primary'>To:</span> field to select recipient streams."
                }));

                // show the modal
                $('#info-modal').modal({
                    show: true,
                    backdrop: true,
                    keyboard: true
                }).on('hidden.bs.modal', function(e) {
                    // turn the form elements back on when the modal is closed..
                    $('#post-it').removeAttr('disabled');
                }).on('shown.bs.modal', function(e) {
                    // focus on the close button so if they hit enter it closes...
                    $('#info-modal button:last').focus();
                });
            } else if (body.length == 0 || body.match(/^[\s\r\n]*$/)) {
                // populate modal info
                $('#info-modal-title').html("Send Message Error");

                $('#info-modal-content').html(Mustache.render(ErrorModalTemplate, {
                    error_title: "Message Has No Body",
                    error_message: "The message you just tried to send has no body.  Messages must be at least 1 character in length."
                }));

                // show the modal
                $('#info-modal').modal({
                    show: true,
                    backdrop: true,
                    keyboard: true
                }).on('hidden.bs.modal', function(e) {
                    // turn the form elements back on when the modal is closed..
                    $('#post-it').removeAttr('disabled');
                }).on('shown.bs.modal', function(e) {
                    // focus on the close button so if they hit enter it closes...
                    $('#info-modal button:last').focus();
                });       
            } else {
                // actually send the message to the server, toggle the form elements back on
                // when we get confirmation that the message was received.
                window.MeritCommons.WebSocket.conn.send("inbound " + JSON.stringify({
                    render_as: "generic",
                    body: body,
                    streams: to_streams,
                    message_from: message_from,
                    read_only: $('#read-only-checkbox:checked').val(),
                    subject: $('#message-subject').val(),
                    public: this.message_public
                }), {
                    callback: function() {
                        $('#inbound-area').code('');
                        $('#post-it').removeAttr('disabled');
                        if (!$('#post-to').is('[readonly]')) {
                            $('#post-to').val('').trigger('change');
                        }
                        $('#read-only-checkbox').attr('checked', false);
                    },
                    times: 1
                });

                // allows the modal to go away after a post
                this.close_no_warning = true;
                $('#inbound-modal').modal('hide');
                this.close_no_warning = false;
            }

            return false;
        },
        editIt: function(ev) {
            $('#edit-it').prop('disabled', true);

            var body = IPP($('#inbound-area').code(), true);

            var data = {
                message_id: MeritCommons.editMessage.get('message_id'),
                render_as: MeritCommons.editMessage.get('render_as'),
                serialized: MeritCommons.editMessage.get('serialized'),
                serialized_payload: MeritCommons.editMessage.get('serialized_payload'),
                subject: $('#message-subject').val(),
                body: body,
                public: MeritCommons.editMessage.get('public'),
                submitter_mask: MeritCommons.editMessage.get('submitter_mask'),
                read_only: parseInt($('#read-only-checkbox:checked').val()),
                in_reply_to: MeritCommons.editMessage.get('in_reply_to'),
            };

            var self = this;
            MeritCommons.WebSocket.conn.send("edit_message " + JSON.stringify(data), {
                callback: function(e, data) {         
                    try {
                        data = JSON.parse(data.body);
                    } catch (e) {
                        console.log(e);
                    }
                    
                    // clean up
                    $('#edit-it').removeAttr('disabled');
                    self.inboundModeToggle('simple');
                },
            });

            // bye modal!
            this.close_no_warning = true;
            $('#inbound-modal').modal('hide');
            this.close_no_warning = false;

            return false;
        },
        toggleSubmit: function (e) {
            var self = this;
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
        },
    });
    return Inbound;
});
