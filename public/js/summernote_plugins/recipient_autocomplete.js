(function (factory) {
  if (typeof define === 'function' && define.amd) {
    define(['jquery'], factory);
  } else {
    factory(window.jQuery);
  }
}(function ($) {
  var range = $.summernote.core.range,
      list = $.summernote.core.list,
      dom = $.summernote.core.dom,
      agent = $.summernote.core.agent;

  var editor = $.summernote.eventHandler.getModule('editor');

  var KEY = {
      UP: 38,
      DOWN: 40,
      LEFT: 37,
      RIGHT: 39,
      ENTER: 13,
      TAB: 9,
      BACKSPACE: 8,
      ESC: 27
  }

  var ARROW_KEYS = [37, 38, 39, 40];

  var searches = {},
      matches = {},
      search_pfx = '',
      matched_on = {},
      searching = false;

  var insertRecipient = function ($popover, $editable) {
    var wordRange = $popover.data('wordRange');
    var $activeItem = $popover.find('.active');
    var name = $activeItem.attr('name');
    var id = $activeItem.data('id');

    var $content = $('<span>').addClass('recipient').text('@' + name).attr('data-id', id);

    $popover.removeData('wordRange');

    wordRange.insertNode($content[0]);

    var space = document.createTextNode(dom.NBSP_CHAR);
    dom.insertAfter(space, $content[0]);
    range.createFromNode(space).collapse().select();

    selection = window.getSelection();
    var childNodes = selection.anchorNode.parentNode.childNodes;
    var splitString = searchString.split(' ');

    $.each(childNodes, function(i, node) {
      if (node && node.nodeType == 3 && node.data.search('@' + splitString[0]) != -1) {
        node.splitText(node.data.indexOf('@' + splitString[0]));
        var s = window.getSelection();
        var cNodes = s.anchorNode.parentNode.childNodes;

        $.each(cNodes, function(j, n) {
          if (n && n.nodeType == 3 && n.data.search('@' + splitString[0]) != -1) {
            dom.remove(n, false);
          }
        });
      }
    });

    range.createFromNode(space).collapse().select();

    $popover.hide();
  };

  var scrollToActive = function($popover) {
    var $el = $popover.find('.active');
    $popover.scrollTop(
      $el.offset().top - $popover.offset().top + $popover.scrollTop()
    );
  }

  var moveDown = function ($popover) {
    var index = $popover.find('.active').index();
    makeActive($popover, (index === -1) ? 0 : (index + 1) % $popover.children().length);
    scrollToActive($popover);
  };

  var moveUp = function ($popover) {
    var index = $popover.find('.active').index();
    makeActive($popover, (index === -1) ? 0 : (index - 1) % $popover.children().length);
    scrollToActive($popover);
  };

  var makeActive = function ($popover, idx) {
    idx = idx || 0;

    if (idx < 0) {
      idx = $popover.children().length - 1;
    }

    $popover.children().removeClass('active');
    var $activeItem = $popover.children().eq(idx);
    $activeItem.addClass('active');
  };

  var leaveRecipientContext = function() {
    var rng = range.create();

    $(rng.sc).unwrap();

    var emptyNode = document.createTextNode('');

    rng.insertNode(emptyNode);
    range.createFromNode(emptyNode).collapse().select();
  };

  var removeRecipient = function(wordRange) {
    var rng = range.create();
    var emptyNode = document.createTextNode('');
    var spaceNode = document.createTextNode(dom.NBSP_CHAR);
    var splitText = $(rng.sc.parentNode).text().split(' ');

    if (splitText.length < 2) {
      var selection = window.getSelection();
      dom.insertAfter(spaceNode, selection.anchorNode);
      range.createFromNode(spaceNode).collapse().select();
      $(rng.sc.parentNode).remove();

      // preserving spaces in webkit browsers
      if (!(agent.isFF || agent.isMSIE)) {
        var s = window.getSelection();
        var r = document.createRange();
        $(s.anchorNode).html($(s.anchorNode).html().replace(/&nbsp;/g, ' '));
        selection.anchorNode.appendChild(spaceNode);
        r.setStart(spaceNode, 0);
        r.collapse(true);
        selection.removeAllRanges();
        selection.addRange(r);
      }
    } else {
      var newRecipient = $(rng.sc.parentNode).text(splitText[0]);
      range.createFromNode(newRecipient[0]).collapse().select();
      dom.insertAfter(spaceNode, newRecipient[0]);
      range.createFromNode(spaceNode).collapse().select();
    }
  };

  var search_string_to_users = function (search_pfx, match) {
    if (searches[search_pfx]) {
      var users = []; 
      $.each(searches[search_pfx].names, function(k, v) {
        if (k.match(new RegExp(searchString, 'i'))) {
          if (matched_on[v]) {
            if ($.grep(matched_on[v], function(name) { k == name }) == 0) {
              matched_on[v].push(k);
            }
          } else {
            matched_on[v] = [k];
          }

          if ($.grep(users, function(user) { v == user.unique_id }).length == 0) {
            if (match) {
              if (match.unique_id == v) {
                users.push(searches[search_pfx].match_pool[v]);
              }
            } else {
              users.push(searches[search_pfx].match_pool[v]);
            }
          }
        }
      });
      return users;
    }
  };

  // TODO: rewrite this to be driven by 'names'
  var collate_search = function (search_data, $popover, search_string, callback) {
    var list = [];
    $.each(search_data.search_results, function(idx, result_set) {
      $.each(result_set, function(id, result) {
        var match = search_data.match_pool[result];
        if ($.grep(list, function(listed) { return match.unique_id == listed.unique_id }).length == 0) {
          if (search_string_to_users(search_pfx, match).length > 0) {
            list.push(match);
          }
        }
      });
    });
    
    if (list.length) {
      callback(list, search_string, $popover);
    } else {
      $popover.hide();
    }
  };

  var match_to_rendered_html = function (match, search_string, first) {
    var alias_match;
    var case_match = false;
    if (matched_on[match.unique_id] && matched_on[match.unique_id].length > 0) {
      alias_match = match.names[0];
      
      $.each(match.names, function(idx, alias) {
        if (alias.length >= search_string.length && ((alias.length < alias_match.length) || (alias.length == alias_match.length && !case_match))) {
          var regex = new RegExp(search_string, "g");
          var regex_lower = new RegExp(search_string.toLowerCase(), "g");
          if (regex.test(alias)) {
            alias_match = alias;
            case_match = true;
          } else if (regex_lower.test(alias.toLowerCase())) {
            alias_match = alias;
            case_match = false;
          }
        }
      });
    }

    return  '<li data-event="insertRecipient" style="min-width: 125px; clear: both; padding: 2px !important; border: 0px !important;" class="aRecipient list-group-item' + (first ? ' active' : '') + '" name="' + alias_match + '" data-id="' + match.userid + '">' + 
              '<h6 style="margin: 0px;"> ' +
                '<img style="float: left; margin-right: 2px;" src="' + match.profile_tiny_url  + '" /> ' + match.common_name +
                ' (' + match.userid + ')' +
                '<br />' +
                '<small>' + match.organization + ' &#8226; ' + match.title + '</small>' +
              '</h6>' +
            '</li>';
  };

  var render_results = function (list, search_string, $popover) {
    var search_view = '';
    $.each(list, function(idx, match) {
      search_view += match_to_rendered_html(match, search_string, idx == 0);
    });

    if (list && list.length > 0) {
      $popover.html(search_view);
      $popover.show();
    }
  };

  var insertAfterRecipient = function(content) {
    var selection = window.getSelection();
    var contentNode = document.createTextNode(content); 
                      
    dom.insertAfter(contentNode, selection.anchorNode.parentNode);
    range.createFromNode(contentNode).collapse().select();
  };

  var insertBeforeRecipient = function(content) {
    var selection = window.getSelection();
    var contentNode = document.createTextNode(content); 
      
    selection.anchorNode.parentNode.parentNode.insertBefore(contentNode, selection.anchorNode.parentNode);
    range.createFromNode(contentNode).collapse().select();
  };2

  $.summernote.addPlugin({
    name: 'recipientAutocomplete',

    events: {
      insertRecipient: function (event, editor, layoutInfo) {
        $popover = layoutInfo.popover().children('.note-recipient-popover');
        insertRecipient($popover, layoutInfo.editable());
        layoutInfo.holder().trigger("summernote.insertrecipient");
      }
    },

    init: function(layoutInfo) {
      var $note = layoutInfo.holder();
      var $popover = $('<div class="note-recipient-popover popover bottom in" style="min-width: 140px; cursor: pointer; display: none; position: fixed; overflow: hidden; overflow-y: auto; max-height: 45%;">' +
                          '<div class="arrow"></div>' +
                            '<div class="popover-content">' +
                          '</div>' +
                        '</div>');
      layoutInfo.popover().append($popover);

      // make recipient active on mouse over
      $popover.on('mouseover', 'li', function(e) {
        $popover.children().removeClass('active');
        $(this).addClass('active');
      });

      layoutInfo.editable().on('keypress', function(e) {
        var selection = window.getSelection();
        var isRecipient = $(selection.anchorNode.parentNode).hasClass('recipient') || $(selection.anchorNode).hasClass('recipient');

        // handler for typing on the recipient and it's edges
        if (isRecipient && e.keyCode != KEY.LEFT && e.keyCode != KEY.RIGHT) {
          var character = e.keyCode == 32 ? dom.NBSP_CHAR : String.fromCharCode(e.keyCode);
          // end of recipient
          if (selection.anchorNode.length == selection.anchorOffset) {
            e.preventDefault();
            insertAfterRecipient(character);
          } else if (selection.anchorOffset == 0) { // beginning of recipient
            e.preventDefault();
            insertBeforeRecipient(character);
          } else {
            leaveRecipientContext();
          }
        }
      });
        
      $note.on('summernote.keydown', function (customEvent, nativeEvent) { 
        var selection = window.getSelection();
        var isRecipient = $(selection.anchorNode.parentNode).hasClass('recipient') || $(selection.anchorNode).hasClass('recipient');

        // handling enter on edges
        if (isRecipient && nativeEvent.keyCode == KEY.ENTER) {
          var character = dom.NBSP_CHAR;
          // end of recipient
          if (selection.anchorNode.length == selection.anchorOffset) {
            nativeEvent.preventDefault();
            insertAfterRecipient(character);
          } else if (selection.anchorOffset == 0) { // beginning of recipient
            nativeEvent.preventDefault();
            insertBeforeRecipient(character);
          } else {
            leaveRecipientContext();
          }

          editor.insertParagraph($editable);
        }

        // arrow key handler for the recipient popover
        if ($popover.css('display') === 'block') {
          if (nativeEvent.keyCode === KEY.DOWN) {
            nativeEvent.preventDefault();
            moveDown($popover);
          } else if (nativeEvent.keyCode === KEY.UP) {
            nativeEvent.preventDefault();
            moveUp($popover);
          } else if ((nativeEvent.keyCode === KEY.ENTER || nativeEvent.keyCode === KEY.TAB)) {
            insertRecipient($popover, layoutInfo.editable());
            $note.trigger('summernote.insertrecipient');
            $note.summernote('focus');
          } 
        }

        // need to do this on keydown in not firefox
        if (nativeEvent.keyCode === KEY.BACKSPACE && isRecipient && !agent.isFF) {
          if (selection.anchorNode.length == selection.anchorOffset) {
            nativeEvent.preventDefault();
            var wordRange = $(this).summernote('createRange').getWordRange();
            removeRecipient(wordRange);
            $note.trigger('summernote.removerecipient');
          } else {
            leaveRecipientContext();
          }
        }
      });

      $note.on('summernote.keyup', function (customEvent, nativeEvent) {
        var rng = range.create();
        var selection = window.getSelection();
        var isRecipient = $(selection.anchorNode.parentNode).hasClass('recipient') || $(selection.anchorNode).hasClass('recipient');

        // backspace handler, need to do this on keyup in firefox
        if (nativeEvent.keyCode === KEY.BACKSPACE && isRecipient && agent.isFF) {
          if (selection.anchorNode.length == selection.anchorOffset) {
            nativeEvent.preventDefault();
            var wordRange = $(this).summernote('createRange').getWordRange();
            removeRecipient(wordRange);
            $note.trigger('summernote.removerecipient');
            $popover.hide();
          } else {
            leaveRecipientContext();
          }
        }

        // escape handler
        if (nativeEvent.keyCode === KEY.ESC && isRecipient) {
          leaveRecipientContext();
        } 

        // new recipient magic
        if (!isRecipient && ARROW_KEYS.indexOf(nativeEvent.keyCode) === -1) {
          var wordRange = $(this).summernote('createRange').getWordRange();
          var wordRangeText = wordRange.ec.textContent;
          if (wordRangeText.length > selection.anchorOffset) { // check if our text extends our cursor
            wordRangeText = wordRangeText.substring(0, selection.anchorOffset); // remove everything after the cursor
          }
          var words = wordRangeText.split(' ');
          var currentWordIndex;
          if (wordRange.toString() == '') {
            currentWordIndex = words.length;
          } else {
            currentWordIndex = words.indexOf(wordRange.toString());
          }
          var newSearchString = '';

          for (i = (currentWordIndex - 1 >= 0 ? currentWordIndex - 1 : 0); i < words.length; i++) {
            words[i] = words[i].replace(/\s/g, ''); // clean up spaces from &nbsp;
            if (/^@/.test(words[i])) {
              newSearchString = words[i];
              if (words[i+1]) {
                newSearchString += ' ' + words[i+1];
              }
            }
          }

          var recipientMatchRegex = /^@([a-zA-Z0-9\-\s]*)([^a-zA-Z0-9\-\s]?)/;

          if (newSearchString != '' && recipientMatchRegex.test(newSearchString) && recipientMatchRegex.exec(newSearchString)[2] == "") {
            searchString = recipientMatchRegex.exec(newSearchString)[1];

            if (searchString.length >= 3) {    
              var recipientParams = {
                search_string: searchString,
                search_contexts: [
                  "subscribed_with_me",
                  "im_following",
                  "my_aliases"
                ]
              };

              //  if we're in a thread, add thread to search context
              var thread_id = layoutInfo.editable().closest('.thread').attr('id');
              if (typeof(thread_id) != "undefined") {
                recipientParams.search_contexts.unshift({ "thread": thread_id });
              }

              if (searchString.match(/^(.{3,5})/)) {
                search_pfx = searchString.match(/^(.{3,5})/)[0].toLowerCase() + "." + recipientParams.search_contexts.length;
              }

              MeritCommons.WebSocket.conn.send('recipient_search ' + JSON.stringify(recipientParams));

              $popover.data('wordRange', wordRange);

              // let's get rect before we our websocket gets back to us since it might change if  we keep typing
              var rect = list.last(wordRange.getClientRects());

              MeritCommons.WebSocket.once('recipient_search:results', function(search) {
                var search_data = JSON.parse(JSON.parse(search.data).body);
                searches[search_pfx] = search_data;

                var rectModal;
                if ($('#inbound-modal:visible').length > 0) {
                  rectModal = list.last($('#inbound-modal').children('.modal-dialog').get(0).getClientRects());
                }

                if (typeof rect != 'undefined') {
                  if (typeof rectModal != 'undefined') { 
                    $popover.css({
                      left: rect.left - rectModal.left,
                      top: rect.top  + rect.height - rectModal.top
                    });
                  } else {
                    $popover.css({
                      left: rect.left,
                      top: rect.top  + rect.height
                    });
                  }

                  $(window).on('scroll', function() {
                    $popover.hide();
                  });
                }

                collate_search(search_data, $popover, searchString, render_results);
              });
            } else {
              $popover.hide();
            }
          } else {
            $popover.hide();
          }
        }
      });
    },
  });
}));