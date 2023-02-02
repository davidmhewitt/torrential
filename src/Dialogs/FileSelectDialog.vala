/*
* Copyright (c) 2018-2021 David Hewitt (https://github.com/davidmhewitt)
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

public class Torrential.Dialogs.FileSelectDialog : Granite.Dialog {
    public Torrent torrent { construct; private get; }

    public FileSelectDialog (Torrent torrent) {
        Object (torrent: torrent);
    }

    public struct FileRow {
        int index;
        string name;
        string path;
        uint64 length;
    }

    construct {
        set_default_size (450, 300);

        var view = new Widgets.FileSelectTreeView (torrent);

        var scrolled = new Gtk.ScrolledWindow (null, null) {
            expand = true,
            margin = 6,
        };
        scrolled.add (view);
        scrolled.get_style_context ().add_class (Gtk.STYLE_CLASS_FRAME);
        scrolled.show_all ();

        get_content_area ().add (scrolled);

        add_button (_("Close"), 0);

        var files = torrent.files;
        if (files != null) {
            Node<FileRow?> root;

            var root_data = FileRow ();
            root_data.name = torrent.name;
            root_data.index = -1;
            root_data.length = 0;

            root = new Node<FileRow?> (root_data);

            for (int i = 0; i < torrent.file_count; i++) {
                unowned Node<FileRow?> parent = root;
                var file = torrent.files [i];
                var path_parts = file.name.split (Path.DIR_SEPARATOR_S);

                for (int j = 0; j < path_parts.length; j++) {
                    bool is_leaf = path_parts[j + 1] == null;
                    var name = path_parts[j];

                    string path;
                    unowned Node<FileRow?>? node;
                    if (j > 0) {
                        path = string.joinv (Path.DIR_SEPARATOR_S, path_parts[0:j+1]);
                    } else {
                        path = path_parts[0];
                    }

                    node = find_child (parent, path);
                    if (node == null) {
                        var new_data = FileRow ();
                        new_data.name = name;
                        if (j == 0) {
                            new_data.path = name;
                        } else {
                            new_data.path = string.joinv (Path.DIR_SEPARATOR_S, path_parts[0:j+1]);
                        }

                        new_data.index = is_leaf ? i : -1;
                        new_data.length = is_leaf ? file.length : 0;

                        var new_node = new Node<FileRow?> (new_data);
                        node = new_node;
                        parent.append ((owned)new_node);
                    }

                    parent = node;
                }
            }

            view.populate_from_tree_node (root);
        }
    }

    private static unowned Node<FileRow?>? find_child (Node<FileRow?> parent, string path) {
        unowned Node<FileRow?>? child = null;

        parent.children_foreach (TraverseFlags.ALL, (node) => {
           if (((Node<FileRow?>)node).data.path == path) {
               child = node;
               return;
           }
        });

        return child;
    }
}


