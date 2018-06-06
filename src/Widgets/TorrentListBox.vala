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

    public signal void torrent_removed (Torrent torrent);
    public signal void open_torrent (int id);
    public signal void open_torrent_location (int id);
    public signal void link_copied ();

    public enum FilterType {
        ALL,
        DOWNLOADING,
        SEEDING,
        PAUSED,
        SEARCH
    }

    public TorrentListBox (Gee.ArrayList<Torrent> torrents) {
        set_selection_mode (Gtk.SelectionMode.MULTIPLE);
        activate_on_single_click = false;

        foreach (var torrent in torrents) {
            add_row (torrent);
        }

        button_press_event.connect (on_button_press);
        row_activated.connect (on_row_activated);
        popup_menu.connect (on_popup_menu);
        set_sort_func (sort);
    }

    public void update () {
        @foreach ((child) => {
            (child as TorrentListRow).update ();
        });
        invalidate_sort ();
    }

    public void add_torrent (Torrent torrent) {
        add_row (torrent);
    }

    private void add_row (Torrent torrent) {
        var row = new TorrentListRow (torrent);
        row.torrent_removed.connect ((torrent_to_remove) => torrent_removed (torrent_to_remove));
        add (row);
    }

    private bool on_button_press (Gdk.EventButton event) {
        if (event.type == Gdk.EventType.BUTTON_PRESS && event.button == Gdk.BUTTON_SECONDARY) {
            var clicked_row = get_row_at_y ((int)event.y);
            var rows = get_selected_rows ();
            var found = false;
            foreach (var row in rows) {
                if (clicked_row == row) {
                    found = true;
                    break;
                }
            }

            if (!found) {
                selected_foreach ((box, row) => {
                    unselect_row (row);
                });

                select_row (clicked_row);
            }

            popup_menu ();
            return true;
        }
        return false;
    }

    private bool on_popup_menu () {
        Gdk.Event event = Gtk.get_current_event ();
        var menu = new Gtk.Menu ();

        var items = get_selected_rows ();
        var all_paused = true;

        foreach (var selected_row in items) {
            if (!(selected_row as TorrentListRow).paused) {
                all_paused = false;
                break;
            }
        }

        var remove_item = new Gtk.MenuItem.with_label (_("Remove"));
        remove_item.activate.connect (() => {
            foreach (var selected_row in items) {
                (selected_row as TorrentListRow).remove_torrent ();
            }
        });

        var pause_item = new Gtk.MenuItem.with_label (_("Pause"));
        pause_item.activate.connect (() => {
            foreach (var selected_row in items) {
                (selected_row as TorrentListRow).pause_torrent ();
            }
        });

        var unpause_item = new Gtk.MenuItem.with_label (_("Resume"));
        unpause_item.activate.connect (() => {
            foreach (var selected_row in items) {
                (selected_row as TorrentListRow).resume_torrent ();
            }
        });

        var open_item = new Gtk.MenuItem.with_label (_("Show in File Browser"));
        open_item.activate.connect (() => {
            var selected_row = get_selected_row ();
            if (selected_row != null) {
                open_torrent_location ((selected_row as TorrentListRow).id);
            }
        });

        var copy_magnet_item = new Gtk.MenuItem.with_label (_("Copy Magnet Link"));
        copy_magnet_item.activate.connect (() => {
            var selected_row = get_selected_row () as TorrentListRow;
            if (selected_row != null) {
                selected_row.copy_magnet_link ();
                link_copied ();
            }
        });

        menu.add (remove_item);
        if (all_paused) {
            menu.add (unpause_item);
        } else {
            menu.add (pause_item);
        }

        if (items.length () < 2) {
            menu.add (copy_magnet_item);
            menu.add (open_item);
        }

        menu.set_screen (null);
        menu.attach_to_widget (this, null);

        menu.show_all ();
        uint button;
        event.get_button (out button);
        menu.popup (null, null, null, button, event.get_time ());
        return true;
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        var torrent_row = row as TorrentListRow;
        if (torrent_row.has_metadata) {
            open_torrent ((row as TorrentListRow).id);
        }
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
                    return (item as TorrentListRow).display_name.casefold ().contains (search_term.casefold ());
                });
                break;
            default:
                break;
        }
    }

    public bool has_visible_children () {
        foreach (var child in get_children ()) {
            if (child.get_child_visible ()) {
                return true;
            }
        }
        return false;
    }

    private int sort (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var a = row1 as TorrentListRow;
        var b = row2 as TorrentListRow;

        if (a.downloading != b.downloading) {
            return a.downloading ? -1 : 1;
        }

        if (a.date_added != b.date_added) {
            return a.date_added.compare (b.date_added);
        }

        return a.display_name.collate (b.display_name);
    }
}
