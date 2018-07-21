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
    private enum Columns {
        ACTIVE,
        NAME,
        ICON,
        N_COLUMNS
    }

    private Gtk.TreeStore tree_store;

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

    public void add_file (string name) {
        var content_type = ContentType.guess (name, null, null);
        var icon = ContentType.get_icon (content_type);

        add_to_treestore (tree_store, name, icon);
    }

    private void add_to_treestore (Gtk.TreeStore tree_store, string name, Icon icon) {
        Gtk.TreeIter iter;
        tree_store.append (out iter, null);
        tree_store.set (iter, Columns.ACTIVE, false, Columns.NAME, name,
                        Columns.ICON, icon);
    }
}
