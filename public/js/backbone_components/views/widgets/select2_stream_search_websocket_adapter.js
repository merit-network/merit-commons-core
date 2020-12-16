define([
    'jquery',
    'underscore',
    'websocket',
    'select2/select2/data/array',
    'select2/select2/utils'
], function($, _, WebSocket, ArrayAdapter, Utils) {

    var WebSocketData = function($element, options) {
        WebSocketData.__super__.constructor.call(this, $element, options);
    }

    Utils.Extend(WebSocketData, ArrayAdapter);

    WebSocketData.searches = {};
    WebSocketData.matches = [];

    WebSocketData.prototype.current = function(callback) {
        var currentVal = this.$element.val();

        var data = [];

        if (this.$element.prop('multiple')) {
            var render_list = false;
            if (Array.isArray(currentVal) && currentVal != "") {
                render_list = true;
            }

            if (render_list) {
                for (var v = 0; v < currentVal.length; v++) {
                    var label;
                    if (WebSocketData.matches.length) {
                        $.each(WebSocketData.matches, function(i, ele) {
                            if (ele.id == currentVal[v]) {
                                data.push(ele);
                                return false;
                            }
                        });
                    }
                }
            } else {
                data = [
                    {
                        id: "-1",
                        text: WebSocketData.es_config.placeholder
                    }
                ]
            }
        }

        callback(data);
    };

    WebSocketData.prototype.query = function(params, callback) {
        var data = {
            results: []
        };

        var search_options = {};
        if (params.term) {
            search_options['search_string'] = params.term;
        } else {
            search_options['type'] = 'role';
        }

        if (search_options.search_string && search_options.search_string.length < 3) {
            this.trigger('results:message', {
                message: 'inputTooShort',
                args: {
                    minimum: 3,
                    input: search_options.search_string
                }
            });
        } else {
            MeritCommons.WebSocket.conn.send("stream_search " + JSON.stringify(search_options), {
                callback: function(e, data) {
                    var to_render = {
                        results: JSON.parse(data.body)
                    };

                    $.each(to_render.results, function(i, ele) {
                        var already_cached = false;
                        $.each(WebSocketData.matches, function(cache_i, cache_ele) {
                            if (ele.id == cache_ele.id) {
                                // we already have this.
                                already_cached = true;
                                return false;
                            }
                        });

                        if (!already_cached) {
                            WebSocketData.matches.push(ele);
                        }
                    });
                    callback(to_render);
                },
                times: 1
            });
        }
    }

    return WebSocketData;
});