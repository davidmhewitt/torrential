/*
* Copyright (c) 2017 David Hewitt (https://github.com/davidmhewitt)
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

public class Torrential.Widgets.TorrentListBox : Gtk.ListBox {

    public enum FilterType {
        ALL,
        DOWNLOADING,
        SEEDING,
        PAUSED,
        SEARCH
    }

    public TorrentListBox (Gee.ArrayList<Torrent> torrents) {
        set_selection_mode (Gtk.SelectionMode.SINGLE);

        foreach (var torrent in torrents) {
            add (new TorrentListRow (torrent));
        }

        button_press_event.connect (on_button_press);
        popup_menu.connect (on_popup_menu);
    }

    public void update () {
        @foreach ((child) => {
            (child as TorrentListRow).update ();
        });
    }

    public void add_torrent (Torrent torrent) {
        add (new TorrentListRow (torrent));
    }

    public bool on_button_press (Gdk.EventButton event) {
        if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == Gdk.BUTTON_SECONDARY) {
            select_row (get_row_at_y ((int)event.y));
            popup_menu ();
            return true;
        }
        return false;
    }

    public bool on_popup_menu () {
        Gdk.Event event = Gtk.get_current_event ();
        var menu = new Gtk.Menu ();
        var remove_item = new Gtk.MenuItem.with_label (_("Remove"));
        remove_item.activate.connect (() => {
            var selected_row = get_selected_row ();
            if (selected_row != null) {
                (selected_row as TorrentListRow).remove_torrent ();
            }
        });
        menu.add (remove_item);

        menu.set_screen (null);
        menu.attach_to_widget (this, null);

        menu.show_all ();
        uint button;
        event.get_button (out button);
        menu.popup (null, null, null, button, event.get_time ());
        return true;
    }

    public void filter (FilterType filter, string? search_term) {
        switch (filter) {
            case FilterType.ALL:
                set_filter_func (null);
                break;
            case FilterType.DOWNLOADING:
                set_filter_func ((item) => {
                    return (item as TorrentListRow).downloading;
                });
                break;
            case FilterType.SEEDING:
                set_filter_func ((item) => {
                    return (item as TorrentListRow).seeding;
                });
                break;
            case FilterType.PAUSED:
                set_filter_func ((item) => {
                    return (item as TorrentListRow).paused;
                });
                break;
            case FilterType.SEARCH:
                set_filter_func ((item) => {
                    return (item as TorrentListRow).name.casefold ().contains (search_term.casefold ());
                });
                break;
            default:
                break;
        }
    }
}
