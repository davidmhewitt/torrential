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

public class Torrential.Widgets.TorrentListBox : Gtk.Box {
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

    public Gee.ArrayList<Torrent> torrents { get; construct; }

    private const string ACTION_GROUP_PREFIX = "win.";
    private const string ACTION_REMOVE = "action-remove";
    private const string ACTION_PAUSE = "action-pause";
    private const string ACTION_RESUME = "action-resume";
    private const string ACTION_EDIT_FILES = "action-edit-files";
    private const string ACTION_COPY_MAGNET = "action-copy-magnet";
    private const string ACTION_OPEN = "action-open";

    private Gtk.ListBox listbox;

    public TorrentListBox (Gee.ArrayList<Torrent> torrents) {
        Object (torrents: torrents);
    }

    construct {
        var secondary_click_gesture = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };

        var key_controller = new Gtk.EventControllerKey ();

        listbox = new Gtk.ListBox () {
            activate_on_single_click = false,
            hexpand = true,
            vexpand = true,
            selection_mode = Gtk.SelectionMode.MULTIPLE
        };
        listbox.add_css_class (Granite.STYLE_CLASS_RICH_LIST);
        listbox.add_controller (key_controller);
        listbox.add_controller (secondary_click_gesture);
        listbox.row_activated.connect (on_row_activated);
        listbox.set_sort_func (sort);

        append (listbox);

        foreach (var torrent in torrents) {
            add_row (torrent);
        }

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
            foreach (unowned var row in listbox.get_selected_rows ()) {
                ((TorrentListRow) row).remove_torrent ();
            }
        });

        action_pause.activate.connect (() => {
            foreach (unowned var row in listbox.get_selected_rows ()) {
                ((TorrentListRow) row).pause_torrent ();
            }
        });

        action_resume.activate.connect (() => {
            foreach (unowned var row in listbox.get_selected_rows ()) {
                ((TorrentListRow) row).resume_torrent ();
            }
        });

        action_edit_files.activate.connect (() => {
            var row = (TorrentListRow) listbox.get_selected_row ();
            if (row != null) {
                row.edit_files ();
            }
        });

        action_open.activate.connect (() => {
            var row = (TorrentListRow) listbox.get_selected_row ();
            if (row != null) {
                open_torrent_location (row.id);
            }
        });

        action_copy_magnet.activate.connect (() => {
            var row = (TorrentListRow) listbox.get_selected_row ();
            if (row != null) {
                row.copy_magnet_link ();
                link_copied ();
            }
        });

        key_controller.key_released.connect ((keyval, keycode, state) => {
            switch (keyval) {
                case Gdk.Key.Delete:
                case Gdk.Key.BackSpace:
                    action_remove.activate (null);
                    break;
                default:
                    break;
            }
        });

        secondary_click_gesture.released.connect (popup_menu);
    }

    public void update () {
        var child = listbox.get_first_child ();
        while (child != null) {
            ((TorrentListRow) child).update ();

            child = child.get_next_sibling ();
        }

        listbox.invalidate_sort ();
    }

    public void add_torrent (Torrent torrent) {
        add_row (torrent);
    }

    private void add_row (Torrent torrent) {
        var row = new TorrentListRow (torrent);
        row.torrent_removed.connect ((torrent_to_remove) => {
            listbox.remove (row);
            torrent_removed (torrent_to_remove);
        });
        listbox.append (row);
    }

    private void popup_menu (int n_press, double x, double y) {
        var clicked_row = listbox.get_row_at_y ((int) y);
        if (clicked_row == null) {
            return;
        }

        var found = false;
        foreach (unowned var row in listbox.get_selected_rows ()) {
            if (clicked_row == row) {
                found = true;
                break;
            }
        }

        if (!found) {
            listbox.selected_foreach ((box, row) => {
                listbox.unselect_row (row);
            });

            listbox.select_row (clicked_row);
        }

        var items = listbox.get_selected_rows ();
        var all_paused = true;

        foreach (unowned var selected_row in items) {
            if (!((TorrentListRow) selected_row).paused) {
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
            var selected_row = listbox.get_selected_row () as TorrentListRow;

            if (selected_row != null && selected_row.multi_file_torrent) {
                menu.append (_("Select Files to Download"), ACTION_GROUP_PREFIX + ACTION_EDIT_FILES);
            }

            menu.append (_("Copy Magnet Link"), ACTION_GROUP_PREFIX + ACTION_COPY_MAGNET);
            menu.append (_("Show in File Browser"), ACTION_GROUP_PREFIX + ACTION_OPEN);
        }

        var rect = Gdk.Rectangle () {
            x = (int) x,
            y = (int) y
        };

        var popover = new Gtk.PopoverMenu.from_model (menu) {
            halign = Gtk.Align.START,
            has_arrow = false,
            pointing_to = rect,
            position = Gtk.PositionType.BOTTOM
        };
        popover.set_parent (this);
        popover.popup ();
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
                listbox.set_filter_func (null);
                break;
            case FilterType.DOWNLOADING:
                listbox.set_filter_func ((item) => {
                    return ((TorrentListRow)item).downloading;
                });
                break;
            case FilterType.SEEDING:
                listbox.set_filter_func ((item) => {
                    return ((TorrentListRow)item).seeding;
                });
                break;
            case FilterType.PAUSED:
                listbox.set_filter_func ((item) => {
                    return ((TorrentListRow)item).paused;
                });
                break;
            case FilterType.SEARCH:
                listbox.set_filter_func ((item) => {
                    return ((TorrentListRow)item).display_name.casefold ().contains (search_term.casefold ());
                });
                break;
            default:
                break;
        }
    }

    public bool has_visible_children () {
        var child = listbox.get_first_child ();
        while (child != null) {
            if (child.get_child_visible ()) {
                return true;
            }

            child = child.get_next_sibling ();
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
