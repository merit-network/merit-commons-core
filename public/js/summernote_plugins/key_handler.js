(function (factory) {
    if (typeof define === 'function' && define.amd) {
        define(['jquery'], factory);
    } else {
        factory(window.jQuery);
    }
}(function ($) {
    
    $.summernote.addPlugin({
        name: 'keyHandler',

        events: {
            enterHandler: function(event, editor, layoutInfo) {
                event.preventDefault();

                var $editor = layoutInfo.editor(),
                $editable = layoutInfo.editable(),
                options = $editor.data('options');

                // handle enter on recipient context
                if (layoutInfo.popover().children('.note-recipient-popover').css('display') != 'block') {
                    if (window.ENTER_TO_POST) {
                        if (event.shiftKey) {
                            var selection = window.getSelection();
                            var isRecipient = $(selection.anchorNode.parentNode).hasClass('recipient') || $(selection.anchorNode).hasClass('recipient');
                            if (!isRecipient) {
                                editor.insertParagraph($editable);
                            }
                        } else {
                            options.submitPost();
                        }
                    } else {
                        var selection = window.getSelection();
                        var isRecipient = $(selection.anchorNode.parentNode).hasClass('recipient') || $(selection.anchorNode).hasClass('recipient');
                        if (!isRecipient) {
                            editor.insertParagraph($editable);
                        }
                    }
                }
            },

            tabHandler: function(event, editor, layoutInfo) {
                event.preventDefault();

                var $editor = layoutInfo.editor(),
                $editable = layoutInfo.editable(),
                options = $editor.data('options');

                // handle tab on recipient context
                if (layoutInfo.popover().children('.note-recipient-popover').css('display') != 'block') {
                    editor.tab($editable, options);
                }
            }
        },
    });

}));