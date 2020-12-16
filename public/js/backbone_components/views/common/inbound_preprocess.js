define([
    'jquery',
    'underscore',
    'html-md'
], function($, _) {
    return function(html, for_submit) {
        var message = $('<div>' + html + '</div>');

        // clear cached search results so they don't taint future states
        window.top_result_search = "";
        window.top_result_id = 0;
        window.top_result_name = "";

        // we definitely shouldn't be searching if this code is running
        window.searching = false; 
        window.websocket_searching = false;
        
        var html = message.html();

        if (for_submit && INBOUND_DEBUG) {
            MeritCommons.WebSocket.conn.send("inbound_debug " + btoa(unescape(encodeURIComponent("pre-process html " + html))));
        }

        // Find and convert recipients.
        $.each(message.find('span.recipient'), function(key, val) {
            var recipient = $(val);
            var id = recipient.attr('data-id');
            var alias = recipient.text();
            var nbsp = new RegExp(String.fromCharCode(160), "g");
            // Replace &nbsp; in multi-part aliases
            alias = alias.replace(nbsp, " ");
            // Remove trailing spaces.
            var splitAlias = alias.split(" ");
            alias = splitAlias[0] + (splitAlias[1] ? " " + splitAlias[1] : "");

            if (typeof(id) === 'undefined') {
                recipient.replaceWith(alias);
            } else {
                recipient.replaceWith(alias + '=' + id);
            }
        });

        html = message.html();

        if (for_submit && INBOUND_DEBUG) {
            MeritCommons.WebSocket.conn.send("inbound_debug " + btoa(unescape(encodeURIComponent("pre-process recipient conversion " + html))));
        }

        // strip out &#200b (zero width space)
        html = html.replace(/\u200b/g, '');

        // replace nbsp with regular space characters.
        var nbsp = new RegExp(String.fromCharCode(160), "g");
        html.replace(nbsp, " ");

        // convert this html into markdown
        html = md(html);

        if (for_submit && INBOUND_DEBUG) {
            MeritCommons.WebSocket.conn.send("inbound_debug " + btoa(unescape(encodeURIComponent("post-process markdown " + html))));
        }

        // return the markdown version.
        return html;
    }
});