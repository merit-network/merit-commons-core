define([
    'jquery',
    'underscore',
    'backbone'
], function($, _, Backbone) {
    // only do this one time.
    if (window.MeritCommons == undefined) {
        window.MeritCommons = {};
    }

    if (window.MeritCommons.HashChange == undefined) {
        window.MeritCommons.HashChange = {};

        // so we can bind dem events
        _.extend(window.MeritCommons.HashChange, Backbone.Events);

        window.MeritCommons.HashChange.parse_hash = function(hash) {
            if (hash == undefined) {
                hash = window.location.hash;
            }
            var hash_components = hash.split(/\//);
            var parsed_hash = {};
            $.each(hash_components, function(i, v) {
                var kv = v.match(/^\#*([a-z]{1,2})([\d\-A-F]+)$/);
                if (kv && kv.length == 3) {
                    if (parsed_hash[kv[1]] == undefined) {
                        parsed_hash[kv[1]] = []; // 3mpty @rray
                    }
                    parsed_hash[kv[1]].push(kv[2]);
                }
            });
            return parsed_hash;
        }

        // get this in here as soon as we can parse dat hash!
        window.MeritCommons.HashChange.parsed_hash = window.MeritCommons.HashChange.parse_hash();

        window.MeritCommons.HashChange.augmented_serialize = function(hobj) {
            var hc = [];
            // we can array-ify clobber, too ;)
            var clobber = hobj.clobber;
            if (!_.isArray(clobber) && clobber != undefined) {
                clobber = [clobber];
            }

            if (hobj != undefined) {
                $.each(hobj, function(k, v) {
                    if (k != "clobber") {
                        if (!_.isArray(v)) {
                            // array-ize this for sanity reasons.
                            v = [v];
                            hobj[k] = v;
                        }
                        
                        $.each(v, function(i, ele) {
                            hc.push(k + ele);
                        });
                    }
                });
                // add everything that wasn't specified by hobj if we're not clobbering!
                $.each(window.MeritCommons.HashChange.parsed_hash, function(k, v) {
                    var clobbering = false;
                    $.each(clobber, function(i, v) {
                        if (v == k) {
                            clobbering = true;
                        }
                    });
                    if (!clobbering) {
                        $.each(v, function(i, ele) {
                            var kele_has = false;
                            $.each(hobj[k], function(i, kele) {
                                if (kele == ele) {
                                    kele_has = true;
                                }
                            });
                            if (kele_has == false) {
                                hc.push(k + ele);
                            }
                        });
                    }
                });
            } else {
                // render what we know!
                $.each(window.MeritCommons.HashChange.parsed_hash, function(k, v) {
                    $.each(v, function(i, ele) {
                        hc.push(k + ele);
                    });
                });
            }

            return "#" + hc.join('\/');
        }

        window.onhashchange = function() {
            // figure out what changed
            var ph = window.MeritCommons.HashChange.parse_hash(window.location.hash);
            var old_ph = window.MeritCommons.HashChange.parsed_hash;
            var changed = [];
            var added = [];
            var removed = [];
            $.each(ph, function(k, v) {
                if (_.has(old_ph, k)) {
                    if (!_.isEqual(v, old_ph[k])) {
                        changed.push(k);
                    }
                } else {
                    added.push(k);
                }
            });
            $.each(old_ph, function(k, v) {
                if (!_.has(ph, k)) {
                    removed.push(k);
                }
            });
            // trigger events accordingly
            $.each(removed, function(i, v) {
                window.MeritCommons.HashChange.trigger(v + ":remove", ph[v]);
            });

            $.each(added, function(i, v) {
                window.MeritCommons.HashChange.trigger(v + ":add", ph[v]);
            });

            $.each(changed, function(i, v) {
                window.MeritCommons.HashChange.trigger(v + ":change", ph[v]);
            });
            window.MeritCommons.HashChange.parsed_hash = ph;
        }

        return window.MeritCommons.HashChange;
    }
});