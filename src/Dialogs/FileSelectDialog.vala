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

public class Torrential.Dialogs.FileSelectDialog : Gtk.Dialog {
    public Torrent torrent { construct; private get; }

    public FileSelectDialog (Torrent torrent) {
        Object (torrent: torrent);
    }

    construct {
        deletable = false;

        var view = new Widgets.FileSelectTreeView ();

        var files = torrent.files;
        if (files != null) {
            foreach (var file in files) {
                view.add_file (file.name);
            }
        }

        var scrolled = new Gtk.ScrolledWindow (null, null);
        scrolled.shadow_type = Gtk.ShadowType.IN;
        scrolled.expand = true;
        scrolled.add (view);

        Gtk.Box content = get_content_area () as Gtk.Box;
        content.pack_start (scrolled, true, true, 0);

        get_header_bar ().visible = false;
        add_button (_("Close"), 0);
    }
}


