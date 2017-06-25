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

public class Torrential.MainWindow : Gtk.Window {
    public signal void show_about (Gtk.Window parent);

    private bool quitting_for_real = false;

    private uint refresh_timer;

    private PreferencesWindow? prefs_window = null;

    private Gtk.Stack stack;
    private Gtk.HeaderBar headerbar;
    private Gtk.Paned main_pane;
    private Granite.Widgets.Welcome welcome_screen;
    private Widgets.MultiInfoBar infobar;
    private Widgets.TorrentListBox list_box;
    private Unity.LauncherEntry launcher_entry;

    private Granite.Widgets.SourceList sidebar;
    private Granite.Widgets.SourceList.Item all_category;
    private Granite.Widgets.SourceList.Item downloading_category;
    private Granite.Widgets.SourceList.Item seeding_category;
    private Granite.Widgets.SourceList.Item paused_category;
    private Granite.Widgets.SourceList.Item search_category;

    private Gtk.SearchEntry search_entry;

    private SimpleActionGroup actions = new SimpleActionGroup ();
    
    private TorrentManager torrent_manager;
    private Settings saved_state;

    private const string ACTION_GROUP_PREFIX_NAME = "tor";
    private const string ACTION_GROUP_PREFIX = ACTION_GROUP_PREFIX_NAME + ".";

    private const string ACTION_PREFERENCES = "undo";
    private const string ACTION_ABOUT = "redo";
    private const string ACTION_QUIT = "quit";
    private const string ACTION_HIDE = "hide";
    private const string ACTION_OPEN = "open";
    private const string ACTION_OPEN_COMPLETED_TORRENT = "show-torrent";

    private const ActionEntry[] action_entries = {
        {ACTION_PREFERENCES,                on_preferences          },
        {ACTION_ABOUT,                      on_about                },
        {ACTION_QUIT,                       on_quit                 },
        {ACTION_HIDE,                       on_hide                 },
        {ACTION_OPEN,                       on_open                 }
    };

    public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
    static construct {
        action_accelerators.set (ACTION_PREFERENCES, "<Ctrl>comma");
        action_accelerators.set (ACTION_QUIT, "<Ctrl>q");
        action_accelerators.set (ACTION_HIDE, "<Ctrl>w");
        action_accelerators.set (ACTION_OPEN, "<Ctrl>o");
    }

    public MainWindow (Application app) {
        saved_state = Settings.get_default ();
        set_default_size (saved_state.window_width, saved_state.window_height);

        // Maximize window if necessary
        switch (saved_state.window_state) {
            case Settings.WindowState.MAXIMIZED:
                this.maximize ();
                break;
            default:
                break;
        }

        actions.add_action_entries (action_entries, this);
        insert_action_group (ACTION_GROUP_PREFIX_NAME, actions);
        foreach (var action in action_accelerators.get_keys ()) {
            app.set_accels_for_action (ACTION_GROUP_PREFIX + action,
                                       action_accelerators[action].to_array ());
        }

        SimpleAction open_torrent = new SimpleAction (ACTION_OPEN_COMPLETED_TORRENT, VariantType.INT32);
        open_torrent.activate.connect ((parameter) => {
            torrent_manager.open_torrent_location (parameter.get_int32 ());
        });
        app.add_action (open_torrent);

        torrent_manager = new TorrentManager ();

        build_headerbar ();
        build_main_interface ();
        build_welcome_screen ();

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        infobar = new Widgets.MultiInfoBar ();
        infobar.set_message_type (Gtk.MessageType.WARNING);
        infobar.no_show_all = true;
        infobar.visible = false;

        stack = new Gtk.Stack ();
        stack.add_named (welcome_screen, "welcome");
        stack.add_named (main_pane, "main");
        stack.visible_child_name = "welcome";
        grid.add (infobar);
        grid.add (stack);
        add (grid);

        set_titlebar (headerbar);
        show_all ();

        launcher_entry = Unity.LauncherEntry.get_for_desktop_id ("com.github.davidmhewitt.torrential.desktop");

        var torrents = torrent_manager.get_torrents ();
        if (torrents.size > 0) {
            enable_main_view ();
            update_category_totals (torrents);
        }

        var torrent_completed_signal_id = torrent_manager.torrent_completed.connect ((torrent) => {
            var notification = new Notification (_("Torrent Complete"));
            notification.set_body (_("\u201C%s\u201D has finished downloading").printf (torrent.name));
            notification.set_default_action_and_target_value ("app." + ACTION_OPEN_COMPLETED_TORRENT, new Variant.int32 (torrent.id));
            app.send_notification ("app.torrent-completed", notification);
        });

        torrent_manager.blocklist_load_failed.connect (() => {
            infobar.add_error (_("Failed to load blocklist. All torrents paused as a precaution."));
            infobar.show ();
        });

        torrent_manager.blocklist_load_complete.connect (() => {
            if (prefs_window != null) {
                prefs_window.blocklist_load_complete ();
            }
        });

        refresh_timer = Timeout.add_seconds (1, () => {
            list_box.update ();
            update_category_totals (torrent_manager.get_torrents ());
            launcher_entry.progress = torrent_manager.get_overall_progress ();
            launcher_entry.progress_visible = true;
            return true;
        });

        delete_event.connect (() => {
            if (saved_state.hide_on_close && !quitting_for_real) {
                return hide_on_delete ();
            } else {
                Source.remove (refresh_timer);
                torrent_manager.disconnect (torrent_completed_signal_id);

                int window_width;
                int window_height;
                get_size (out window_width, out window_height);
                saved_state.window_width = window_width;
                saved_state.window_height = window_height;
                if (is_maximized) {
                    saved_state.window_state = Settings.WindowState.MAXIMIZED;
                } else {
                    saved_state.window_state = Settings.WindowState.NORMAL;
                }
                return false;
            }
        });
    }

