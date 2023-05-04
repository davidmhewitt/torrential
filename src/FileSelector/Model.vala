/*
* Copyright (c) 2023 David Hewitt (https://github.com/davidmhewitt)
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

public class FileSelector.Model : Object {
    public class TorrentFile : Object {
        public Torrential.Torrent torrent { get; set; }
        public weak Model? model { get; set; }
        public int index { get; set; }
        public uint depth { get; set; }
        public string name { get; set; }
        public string path { get; set; }
        public string icon_name {
            owned get {
                if (index == -1) {
                    return ContentType.get_generic_icon_name ("inode/directory");
                }

                var content_type = ContentType.guess (name, null, null);
                return ContentType.get_generic_icon_name (content_type);
            }
        }

        public bool download {
            get {
                if (index != -1) {
                    return torrent.is_file_wanted (index);
                } else {
                    var children = get_all_descendants ();
                    var all_checked = children.all_match ((a) => a.download);
                    var some_checked = children.any_match((a) => a.download);
                    inconsistent = !all_checked && some_checked;

                    return some_checked;
                }
            }
            set {
                if (index != -1) {
                    torrent.set_file_download (index, value);
                } else {
                    var children = get_all_descendants ();
                    uint32[] indexes = {};
                    children.@foreach((a) => {
                        indexes += a.index;

                        return true;
                    });
                    torrent.set_files_download (indexes, value);
                }

                model.invalidate (this);
            }
        }
        public bool inconsistent { get; set; }

        public Gee.TreeSet<TorrentFile> get_direct_descendants () {
            var result = new Gee.TreeSet<TorrentFile> ((a, b) => {
                if (a.path.hash() == b.path.hash()) {
                    return 0;
                }

                if (a.index == -1 && b.index == -1) {
                    return a.name.casefold() < b.name.casefold() ? -1 : 1;
                }

                if (a.index == -1 || b.index == -1) {
                    return a.index == -1 ? -1 : 1;
                }

                return a.name.casefold() < b.name.casefold() ? -1 : 1;
            });

            for (int i = 0; i < torrent.file_count; i++) {
                unowned var file = torrent.files[i];
                var parts = file.name.split(Path.DIR_SEPARATOR_S);
                int depth = parts.length;

                if (depth == this.depth + 1 && file.name.has_prefix (this.path)) {
                    result.add (new TorrentFile () {
                        torrent = torrent,
                        index = i,
                        name = parts[parts.length - 1],
                        path = file.name,
                        depth = depth,
                        model = model,
                    });
                } else if (depth == this.depth + 2 && file.name.has_prefix (this.path)) {
                    var stripped_path = string.joinv(Path.DIR_SEPARATOR_S, parts[0:parts.length - 1]);
                    result.add (new TorrentFile () {
                        torrent = torrent,
                        index = -1,
                        name = parts[parts.length - 2],
                        path = stripped_path + "/",
                        depth = this.depth + 1,
                        model = model,
                    });
                }
            }

            return result;
        }

        private Gee.TreeSet<TorrentFile> get_all_descendants () {
            var result = new Gee.TreeSet<TorrentFile> ((a, b) => {
                if (a.path.hash() == b.path.hash()) {
                    return 0;
                }

                return -1;
            });

            for (int i = 0; i < torrent.file_count; i++) {
                unowned var file = torrent.files[i];
                var parts = file.name.split(Path.DIR_SEPARATOR_S);
                int depth = parts.length;

                if (depth > this.depth && file.name.has_prefix (this.path)) {
                    result.add (new TorrentFile () { torrent = torrent, index = i, path = file.name, depth = depth });
                }
            }

            return result;
        }
    }

    public Torrential.Torrent torrent { get; construct; }
    public Gtk.TreeListModel tree_model { private get; construct; }
    public Gtk.SelectionModel selection_model { get; construct; }

    public Model(Torrential.Torrent torrent) {
        Object(torrent: torrent);
    }

    construct {
        var root = create_model (null);
        tree_model = new Gtk.TreeListModel(root, false, false, create_model);
        selection_model = new Gtk.SingleSelection (tree_model);
    }

    private ListModel? create_model (Object? item) {
        if (item == null) {
            var root_node = new TorrentFile () { torrent = torrent, index = -1, name = torrent.name, path = "", depth = 0, model = this };
            var result = new ListStore(typeof(TorrentFile));
            result.append(root_node);
            return result;
        }

        var file_item = item as TorrentFile;
        if (file_item == null) {
            return null;
        }

        if (file_item.index == -1) {
            var result = new ListStore(typeof(TorrentFile));
            var children = file_item.get_direct_descendants ();
            result.splice (0, 0, children.to_array ());

            return result;
        }

        return null;
    }

    public void invalidate(Object item) {
        for (int i = 0; i < tree_model.get_n_items (); i++) {
            var row = tree_model.get_row (i);
            if (row.item == item) {
                var parent = row.get_parent ();
                while (parent != null) {
                    var p = parent.item as TorrentFile;
                    p.notify_property ("download");
                    parent = parent.get_parent ();
                }

                if (row.children != null) {
                    for (int j = 0; j < row.children.get_n_items (); j++) {
                        var child = row.children.get_object(j) as TorrentFile;
                        child.notify_property ("download");
                    }
                }

                break;
            }
        }
    }
}