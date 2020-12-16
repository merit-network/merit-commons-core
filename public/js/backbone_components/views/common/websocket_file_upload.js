define([
    'jquery',
    'underscore',
    'websocket',
    'mustache',
    'text!templates/common/error_modal.mustache'
], function($, _, WebSocket, Mustache, ErrorModalTemplate) {
    return function(files, editor, $editable) {
        // copied from https://developer.mozilla.org/en-US/docs/Web/API/WindowBase64/Base64_encoding_and_decoding
        // TODO: evaluate if browser support for this has been fleshed out enough to get rid of this
        function strToUTF8Arr (sDOMStr) {

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
        }

        // send the files over the websocket, one at a time, due to the limitations of hydrant "state"
        $.each(files, function(i, file) {
            // file is a File object [https://developer.mozilla.org/en-US/docs/Web/API/File]
            var fr = new FileReader();
            fr.onloadend = function() {
                // get ready to ship this message over
                if ((window.MeritCommons.WebSocket.conn) && (window.MeritCommons.WebSocket.conn.readyState == 1)) {
                    var uuid = window.MeritCommons.WebSocket.new_uuid().toUpperCase();
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
                    $('.summernote-spinner').show();
                    $('#post-it').removeClass('btn-default').addClass('disabled btn-warning').html('<i class="fa fa-spinner fa-spin"></i> Busy');
                    
                    // MeritCommons's take on file uploads ;)
                    window.MeritCommons.WebSocket.conn.send(upload_blob, {
                      verbatim: true,
                      request_id: uuid
                    });

                    window.MeritCommons.WebSocket.once('upload_file:' + uuid + ':success', function(e, data) {
                      window.MeritCommons.WebSocket.off('upload_file:' + uuid + ':error'); // get rid of the error handler
                      $('#post-it').removeClass('disabled btn-warning').addClass('btn-default').html('<i class="fa fa-paper-plane"></i> Post');
                      $('.summernote-spinner').hide();
                      editor.insertImage($editable, $.parseJSON(data.body).canonical_url);
                    });
                    window.MeritCommons.WebSocket.once('upload_file:' + uuid + ':error', function(e, data) {
                      window.MeritCommons.WebSocket.off('upload_file:' + uuid + ':success'); // get rid of the success handler

                      // toggle off the busy indicator
                      $('#post-it').removeClass('disabled btn-warning').addClass('btn-default').html('<i class="fa fa-paper-plane"></i> Post');
                      $('.summernote-spinner').hide();
                      
                      var error = $.parseJSON(data.body);
                      var error_title = "Unknown Error";

                      if (error.error_title) {
                        error_title = error.error_title;
                      }

                      // populate modal info
                      $('#info-modal-title').html("Notice");

                      $('#info-modal-content').html(Mustache.render(ErrorModalTemplate, {
                        error_title: error_title,
                        error_message: error.error
                      }));
                                             
                      // show the modal
                      $('#info-modal').modal({
                        show: true,
                        backdrop: 'static',
                        keyboard: true
                      });
                    });
                }
            };
            fr.readAsArrayBuffer(file);
        });
    }
});