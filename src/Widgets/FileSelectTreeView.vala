/*
* Copyright (c) 2018 David Hewitt (https://github.com/davidmhewitt)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: David Hewitt <davidmhewitt@gmail.com>
*/

public class Torrential.Widgets.FileSelectTreeView : Gtk.TreeView {
    private static Icon FOLDER_ICON;
    private static Icon TORRENT_ICON;

    private enum Columns {
        INDEX,
        ACTIVE,
        NAME,
        ICON,
        N_COLUMNS
    }

    private enum ActiveState {
        NOT_SET,
        MIXED,
        ENABLED,
        DISABLED
    }

    public Torrent torrent { construct; private get; }

    private delegate void PostorderForeachFunc (Gtk.TreeModel model, Gtk.TreeIter iter);

    private Gtk.TreeStore tree_store;

    public FileSelectTreeView (Torrent torrent) {
        Object (torrent: torrent);
    }

    static construct {
        FOLDER_ICON = ContentType.get_icon ("inode/directory");
        TORRENT_ICON = ContentType.get_icon ("application/x-bittorrent");
    }

    construct {
        tree_store = new Gtk.TreeStore (Columns.N_COLUMNS, typeof (int), typeof (int), typeof (string), typeof (Icon));

        model = tree_store;
        vexpand = true;
        headers_visible = false;

        var celltoggle = new Gtk.CellRendererToggle ();
        celltoggle.toggled.connect ((toggle, path) => {
            var tree_path = new Gtk.TreePath.from_string (path);
            Gtk.TreeIter iter;
            tree_store.get_iter (out iter, tree_path);

            Value enabled, node_index;
            tree_store.get_value (iter, Columns.INDEX, out node_index);
            tree_store.get_value (iter, Columns.ACTIVE, out enabled);

            int index = node_index.get_int ();
            if (index >= 0) {
                if (enabled.get_int () == ActiveState.ENABLED) {
                    tree_store.set (iter, Columns.ACTIVE, ActiveState.DISABLED);
                    torrent.files[index].dnd = 1;
                } else {
                    tree_store.set (iter, Columns.ACTIVE, ActiveState.ENABLED);
                    torrent.files[index].dnd = 0;
                }

                update_checked_states ();
            } else {
                if (enabled.get_int () == ActiveState.DISABLED) {
                    recursively_set_active (iter, true);
                } else {
                    recursively_set_active (iter, false);
                }

                update_checked_states ();
            }
        });

        var cell = new Gtk.CellRendererText ();
        var cellpixbuf = new Gtk.CellRendererPixbuf ();
        insert_column_with_data_func (-1, "", celltoggle, render_active_cell);
        insert_column_with_attributes (-1, "", cellpixbuf, "gicon", Columns.ICON);
        insert_column_with_attributes (-1, "", cell, "markup", Columns.NAME);
    }

    private void render_active_cell (Gtk.TreeViewColumn col, Gtk.CellRenderer cell, Gtk.TreeModel model, Gtk.TreeIter iter) {
        Value enabled_state;
        model.get_value (iter, Columns.ACTIVE, out enabled_state);

        var renderer = cell as Gtk.CellRendererToggle;
        switch (enabled_state.get_int ()) {
            case ActiveState.MIXED:
                renderer.inconsistent = true;
                renderer.active = true;
                break;
            case ActiveState.ENABLED:
                renderer.active = true;
                renderer.inconsistent = false;
                break;
            default:
                renderer.active = false;
                renderer.inconsistent = false;
                break;
        }
    }

    private void recursively_set_active (Gtk.TreeIter parent, bool enabled) {
        Gtk.TreeIter child;

        if (tree_store.iter_children (out child, parent)) {
            do {
                Value node_index;
                tree_store.get_value (child, Columns.INDEX, out node_index);
                int index = node_index.get_int ();

                if (index >= 0) {
                    tree_store.set (child, Columns.ACTIVE, enabled ? ActiveState.ENABLED : ActiveState.DISABLED);
                    torrent.files[index].dnd = enabled ? 0 : 1;
                } else {
                    recursively_set_active (child, enabled);
                }

            } while (tree_store.iter_next (ref child));
        }
    }

    public void populate_from_tree_node (Node<Dialogs.FileSelectDialog.FileRow?> node, Gtk.TreeIter? parent = null) {
        Gtk.TreeIter child_iter;

        var row_data = node.data;
        var name = Markup.escape_text (row_data.name);

        Icon icon;

        if (node.parent == null) {
            if (node.children != null) {
                node.children_foreach (TraverseFlags.ALL, (child_node) => {
                    populate_from_tree_node (child_node, null);
                });
            }

            update_checked_states ();
            return;
        } else if (node.children != null) {
            icon = FOLDER_ICON;
        } else {
            var content_type = ContentType.guess (row_data.name, null, null);
            icon = ContentType.get_icon (content_type);
        }

        tree_store.append (out child_iter, parent);
        tree_store.set (child_iter, Columns.INDEX, row_data.index, Columns.ACTIVE, ActiveState.DISABLED, Columns.NAME, name, Columns.ICON, icon);

        if (node.children != null) {
            node.children_foreach (TraverseFlags.ALL, (child_node) => {
                populate_from_tree_node (child_node, child_iter);
            });
        }
    }

    private void update_checked_states () {
        foreach_postorder (model, (model, iter) => {
            Value file_index;
            model.get_value (iter, Columns.INDEX, out file_index);

            int index = file_index.get_int ();
            if (index >= 0) {
                tree_store.@set (iter, Columns.ACTIVE, torrent.files[index].dnd == 0 ? ActiveState.ENABLED : ActiveState.DISABLED);
            } else {
                Gtk.TreeIter child;
                ActiveState enabled = ActiveState.NOT_SET;

                if (model.iter_children (out child, iter)) {
                    do {
                        Value child_enabled;
                        model.get_value (child, Columns.ACTIVE, out child_enabled);

                        if (enabled == ActiveState.NOT_SET) {
                            enabled = (ActiveState) child_enabled.get_int ();
                        } else if (enabled != child_enabled.get_int ()){
                            enabled = ActiveState.MIXED;
                        }

                    } while (model.iter_next (ref child));

                    tree_store.@set (iter, Columns.ACTIVE, enabled);
                }
            }
        });
    }

    private void foreach_postorder_subtree (Gtk.TreeModel model, Gtk.TreeIter parent, PostorderForeachFunc func) {
        Gtk.TreeIter child;

        if (model.iter_children (out child, parent)) {
            do {
                foreach_postorder_subtree (model, child, func);
            } while (model.iter_next (ref child));
        }

        func (model, parent);
    }

    private void foreach_postorder (Gtk.TreeModel model, PostorderForeachFunc func) {
        Gtk.TreeIter iter;

        if (model.iter_nth_child (out iter, null, 0)) {
            do {
                foreach_postorder_subtree (model, iter, func);
            } while (model.iter_next (ref iter));
        }
    }
}
