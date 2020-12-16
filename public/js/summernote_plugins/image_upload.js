(function (factory) {
  if (typeof define === 'function' && define.amd) {
    define(['jquery'], factory);
  } else {
    factory(window.jQuery);
  }
}(function ($) {
  var tmpl = $.summernote.renderer.getTemplate(),
    range = $.summernote.core.range,
    dom = $.summernote.core.dom,
    list = $.summernote.core.list;

  var editor = $.summernote.eventHandler.getModule('editor');
  
  var KEY = {
      ENTER: 13
  }

  var toggleBtn = function ($btn, isEnable) {
    $btn.toggleClass('disabled', !isEnable);
    $btn.attr('disabled', !isEnable);
  };

  var bindEnterKey = function ($input, $btn) {
    $input.on('keypress', function (event) {
      if (event.keyCode === KEY.ENTER && !$btn.hasClass('disabled')) {
        $btn.click();      
      }
    });
  };
  
  var showImageDialog = function ($editable, $dialog) {
    return $.Deferred(function (deferred) {
      var $imageDialog = $dialog.find('.note-image-dialog');

      var $imageInput = $dialog.find('.note-image-input'),
          $imageUrl = $dialog.find('.note-image-url'),
          $imageBtn = $dialog.find('.note-image-btn');

      $imageDialog.one('shown.bs.modal', function () {
        // Cloning imageInput to clear element.
        $imageInput.replaceWith($imageInput.clone()
          .on('change', function () {
            deferred.resolve(this.files || this.value);
            $imageDialog.modal('hide');
          })
          .val('')
        );

        $imageBtn.click(function (event) {
          event.preventDefault();

          deferred.resolve($imageUrl.val());
          $imageDialog.modal('hide');
        });

        $imageUrl.on('keyup paste', function (event) {
          var url;
          
          if (event.type === 'paste') {
            url = event.originalEvent.clipboardData.getData('text');
          } else {
            url = $imageUrl.val();
          }
          
          toggleBtn($imageBtn, url);
        }).val('').trigger('focus');
        bindEnterKey($imageUrl, $imageBtn);
      }).one('hidden.bs.modal', function () {
        $imageInput.off('change');
        $imageUrl.off('keyup paste keypress');
        $imageBtn.off('click');
        // disable the button when we're done
        toggleBtn($imageBtn);

        if (deferred.state() === 'pending') {
          deferred.reject();
        }
      }).modal('show');
    });
  };

  showImageDialogMobile = function($editable, $dialog) {
    return $.Deferred(function (deferred) {
      var $imageDialog = $dialog.find('.note-image-dialog');
      var $imageInput = $dialog.find('.note-image-input');

      $imageInput.removeAttr('multiple');
      $imageInput.attr('capture', 'camera');

      var clone = $imageInput.clone();

      $imageInput.replaceWith($(clone)
        .on('change', function () {
          deferred.resolve(this.files || this.value);
        })
        .val('')
      );

      $(clone).click();
    });
  };

  var strToUTF8Arr = function (sDOMStr) {
    var aBytes, nChr, nStrLen = sDOMStr.length, nArrLen = 0;

    /* mapping... */

    for (var nMapIdx = 0; nMapIdx < nStrLen; nMapIdx++) {
      nChr = sDOMStr.charCodeAt(nMapIdx);
      nArrLen += nChr < 0x80 ? 1 : nChr < 0x800 ? 2 : nChr < 0x10000 ? 3 : nChr < 0x200000 ? 4 : nChr < 0x4000000 ? 5 : 6;
    }

    aBytes = new Uint8Array(nArrLen);

    /* transcription... */

    for (var nIdx = 0, nChrIdx = 0; nIdx < nArrLen; nChrIdx++) {
      nChr = sDOMStr.charCodeAt(nChrIdx);
      if (nChr < 128) {
        /* one byte */
        aBytes[nIdx++] = nChr;
      } else if (nChr < 0x800) {
        /* two bytes */
        aBytes[nIdx++] = 192 + (nChr >>> 6);
        aBytes[nIdx++] = 128 + (nChr & 63);
      } else if (nChr < 0x10000) {
        /* three bytes */
        aBytes[nIdx++] = 224 + (nChr >>> 12);
        aBytes[nIdx++] = 128 + (nChr >>> 6 & 63);
        aBytes[nIdx++] = 128 + (nChr & 63);
      } else if (nChr < 0x200000) {
        /* four bytes */
        aBytes[nIdx++] = 240 + (nChr >>> 18);
        aBytes[nIdx++] = 128 + (nChr >>> 12 & 63);
        aBytes[nIdx++] = 128 + (nChr >>> 6 & 63);
        aBytes[nIdx++] = 128 + (nChr & 63);
      } else if (nChr < 0x4000000) {
        /* five bytes */
        aBytes[nIdx++] = 248 + (nChr >>> 24);
        aBytes[nIdx++] = 128 + (nChr >>> 18 & 63);
        aBytes[nIdx++] = 128 + (nChr >>> 12 & 63);
        aBytes[nIdx++] = 128 + (nChr >>> 6 & 63);
        aBytes[nIdx++] = 128 + (nChr & 63);
      } else /* if (nChr <= 0x7fffffff) */ {
        /* six bytes */
        aBytes[nIdx++] = 252 + (nChr >>> 30);
        aBytes[nIdx++] = 128 + (nChr >>> 24 & 63);
        aBytes[nIdx++] = 128 + (nChr >>> 18 & 63);
        aBytes[nIdx++] = 128 + (nChr >>> 12 & 63);
        aBytes[nIdx++] = 128 + (nChr >>> 6 & 63);
        aBytes[nIdx++] = 128 + (nChr & 63);
      }
    }

    return aBytes;
  };

  var uploadImages = function(files, editor, $editable) {
    $.each(files, function(i, file) {
      // file is a File object [https://developer.mozilla.org/en-US/docs/Web/API/File]
      var fr = new FileReader();
      fr.onloadend = function() {
        // get ready to ship this message over
        if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
          var uuid = MeritCommons.WebSocket.new_uuid().toUpperCase();
          var json_string = JSON.stringify({
              command: "upload_file",
              type: file.type,
              name: file.name,
              size: file.size,
              request_id: uuid
          });

          // get a UTF-8 encoded Uint8Array of the JSON
          var json_ab = strToUTF8Arr(json_string);

          // get the same thing for the preamble
          var preamble_string = "MERITCOMMONSBINARY" + json_ab.length;
          var preamble_ab = strToUTF8Arr(preamble_string);

          var upload_blob = new Blob([preamble_ab, json_ab, this.result], {type: 'application/octet-binary'});

          // start the spinny thingie
          var $thread = $editable.closest('div.thread');
          if ($thread.attr('id')) {
            $thread.find('.submit-reply-btn.meritcommons-button').removeClass('btn-default').addClass('disabled btn-warning').html('<i class="fa fa-spinner fa-spin"></i> Busy');
          } else {
            $('#post-it').removeClass('btn-default').addClass('disabled btn-warning').html('<i class="fa fa-spinner fa-spin"></i> Busy');
          }

          // MeritCommons's take on file uploads ;)
          window.MeritCommons.WebSocket.conn.send(upload_blob, {
            verbatim: true,
            request_id: uuid
          });

          window.MeritCommons.WebSocket.once('upload_file:' + uuid + ':success', function(e, data) {
            window.MeritCommons.WebSocket.off('upload_file:' + uuid + ':error'); // get rid of the error handler
            if ($thread.attr('id')) {
              $thread.find('.submit-reply-btn.meritcommons-button').removeClass('disabled btn-warning').addClass('btn-default').html('<i class="fa fa-paper-plane"></i> Post Reply');
            } else {
              $('#post-it').removeClass('disabled btn-warning').addClass('btn-default').html('<i class="fa fa-paper-plane"></i> Post');
            }
            editor.insertImage($editable, $.parseJSON(data.body).canonical_url);
          });

          window.MeritCommons.WebSocket.once('upload_file:' + uuid + ':error', function(e, data) {
            window.MeritCommons.WebSocket.off('upload_file:' + uuid + ':success'); // get rid of the success handler

            // toggle off the busy indicator
            if ($thread.attr('id')) {
              $thread.find('.submit-reply-btn.meritcommons-button').removeClass('disabled btn-warning').addClass('btn-default').html('<i class="fa fa-paper-plane"></i> Post Reply');
            } else {
              $('#post-it').removeClass('disabled btn-warning').addClass('btn-default').html('<i class="fa fa-paper-plane"></i> Post');
            }

            var error = $.parseJSON(data.body);

            alert(error.error_title + ": " + error.error);
          });
        }
      };  
    
      fr.readAsArrayBuffer(file);
    });
  }

  $.summernote.addPlugin({
    name: 'imageUpload',

    init: function(layoutInfo) {
      $dropzone = layoutInfo.dropzone();
      $editable = layoutInfo.editable();

      $('.note-image-popover').remove();

      // unbinding summernote's default drop handler & paste handler
      $dropzone.unbind('drop');
      $editable.unbind('paste');

      // setting up our own drop handler
      $dropzone.on('drop', function (event) {
        event.preventDefault();

        var dataTransfer = event.originalEvent.dataTransfer;
        var html = dataTransfer.getData('text/html');
        var text = dataTransfer.getData('text/plain');

        var layoutInfo = dom.makeLayoutInfo(event.currentTarget || event.target);
        var $editable = layoutInfo.editable();

        if (dataTransfer && dataTransfer.files && dataTransfer.files.length) {
          $editable.focus();
          uploadImages(dataTransfer.files, editor, $editable);
        } else if (html) {
          $(html).each(function () {
            $editable.focus();
            editor.insertNode($editable, this);
          });
        } else if (text) {
          $editable.focus();
          editor.insertText($editable, text);
        }
      }).on('dragover', false);

      // setting up our own paste handler
      $editable.on('paste', function (event) {
        var clipboardData = event.originalEvent.clipboardData;
        var layoutInfo = dom.makeLayoutInfo(event.currentTarget || event.target);

        if (!clipboardData || !clipboardData.items || !clipboardData.items.length) {
          var callbacks = $editable.data('callbacks');

          editor.saveNode($editable);
          editor.saveRange($editable);

          $editable.html('');

          setTimeout(function () {
            var $img = $editable.find('img');

            // if img is no in clipboard, insert text or dom
            if (!$img.length || $img[0].src.indexOf('data:') === -1) {
              var html = $editable.html();

              editor.restoreNode($editable);
              editor.restoreRange($editable);

              editor.focus($editable);
              try {
                editor.pasteHTML($editable, html);
              } catch (ex) {
                editor.insertText($editable, html);
              }
              return;
            }

            var datauri = $img[0].src;

            var data = atob(datauri.split(',')[1]);
            var array = new Uint8Array(data.length);
            for (var i = 0; i < data.length; i++) {
              array[i] = data.charCodeAt(i);
            }

            var blob = new Blob([array], { type : 'image/png' });
            blob.name = 'clipboard.png';

            editor.restoreNode($editable);
            editor.restoreRange($editable);
            uploadImages([blob], editor, $editable);

            editor.afterCommand($editable);
          }, 0);

          return;
        }

        var item = list.head(clipboardData.items);
        var isClipboardImage = item.kind === 'file' && item.type.indexOf('image/') !== -1;

        if (isClipboardImage) {
          uploadImages([item.getAsFile()]);
        }

        editor.afterCommand($editable);
      });
    },

    buttons: {
      image: function (lang) {
        return tmpl.iconButton('fa fa-picture-o', {
          event: 'showImgDialog',
          title: lang.image.image,
          hide: true
        });
      },
      imageMobile: function(lang) {
        var button = tmpl.iconButton('fa fa-picture-o', {
          event: 'showImgDialogMobile',
          hide: true
        });

        // gotta add text our way
        $button = $(button).append(' Upload Image');

        return $button[0];
      }
    },

    dialogs: {
       image: function (lang, options) {
        var imageLimitation = '';
        if (options.maximumImageFileSize) {
          var unit = Math.floor(Math.log(options.maximumImageFileSize) / Math.log(1024));
          var readableSize = (options.maximumImageFileSize / Math.pow(1024, unit)).toFixed(2) * 1 +
                             ' ' + ' KMGTP'[unit] + 'B';
          imageLimitation = '<small>' + lang.image.maximumFileSize + ' : ' + readableSize + '</small>';
        }

        var body = '<div class="form-group row-fluid note-group-select-from-files">' +
                     '<label>' + lang.image.selectFromFiles + '</label>' +
                     '<input class="note-image-input" type="file" name="files" accept="image/*" multiple="multiple" />' +
                     imageLimitation +
                   '</div>' +
                   '<div class="form-group row-fluid">' +
                     '<label>' + lang.image.url + '</label>' +
                     '<input class="note-image-url form-control span12" type="text" />' +
                   '</div>';
        var footer = '<a href="#" class="btn btn-primary note-image-btn disabled" disabled>' + lang.image.insert + '</a>';
        return tmpl.dialog('note-image-dialog', lang.image.insert, body, footer);
      },
    },

    events: {
      showImgDialog: function (event, editor, layoutInfo) {
        var $dialog = layoutInfo.dialog(),
            $editable = layoutInfo.editable();

        editor.saveRange($editable);
        showImageDialog($editable, $dialog).then(function (data) {
          editor.restoreRange($editable);

          if (typeof data === 'string') {
            // image url
            window.MeritCommons.WebSocket.conn.send('proxy_href ' + data);
            window.MeritCommons.WebSocket.once('proxy_href:response', function(response) {
              var proxyData = JSON.parse(response.data);
              var proxyUrl = proxyData.body;
              editor.insertImage($editable, proxyUrl);
            });
          } else {
            uploadImages(data, editor, $editable);
          }
        }).fail(function () {
          editor.restoreRange($editable);
        });
      },
      showImgDialogMobile: function (event, editor, layoutInfo) {
        var $dialog = layoutInfo.dialog(),
            $editable = layoutInfo.editable();

        editor.saveRange($editable);
        showImageDialogMobile($editable, $dialog).then(function (data) {
          editor.restoreRange($editable);
          // upload our images
          uploadImages(data, editor, $editable);
        }).fail(function () {
          editor.restoreRange($editable);
        });
      },
    },
  });
}));