    private void update_category_totals (Gee.ArrayList<Torrent> torrents) {
        if (torrents.size == 0) {
            search_entry.sensitive = false;
            stack.visible_child_name = "welcome";
        }

        all_category.badge = torrents.size.to_string ();
        uint paused = 0, downloading = 0, seeding = 0;
        foreach (var torrent in torrents) {
            if (torrent.paused) {
                paused++;
            }
            if (torrent.downloading) {
                downloading++;
            }
            if (torrent.seeding) {
                seeding++;
            }
        }
        paused_category.badge = paused.to_string ();
        downloading_category.badge = downloading.to_string ();
        seeding_category.badge = seeding.to_string ();
    }

    private void build_headerbar () {
        headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;

        var about_button = new Gtk.MenuButton ();
        about_button.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
        about_button.tooltip_text = _("Application menu");
        about_button.popup = build_menu ();
        headerbar.pack_end (about_button);

        var open_button = new Gtk.ToolButton.from_stock (Gtk.Stock.OPEN);
        open_button.set_action_name (ACTION_GROUP_PREFIX + ACTION_OPEN);
        headerbar.pack_start (open_button);

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Torrents");
        headerbar.pack_end (search_entry);
        search_entry.sensitive = false;
        search_entry.search_changed.connect (() => {
            if (search_entry.text != "") {
                search_category.visible = true;
                sidebar.selected = search_category;
                list_box.filter (Widgets.TorrentListBox.FilterType.SEARCH, search_entry.text);
            } else {
                search_category.visible = false;
                sidebar.selected = all_category;
            }
        });
    }

    private void build_main_interface () {
        all_category = new Granite.Widgets.SourceList.Item (_("All"));
        try {
            all_category.icon = Icon.new_for_string ("folder");
        } catch (Error e) {
            warning ("Error creating icon for 'All' category: %s", e.message);
        }
        all_category.badge = "0";
        downloading_category = new Granite.Widgets.SourceList.Item (_("Downloading"));
        try {
            downloading_category.icon = Icon.new_for_string ("go-down");
        } catch (Error e) {
            warning ("Error creating icon for 'Downloading' category: %s", e.message);
        }
        downloading_category.badge = "0";
        seeding_category = new Granite.Widgets.SourceList.Item (_("Seeding"));
        try {
            seeding_category.icon = Icon.new_for_string ("go-up");
        } catch (Error e) {
            warning ("Error creating icon for 'Seeding' category: %s", e.message);
        }
        seeding_category.badge = "0";
        paused_category = new Granite.Widgets.SourceList.Item (_("Paused"));
        try {
            paused_category.icon = Icon.new_for_string ("media-playback-pause");
        } catch (Error e) {
            warning ("Error creating icon for 'Paused' category: %s", e.message);
        }
        paused_category.badge = "0";
        search_category = new Granite.Widgets.SourceList.Item (_("Search Results"));
        try {
            search_category.icon = Icon.new_for_string ("edit-find");
        } catch (Error e) {
            warning ("Error creating icon for 'Search Results' category: %s", e.message);
        }
        search_category.visible = false;

        sidebar = new Granite.Widgets.SourceList ();
        var root = sidebar.root;
        root.add (all_category);
        root.add (downloading_category);
        root.add (seeding_category);
        root.add (paused_category);
        root.add (search_category);

        sidebar.item_selected.connect ((item) => {
            if (item == all_category) {
                list_box.filter (Widgets.TorrentListBox.FilterType.ALL, null);
            } else if (item == downloading_category) {
                list_box.filter (Widgets.TorrentListBox.FilterType.DOWNLOADING, null);
            } else if (item == seeding_category) {
                list_box.filter (Widgets.TorrentListBox.FilterType.SEEDING, null);
            } else if (item == paused_category) {
                list_box.filter (Widgets.TorrentListBox.FilterType.PAUSED, null);
            } else if (item == search_category) {
                list_box.filter (Widgets.TorrentListBox.FilterType.SEARCH, search_entry.text);
            }
        });

        main_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        main_pane.position = 175;

        main_pane.add1 (sidebar);

        list_box = new Widgets.TorrentListBox (torrent_manager.get_torrents ());
        list_box.torrent_removed.connect ((torrent) => torrent_manager.remove_torrent (torrent));
        list_box.open_torrent.connect ((id) => torrent_manager.open_torrent_location (id));
        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.add (list_box);
        main_pane.add2 (scroll);
    }

