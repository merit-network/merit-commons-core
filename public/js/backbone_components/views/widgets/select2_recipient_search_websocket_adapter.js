define([
    'jquery',
    'underscore',
    'websocket',
    'select2/select2/data/array',
    'select2/select2/utils'
], function($, _, WebSocket, ArrayAdapter, Utils) {
    var last_search_time;
    var timer_id;

    var WebSocketData = function($element, options) {
        WebSocketData.__super__.constructor.call(this, $element, options);
    }

    Utils.Extend(WebSocketData, ArrayAdapter);

    WebSocketData.searches = {};
    WebSocketData.matches = {};

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
                    if (WebSocketData.matches) {
                        if (WebSocketData.matches[currentVal[v]]) {
                            label = WebSocketData.matches[currentVal[v]].common_name;
                        }
                    }

                    data.push({
                        id: currentVal[v],
                        text: label
                    });
                }
            } else {
                data = [
                    {
                        id: "",
                        text: WebSocketData.es_config.placeholder
                    }
                ]
            }
        } else {
            var label;
            if (WebSocketData.matches) {
                if (WebSocketData.matches[currentVal]) {
                    label = WebSocketData.matches[currentVal].common_name;
                }
            }

            if (currentVal) {
                data = [ 
                    {
                        id: currentVal,
                        text: label
                    }
                ];
            } else {
                data = [
                    {
                        id: "",
                        text: WebSocketData.es_config.placeholder
                    }
                ];
            }
        }

        callback(data);
    };

    WebSocketData.prototype.query = function(params, callback) {
        var data = {
            results: []
        };

        // install this so we can use it to compare search results to the status of this field
        if (typeof(this.$search) === "undefined") {
            this.$search = this.$element.closest('div').find("input.select2-search__field");
            if (this.$search.length == 0) {
                // last ditch effort.
                this.$search = $("body input.select2-search__field").filter(":visible");
            }
        }

        var search_string = params.term ? params.term : '';
        var search_pfx;

        if (search_string.match(/^(.{3,20})/)) {
            search_pfx = search_string.match(/^(.{3,20})/)[0].toLowerCase();
        } else if (WebSocketData.es_config.fire_when_empty) {
            // augment the in-memory cache search with the value of search_mode as well
            if (WebSocketData.es_config.search_mode) {
                search_pfx = "__empty_" + WebSocketData.es_config.search_mode + "__";
            } else {
                search_pfx = "__empty__";
            }
        }

        // search results in a search_pfx local cache looking for a match or for all matches
        // if match is passed it only returns the record that matches it.
        function search_string_to_entities (search_pfx, match) {
            if (WebSocketData.searches[search_pfx]) {
                var entities = []; 
                _.each(WebSocketData.searches[search_pfx].names, function(v, k, list) {
                    if (k.match(new RegExp(search_string, 'i'))) {
                        _.each(v, function(ele, idx) {
                            // see if we've already added this entity to our entities array (there are multiple 'names' per 'entity')
                            var already_listed = _.find(entities, function(uele, uidx) {
                                if (uele == ele) {
                                    return true;
                                }
                                return false;
                            });

                            if (!already_listed) {
                                if (match) {
                                    if (match.id == ele) {
                                        // this is the one we're looking for
                                        entities.push(WebSocketData.searches[search_pfx].match_pool[ele]);
                                    }
                                } else {
                                    entities.push(WebSocketData.searches[search_pfx].match_pool[ele]);
                                }
                            }
                        });
                    }
                });
                return entities;
            }
        }

        // this function operates on a data structure provided by either
        // the cached results from the websocket or from the websocket itself
        function display_results (search_data) {
            if (MERITCOMMONS_DEBUG) {
                console.log("rendering results for search string '" + search_data.search_string + "'");
            }
            _.each(search_data.search_results, function(result_set) {
                _.each(result_set, function(result) {
                    var match = search_data.match_pool[result];
                    var match_text = match.common_name;

                    var match_item = {
                        id: result,
                        text: match_text
                    };

                    var already_listed = _.find(data.results, function(rslt) {
                        if (rslt.id == match_item.id) {
                            return true;
                        }
                        return false;
                    });

                    if (!already_listed) {
                        // if this still matches the search string, list it
                        if (search_string_to_entities(search_pfx, match_item).length > 0) {
                            data.results.push(match_item);
                        }
                        
                        // keep a record of this (for 'selected' purposes)
                        WebSocketData.matches[result] = search_data.match_pool[result];
                    }
                });
            });

            callback(data);
        }

        if (search_pfx) {
            if (WebSocketData.searches[search_pfx]) {
                if (MERITCOMMONS_DEBUG) {
                    console.log("[recipient_search] using in-memory cached search results for " + search_pfx);
                }
                
                // render locally cached version
                display_results(WebSocketData.searches[search_pfx]);
            } else {
                // setup and perform actual search
                var search_params = {
                    search_string: search_string,
                    search_contexts: WebSocketData.es_config.search_contexts
                };

                var ls_key;
                if (window.localStorage) {
                    ls_key = search_params.search_string;
                    $.each(search_params.search_contexts, function(i, ele) {
                        if (typeof(ele) === "object") {
                            // get the context and add it to the search.
                            var ctx = Object.keys(ele)[0];
                            ls_key += ctx;

                            $.each(ele[ctx], function(k, v) {
                                ls_key += k + ":" + v;
                            });
                        } else if (typeof(ele) === "string") {
                            ls_key += "-" + ele;
                        }
                    });
                }

                // in case a "mode" is specified, as with inbound promo vs. regular mode, append
                // that to the local storage key as well to prevent cached results from being 
                // returned in the different context.
                if (WebSocketData.es_config.search_mode) {
                    ls_key += "-" + WebSocketData.es_config.search_mode;
                }

                if (ls_key) {
                    var cached = window.localStorage.getItem(ls_key);
                    if (cached) {
                        // check if it's expired
                        var exp_time = window.localStorage.getItem(ls_key + 'exp_time');
                        if (Math.floor(Date.now() / 1000) < exp_time) {
                            if (MERITCOMMONS_DEBUG) {
                                console.log("[recipient_search] unexpired localStorage HIT for " + ls_key);
                            }
                            // not expired, just read from cache!
                            WebSocketData.searches[search_pfx] = JSON.parse(cached);
                            display_results(WebSocketData.searches[search_pfx]);
                            return; // this run stops here in this case.
                        } else {
                            if (MERITCOMMONS_DEBUG) {
                                console.log("[recipient_search] found expired localStorage value for " + ls_key + ", running new search");
                            }
                            // clean up after ourselves
                            window.localStorage.removeItem(ls_key);
                            window.localStorage.removeItem(ls_key + 'exp_time');
                        }
                    }
                }

                var do_search = false;
                if (WebSocketData.es_config.fire_when_empty && !search_params.search_string) {
                    // if we're configured to fire_when_empty, search wneh there is no search string
                    do_search = true;
                } else if (search_params.search_string && search_params.search_string.length >= 3) {
                    // if there's a search string and it's 3 characters or longer, do the search.
                    do_search = true;
                }

                if (window.MeritCommons.WebSocket.conn && window.MeritCommons.WebSocket.conn.readyState == 1) {
                    if (do_search) {
                        // RUN SEARCH HERE!

                        if (last_search_time) {
                            if (last_search_time + 500 > Date.now()) {

                                // they typed fast enough....
                                if (timer_id) {
                                    clearTimeout(timer_id);
                                }
                            }
                        }

                        last_search_time = Date.now();

                        var self = this;
                        timer_id = setTimeout(function() {
                            window.MeritCommons.WebSocket.conn.send("recipient_search " + JSON.stringify(search_params), {
                                callback: function(e, data) {
                                    var search_data = JSON.parse(data.body);
                                    WebSocketData.searches[search_pfx] = search_data;

                                    if (ls_key) {
                                        // cache expires in 30 minutes.
                                        window.localStorage.setItem(ls_key + 'exp_time', Math.floor(Date.now() / 1000) + 1800);
                                        window.localStorage.setItem(ls_key, JSON.stringify(search_data));
                                    }

                                    // see if this search result matches what's currently in the box
                                    if (search_data.search_string == self.$search.val()) {
                                        // if so, it's relevant, do the damn thing!
                                        display_results(search_data);
                                    } else {
                                        if (MERITCOMMONS_DEBUG) {
                                            console.log("result search string '" + search_data.search_string + 
                                              "' does not match current value, submitting new search for '" + 
                                              self.$search.val() + "'");
                                        }
                                        self.trigger('query', {
                                            term: self.$search.val()
                                        });
                                    }
                                },
                                times: 1
                            });
                        }, 500);

                        this.trigger('results:message', {
                            message: 'searching'
                        });
                    } else {
                        this.trigger('results:message', {
                            message: 'inputTooShort',
                            args: {
                                minimum: 3,
                                input: search_params.search_string
                            }
                        });
                    }
                } else {
                    this.trigger('results:message', {
                        message: 'searching'
                    });
                }
            }
        } else {
            // assuming this to be the case
            this.trigger('results:message', {
                message: 'inputTooShort',
                args: {
                    minimum: 3,
                    input: search_string
                }
            });
        }
    }

    return WebSocketData;
});