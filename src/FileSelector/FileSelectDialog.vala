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

    construct {
        var model = new FileSelector.Model (torrent);
        var scope = new Gtk.BuilderCScope ();
        scope.add_callback_symbol ("download_changed", (Callback)download_changed);

        var factory = new Gtk.BuilderListItemFactory.from_resource (scope, "/com/github/davidmhewitt/torrential/ui/FileSelectFactory.ui");

        set_default_size (450, 300);

        var view = new Gtk.ListView (model.selection_model, factory);

        var scrolled = new Gtk.ScrolledWindow () {
            child = view,
            hexpand = true,
            vexpand = true,
            margin_end = 10,
            margin_bottom = 9,
            margin_start = 10
        };
        scrolled.add_css_class (Granite.STYLE_CLASS_FRAME);

        get_content_area ().append (scrolled);

        add_button (_("Close"), 0);
    }

    private static void download_changed (Gtk.CheckButton check, ParamSpec pspec, Gtk.ListItem list_item) {
        var expander = (Gtk.TreeExpander)list_item.child;
        var torrent_item = expander.item as FileSelector.Model.TorrentFile;
        torrent_item.download = check.active;
    }
}