    private void build_welcome_screen () {
        welcome_screen = new Granite.Widgets.Welcome (_("No Torrents Added"), _("Add a torrent file to begin downloading."));
        welcome_screen.append ("folder", _("Open Torrent"), _("Open a torrent file from your computer."));
        welcome_screen.append ("open-menu", _("Preferences"), _("Set download folder and other preferences."));

        welcome_screen.activated.connect ((index) => {
            switch (index) {
                case 0:
                    actions.activate_action (ACTION_OPEN, null);
                    break;
                case 1:
                    actions.activate_action (ACTION_PREFERENCES, null);
                    break;
                default:
                    break;
            }
        });
    }

    private void enable_main_view () {
        search_entry.sensitive = true;
        stack.visible_child_name = "main";
    }

    private Gtk.Menu build_menu () {
        var app_menu = new Gtk.Menu ();

        var preferences_item = new Gtk.MenuItem.with_mnemonic (_("_Preferences"));
        preferences_item.set_action_name (ACTION_GROUP_PREFIX + ACTION_PREFERENCES);
        app_menu.append (preferences_item);

        var about_item = new Gtk.MenuItem.with_mnemonic (_("_About"));
        about_item.set_action_name (ACTION_GROUP_PREFIX + ACTION_ABOUT);
        app_menu.append (about_item);

        app_menu.append (new Gtk.SeparatorMenuItem ());

        var quit_item = new Gtk.MenuItem.with_mnemonic (_("_Quit"));
        quit_item.set_action_name (ACTION_GROUP_PREFIX + ACTION_QUIT);
        app_menu.append (quit_item);

        app_menu.show_all ();

        return app_menu;
    }

    private void on_preferences (SimpleAction action) {
        prefs_window = new PreferencesWindow (this);
        prefs_window.on_close.connect (() => {
            torrent_manager.close.begin ();
        });
        prefs_window.update_blocklist.connect (() => {
            torrent_manager.update_blocklists (true);
        });
        prefs_window.show_all ();
    }

    private void on_about (SimpleAction action) {
        show_about (this);
    }

    private void on_quit (SimpleAction action) {
        quitting_for_real = true;
        close ();
    }

    private void on_hide (SimpleAction action) {
        close ();
    }

    private void on_open (SimpleAction action) {
        var filech = new Gtk.FileChooserDialog (_("Open some torrents"), this, Gtk.FileChooserAction.OPEN);
        filech.set_select_multiple (true);
        filech.add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        filech.add_button (_("Open"), Gtk.ResponseType.ACCEPT);
        filech.set_default_response (Gtk.ResponseType.ACCEPT);
        filech.set_current_folder_uri (GLib.Environment.get_home_dir ());

        var all_files_filter = new Gtk.FileFilter ();
        all_files_filter.set_filter_name (_("All files"));
        all_files_filter.add_pattern ("*");
        var torrent_files_filter = new Gtk.FileFilter ();
        torrent_files_filter.set_filter_name (_("Torrent files"));
        torrent_files_filter.add_mime_type ("application/x-bittorrent");
        filech.add_filter (torrent_files_filter);
        filech.add_filter (all_files_filter);

        if (filech.run () == Gtk.ResponseType.ACCEPT) {
            add_files (filech.get_uris ());
        }

        filech.close ();
    }

    public void add_files (SList<string> uris) {
        Gee.ArrayList<string> errors = new Gee.ArrayList<string> ();
        foreach (string uri in uris) {
            string path = "";
            try {
                path = Filename.from_uri (uri);
            } catch (ConvertError e) {
                warning ("Error opening %s, error: %s", uri, e.message);
                continue;
            }
            Torrent? new_torrent;
            var result = torrent_manager.add_torrent_by_path (path, out new_torrent);
            if (result == Transmission.ParseResult.OK) {
                list_box.add_torrent (new_torrent);
            } else if (result == Transmission.ParseResult.ERR) {
                var basename = Filename.display_basename (path);
                errors.add (_("Failed to add \u201C%s\u201D as it doesn\u2019t appear to be a valid torrent.").printf (basename));
            } else {
                var basename = Filename.display_basename (path);
                errors.add (_("Didn\u2019t add \u201C%s\u201D. An identical torrent has already been added.").printf (basename));
            }
        }
        if (uris.length () - errors.size > 0) {
            enable_main_view ();
        }
        if (errors.size > 0) {
            infobar.add_errors (errors);
            infobar.show ();
        }
    }

    public void add_magnet (string magnet) {
        warning ("adding magnet: %s", magnet);
        Torrent? new_torrent;
        var result = torrent_manager.add_torrent_by_magnet (magnet, out new_torrent);
        if (result == Transmission.ParseResult.OK) {
            list_box.add_torrent (new_torrent);
            enable_main_view ();
        } else if (result == Transmission.ParseResult.ERR) {
            infobar.add_error (_("Failed to add magnet link as it doesn\u2019t appear to be valid."));
            infobar.show ();
        } else {
            infobar.add_error (_("Didn\u2019t add magnet link. An identical torrent has already been added."));
            infobar.show ();
        }
    }
}
