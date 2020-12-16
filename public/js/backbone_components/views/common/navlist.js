define([
    'jquery',
    'underscore',
    'backbone',
    'mustache',
    'hashchange'
], function($, _, Backbone, Mustache, HashChange) {
    var NavList = Backbone.View.extend({
        initialize: function() {
            this.found_collection = undefined;

            // on click redraw the appropriate menu
            $('a.navlist-link-collection').click(this.load_new_menu);

            var self = this;

            HashChange.on('c:remove', function() { 
                self.load_new_menu({}, "_top"); 
            }, this);

            // added or changed!
            HashChange.on('c:add', function(v) {
                self.load_new_menu({}, v[0]); 
            }, this);

            HashChange.on('c:change', function(v) {
                self.load_new_menu({}, v[0]); 
            }, this);

            // when everything's ready, do this on load up
            $.each(HashChange.parsed_hash, function(k, v) {
                if (k == "c") {
                    HashChange.trigger(k + ":add", window.MeritCommons.HashChange.parsed_hash[k]);
                }
            });

            $('a.superclick').click(function(e) {
                MeritCommons.WebSocket.conn.send(
                    "superclick " + JSON.stringify({ short_loc: $(e.currentTarget).data('shortloc') }), 
                    {
                        callback: function(data) {
                            window.location.reload();
                        },
                        times: 1
                    }
                );
                e.preventDefault();
            });
            $('a.superclick').tooltip();
        },

        // recursive collection finder w/ ancestry finder
        find_collection: function(id, ntree, ancestry) {
            if (ancestry == undefined) {
                ancestry = []; // we have no ancestors yet.
            }

            var self = this;

            // iterate through this level
            $.each(ntree, function(i, v) {
                if (v.collection == 1 && v.id == id) {
                    // this is the immediate parent, it for sure is an ancestor.
                    ancestry.push({
                        ancestor: v,
                        with_siblings: ntree
                    });
                    self.found_collection = { common_name: v.common_name, common_name_abbr: v.common_name_abbr, items: v.children };
                    return false;
                } else {
                    if (v.children) {
                        // this is a potential parent, push it on the stack
                        var ancestry_copy = ancestry;
                        ancestry_copy.push({
                            ancestor: v,
                            with_siblings: ntree
                        });

                        // recurse!
                        var returned = self.find_collection(id, v.children, ancestry_copy);
                        if (returned != undefined) {
                            // damn not being able to return more than one value
                            self.found_collection = returned[0];
                            ancestry = returned[1];
                            if (self.found_collection) {
                                return false;
                            }
                        } else {
                            ancestry.pop();
                        }
                    }
                }
            });

            // clear the variable once we've done our work.
            if (this.found_collection) {
                var copy = this.found_collection;
                this.found_collection = undefined;
                var copy2 = ancestry;
                ancestry = [];
                return [copy, copy2];
            }
        },
        
        load_menu_with_hierarchy: function(event, collection_id) {
            var nav_item_template = $('#mustache-nav-item').html();
            var nav_list_template = $('#mustache-nav-list').html();


        },

        render: function(collection, ancestry, ul_wrap, parent) {
            var self = this;

            var html = '';
            if (ul_wrap) {
                html = "<ul>";
            }

            if (ancestry.length) {
                var level = ancestry.shift();                
                $.each(level.with_siblings, function(i, sibling) {
                    sibling.id_hash = HashChange.augmented_serialize({ c: sibling.id, clobber: 'c' });
                    if (level.ancestor.id == sibling.id) {
                        var copy = $.extend({}, sibling);
                        sibling.expanded = 1;
                        if (parent) {
                            // clicking an expanded thing closes it again
                            sibling.id_hash = parent.id_hash;
                        } else {
                            sibling.id_hash = "#c0";
                        }
                        html += Mustache.render($('#mustache-nav-item').html(), sibling);
                        if (level.ancestor.id == collection.id) {
                            html += "<ul>" + Mustache.render($('#mustache-nav-list').html(), collection) + "</ul>";
                        } else {
                            // we must recurse!
                            html += self.render(collection, ancestry, true, copy);
                        }
                    } else {
                        sibling.expanded = 0;
                        html += Mustache.render($('#mustache-nav-item').html(), sibling);
                    }
                });
            } else {
                html += Mustache.render($('#mustache-nav-list').html(), collection);
            }

            if (ul_wrap) {
                html += "</ul>";
            }
            return html;
        },

        load_new_menu: function(event, collection_id) {
            if (!collection_id) {
                collection_id = $(this).attr('id');
            } else {
                var clicked_collection;
                var clicked_ancestry;
                if (collection_id == "_top" || collection_id == 0) {
                    clicked_collection = { common_name: "WSU Resources", items: nav_tree };
                    clicked_ancestry = [];
                } else {
                    var returned = this.find_collection(collection_id, nav_tree);
                    clicked_collection = returned[0];
                    clicked_ancestry = returned[1];
                }

                $.each(clicked_collection.items, function(i, v) {
                    v['id_hash'] = HashChange.augmented_serialize({ c: v.id, clobber: 'c' });
                });

                $('#nav-main').html(this.render(clicked_collection, clicked_ancestry));
                //$('#nav-main ul:not(:has(ul))').css({display: 'none'}).slideDown();

                var navlist_breadcrumbs = [];
                if (collection_id && collection_id != "_top" && collection_id != 0) {
                    $('#navlist-breadcrumbs').html('<li><a class="navlist-link-collection" id="_top" href="' + HashChange.augmented_serialize({ c: 0, clobber: 'c' }) + '"><i class="fa fa-home"></i>Home</a> ');
                } else {
                    $('#navlist-breadcrumbs').html('<li class="active"><i class="fa fa-home"></i>Home</li> ');
                }
                $.each(clicked_ancestry, function(i, v) {
                    if (i < clicked_ancestry.length - 1) {
                        $('#navlist-breadcrumbs').append(' <span class="divider">/</span> <li><a class="navlist-link-collection" id="' + v.ancestor.id + '"" href="' + HashChange.augmented_serialize({ c: v.ancestor.id, clobber: 'c' }) + '">' + v.ancestor.common_name_abbr + '</a> ');
                    } else {
                        $('#navlist-breadcrumbs').append(' <span class="divider">/</span> <li>' + v.ancestor.common_name);
                    }
                });
                $('a.navlist-link-collection').click(this.load_new_menu);

                $('a.superclick').click(function(e) {
                    MeritCommons.WebSocket.conn.send(
                        "superclick " + JSON.stringify({ short_loc: $(e.currentTarget).data('shortloc') }), 
                        {
                            callback: function(data) {
                                window.location.reload();
                            },
                            times: 1
                        }
                    );
                    e.preventDefault();
                });
                $('a.superclick').tooltip();
            }
        }
    });

  return NavList;
});
