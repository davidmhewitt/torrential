/*
* Copyright (c) 2017-2021 David Hewitt (https://github.com/davidmhewitt)
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

    private const string ACTION_GROUP_PREFIX = "win.";
    private const string ACTION_REMOVE = "action-remove";
    private const string ACTION_PAUSE = "action-pause";
    private const string ACTION_RESUME = "action-resume";
    private const string ACTION_EDIT_FILES = "action-edit-files";
    private const string ACTION_COPY_MAGNET = "action-copy-magnet";
    private const string ACTION_OPEN = "action-open";

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

        key_release_event.connect ((event) => {
            switch (event.keyval) {
                case Gdk.Key.Delete:
                case Gdk.Key.BackSpace:
                    var items = get_selected_rows ();
                    foreach (var selected_row in items) {
                        ((TorrentListRow)selected_row).remove_torrent ();
                    }

                    break;
                default:
                    break;
            }

            return false;
        });
    }

    construct {
        var action_remove = new SimpleAction (ACTION_REMOVE, null);
        var action_pause = new SimpleAction (ACTION_PAUSE, null);
        var action_resume = new SimpleAction (ACTION_RESUME, null);
        var action_edit_files = new SimpleAction (ACTION_EDIT_FILES, null);
        var action_copy_magnet = new SimpleAction (ACTION_COPY_MAGNET, null);
        var action_open = new SimpleAction (ACTION_OPEN, null);

        var active_window = (Gtk.ApplicationWindow)((Gtk.Application) GLib.Application.get_default ()).active_window;
        active_window.add_action (action_remove);
        active_window.add_action (action_pause);
        active_window.add_action (action_resume);
        active_window.add_action (action_edit_files);
        active_window.add_action (action_copy_magnet);
        active_window.add_action (action_open);

        action_remove.activate.connect (() => {
            foreach (unowned var row in get_selected_rows ()) {
                ((TorrentListRow) row).remove_torrent ();
            }
        });

        action_pause.activate.connect (() => {
            foreach (unowned var row in get_selected_rows ()) {
                ((TorrentListRow) row).pause_torrent ();
            }
        });

        action_resume.activate.connect (() => {
            foreach (unowned var row in get_selected_rows ()) {
                ((TorrentListRow) row).resume_torrent ();
            }
        });

        action_edit_files.activate.connect (() => {
            var row = (TorrentListRow) get_selected_row ();
            if (row != null) {
                row.edit_files ();
            }
        });

        action_open.activate.connect (() => {
            var row = (TorrentListRow) get_selected_row ();
            if (row != null) {
                open_torrent_location (row.id);
            }
        });

        action_copy_magnet.activate.connect (() => {
            var row = (TorrentListRow) get_selected_row ();
            if (row != null) {
                row.copy_magnet_link ();
                link_copied ();
            }
        });
    }

    public void update () {
        @foreach ((child) => {
            ((TorrentListRow)child).update ();
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
        var items = get_selected_rows ();
        var all_paused = true;

        foreach (var selected_row in items) {
            if (!((TorrentListRow)selected_row).paused) {
                all_paused = false;
                break;
            }
        }

        var menu = new Menu ();
        menu.append (_("Remove"), ACTION_GROUP_PREFIX + ACTION_REMOVE);
        if (all_paused) {
            menu.append (_("Resume"), ACTION_GROUP_PREFIX + ACTION_RESUME);
        } else {
            menu.append (_("Pause"), ACTION_GROUP_PREFIX + ACTION_PAUSE);
        }

        if (items.length () < 2) {
            var selected_row = get_selected_row () as TorrentListRow;

            if (selected_row != null && selected_row.multi_file_torrent) {
                menu.append (_("Select Files to Download"), ACTION_GROUP_PREFIX + ACTION_EDIT_FILES);
            }

            menu.append (_("Copy Magnet Link"), ACTION_GROUP_PREFIX + ACTION_COPY_MAGNET);
            menu.append (_("Show in File Browser"), ACTION_GROUP_PREFIX + ACTION_OPEN);
        }

        var gtk_menu = new Gtk.Menu.from_model (menu);
        gtk_menu.attach_to_widget (this, null);
        gtk_menu.popup_at_pointer (Gtk.get_current_event ());

        return true;
    }

    private void on_row_activated (Gtk.ListBoxRow row) {
        var torrent_row = row as TorrentListRow;
        if (torrent_row.has_metadata) {
            open_torrent (((TorrentListRow)row).id);
        }
    }

    public void filter (FilterType filter, string? search_term) {
        switch (filter) {
            case FilterType.ALL:
                set_filter_func (null);
                break;
            case FilterType.DOWNLOADING:
                set_filter_func ((item) => {
                    return ((TorrentListRow)item).downloading;
                });
                break;
            case FilterType.SEEDING:
                set_filter_func ((item) => {
                    return ((TorrentListRow)item).seeding;
                });
                break;
            case FilterType.PAUSED:
                set_filter_func ((item) => {
                    return ((TorrentListRow)item).paused;
                });
                break;
            case FilterType.SEARCH:
                set_filter_func ((item) => {
                    return ((TorrentListRow)item).display_name.casefold ().contains (search_term.casefold ());
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
