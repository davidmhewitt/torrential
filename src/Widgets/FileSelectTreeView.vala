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
        ACTIVE,
        NAME,
        ICON,
        N_COLUMNS
    }

    private Gtk.TreeStore tree_store;

    static construct {
        FOLDER_ICON = ContentType.get_icon ("inode/directory");
        TORRENT_ICON = ContentType.get_icon ("application/x-bittorrent");
    }

    construct {
        tree_store = new Gtk.TreeStore (Columns.N_COLUMNS, typeof (bool), typeof (string), typeof (Icon));

        model = tree_store;
        vexpand = true;
        headers_visible = false;

        var celltoggle = new Gtk.CellRendererToggle ();
        celltoggle.toggled.connect ((toggle, path) => {
            var tree_path = new Gtk.TreePath.from_string (path);
			Gtk.TreeIter iter;
			tree_store.get_iter (out iter, tree_path);
			tree_store.set (iter, Columns.ACTIVE, !toggle.active);
        });

        var cell = new Gtk.CellRendererText ();
        var cellpixbuf = new Gtk.CellRendererPixbuf ();
        insert_column_with_attributes (-1, "", celltoggle, "active", Columns.ACTIVE);
        insert_column_with_attributes (-1, "", cellpixbuf, "gicon", Columns.ICON);
        insert_column_with_attributes (-1, "", cell, "markup", Columns.NAME);
    }

    public void populate_from_tree_node (Node<Dialogs.FileSelectDialog.FileRow?> node, Gtk.TreeIter? parent = null) {
        Gtk.TreeIter child_iter;

        var row_data = node.data;
        var name = Markup.escape_text (row_data.name);

        Icon icon;

        if (node.parent == null) {
            icon = TORRENT_ICON;
        } else if (node.children != null) {
            icon = FOLDER_ICON;
        } else {
            var content_type = ContentType.guess (row_data.name, null, null);
            icon = ContentType.get_icon (content_type);
        }

        tree_store.append (out child_iter, parent);
        tree_store.set (child_iter, Columns.ACTIVE, false, Columns.NAME, name, Columns.ICON, icon);

        if (node.children != null) {
            node.children_foreach (TraverseFlags.ALL, (child_node) => {
                populate_from_tree_node (child_node, child_iter);
            });
        }
    }
}
