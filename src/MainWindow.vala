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
    private bool quitting_for_real = false;

    private uint refresh_timer;

    private PreferencesWindow? prefs_window = null;
    private weak Application app;

    private Granite.Widgets.ModeButton view_mode;
    private Gtk.Stack stack;
    private Gtk.HeaderBar headerbar;
    private Granite.Widgets.Welcome welcome_screen;
    private Granite.Widgets.Toast toast;
    private Widgets.MultiInfoBar infobar;
    private Widgets.TorrentListBox list_box;
    private Gtk.ScrolledWindow list_box_scroll;
    private Unity.LauncherEntry launcher_entry;

    private Gtk.SearchEntry search_entry;

    private SimpleActionGroup actions = new SimpleActionGroup ();

    public TorrentManager torrent_manager;
    private Settings saved_state;
    private FileMonitor download_monitor;

    private const string ACTION_GROUP_PREFIX_NAME = "tor";
    private const string ACTION_GROUP_PREFIX = ACTION_GROUP_PREFIX_NAME + ".";

    private const string ACTION_PREFERENCES = "preferences";
    private const string ACTION_QUIT = "quit";
    private const string ACTION_HIDE = "hide";
    private const string ACTION_OPEN = "open";
    private const string ACTION_OPEN_MAGNET = "open-magnet";
    private const string ACTION_OPEN_COMPLETED_TORRENT = "show-torrent";
    private const string ACTION_SHOW_WINDOW = "show-window";

    private uint int_sig;
    private uint term_sig;

    private const ActionEntry[] action_entries = {
        {ACTION_PREFERENCES,                on_preferences          },
        {ACTION_QUIT,                       on_quit                 },
        {ACTION_HIDE,                       on_hide                 },
        {ACTION_OPEN,                       on_open                 },
        {ACTION_OPEN_MAGNET,                on_open_magnet          }
    };

    public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
    static construct {
        action_accelerators.set (ACTION_PREFERENCES, "<Ctrl>comma");
        action_accelerators.set (ACTION_QUIT, "<Ctrl>q");
        action_accelerators.set (ACTION_HIDE, "<Ctrl>w");
        action_accelerators.set (ACTION_OPEN, "<Ctrl>o");
        action_accelerators.set (ACTION_OPEN_MAGNET, "<Ctrl>m");
    }

    public MainWindow (Application app) {
        Gtk.IconTheme.get_default ().add_resource_path ("/com/github/davidmhewitt/torrential");

        this.app = app;
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
            torrent_manager.open_torrent (parameter.get_int32 ());
        });
        app.add_action (open_torrent);

        SimpleAction show_window = new SimpleAction (ACTION_SHOW_WINDOW, null);
        show_window.activate.connect (() => {
            present ();
            present_with_time (0);
        });
        app.add_action (show_window);

        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        infobar = new Widgets.MultiInfoBar ();
        infobar.set_message_type (Gtk.MessageType.WARNING);
        infobar.no_show_all = true;
        infobar.visible = false;

        torrent_manager = new TorrentManager ();

        build_headerbar ();
        build_main_interface ();
        build_welcome_screen ();

        var no_results_alertview = new Granite.Widgets.AlertView (_("No Search Results"), _("Try changing search terms"), "edit-find-symbolic");
        var empty_category_alertview = new Granite.Widgets.AlertView (_("No Torrents Here"), _("Try a different category"), "edit-find-symbolic");

        stack = new Gtk.Stack ();
        stack.add_named (welcome_screen, "welcome");
        stack.add_named (list_box_scroll, "main");
        stack.add_named (no_results_alertview, "no_results");
        stack.add_named (empty_category_alertview, "empty_category");
        stack.visible_child_name = "welcome";
        grid.add (infobar);
        grid.add (stack);

        var overlay = new Gtk.Overlay ();
        toast = new Granite.Widgets.Toast ("");
        overlay.add_overlay (grid);
        overlay.add_overlay (toast);

        add (overlay);

        set_titlebar (headerbar);
        show_all ();

        launcher_entry = Unity.LauncherEntry.get_for_desktop_id ("com.github.davidmhewitt.torrential.desktop");

        var torrents = torrent_manager.get_torrents ();
        if (torrents.size > 0) {
            enable_main_view ();
            update_category_totals (torrents);
        }

        var torrent_completed_signal_id = torrent_manager.torrent_completed.connect ((torrent) => {
            var focused = (get_window ().get_state () & Gdk.WindowState.FOCUSED) != 0;
            if (!focused) {
                var notification = new Notification (_("Torrent Complete"));
                notification.set_body (_("\u201C%s\u201D has finished downloading").printf (torrent.name));
                notification.set_default_action_and_target_value ("app." + ACTION_OPEN_COMPLETED_TORRENT, new Variant.int32 (torrent.id));
                app.send_notification ("app.torrent-completed", notification);
            }
        });

        torrent_manager.blocklist_load_failed.connect (() => {
            infobar.add_error (_("Failed to load blocklist. All torrents paused as a precaution."));
            infobar.show ();
        });

        refresh_timer = Timeout.add_seconds (1, () => {
            list_box.update ();
            update_category_totals (torrent_manager.get_torrents ());
            launcher_entry.progress = torrent_manager.get_overall_progress ();
            var focused = (get_window ().get_state () & Gdk.WindowState.FOCUSED) != 0;
            if (!focused && list_box.has_visible_children ()) {
                launcher_entry.progress_visible = true;
            } else {
                launcher_entry.progress_visible = false;
            }
            return true;
        });

        delete_event.connect (() => {
            if (!torrent_manager.has_active_torrents ()) {
                quitting_for_real = true;
            }
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

        var download_folder = File.new_for_path (Environment.get_user_special_dir (UserDirectory.DOWNLOAD));
        try {
            download_monitor = download_folder.monitor (FileMonitorFlags.NONE, null);
            download_monitor.changed.connect (on_download_folder_changed);
        } catch (Error e) {
            warning ("Error setting up watchfolder on Download folder: %s", e.message);
        }

#if VALA_0_40
        int_sig = Unix.signal_add (Posix.Signal.INT, quit_source_func, Priority.HIGH);
        term_sig = Unix.signal_add (Posix.Signal.TERM, quit_source_func, Priority.HIGH);
#else
        int_sig = Unix.signal_add (Posix.SIGINT, quit_source_func, Priority.HIGH);
        term_sig = Unix.signal_add (Posix.SIGTERM, quit_source_func, Priority.HIGH);
#endif
    }

    public bool quit_source_func () {
        quit ();
        return false;
    }

    public void wait_for_close () {
        torrent_manager.wait_for_close ();
    }

    private void update_category_totals (Gee.ArrayList<Torrent> torrents) {
        if (torrents.size == 0) {
            search_entry.sensitive = false;
            view_mode.sensitive = false;
            stack.visible_child_name = "welcome";
        }
    }

    private void build_headerbar () {
        headerbar = new Gtk.HeaderBar ();
        headerbar.show_close_button = true;

        var menu_button = new Gtk.MenuButton ();
        menu_button.image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR);
        menu_button.tooltip_text = _("Application menu");
        menu_button.popup = build_menu ();
        headerbar.pack_end (menu_button);

        var open_button = new Gtk.ToolButton.from_stock (Gtk.Stock.OPEN);
        open_button.set_action_name (ACTION_GROUP_PREFIX + ACTION_OPEN);
        open_button.tooltip_text = _("Open .torrent file");
        headerbar.pack_start (open_button);

        var magnet_image = new Gtk.Image.from_icon_name ("open-magnet", Gtk.IconSize.LARGE_TOOLBAR);
        var magnet_button = new Gtk.ToolButton (magnet_image, null);
        magnet_button.set_action_name (ACTION_GROUP_PREFIX + ACTION_OPEN_MAGNET);
        magnet_button.tooltip_text = _("Open magnet link");
        headerbar.pack_start (magnet_button);

        search_entry = new Gtk.SearchEntry ();
        search_entry.placeholder_text = _("Search Torrents");
        headerbar.pack_end (search_entry);
        search_entry.sensitive = false;
        search_entry.search_changed.connect (() => {
            update_view ();
        });

        view_mode = new Granite.Widgets.ModeButton ();
        view_mode.sensitive = false;
        view_mode.margin = 1;
        view_mode.margin_right = 20;
        view_mode.append_text (_("All"));
        view_mode.append_text (_("Downloading"));
        view_mode.append_text (_("Seeding"));
        view_mode.append_text (_("Paused"));
        view_mode.selected = 0;

        view_mode.notify["selected"].connect (() => {
            update_view ();
        });

        headerbar.set_custom_title (view_mode);
    }

    private void update_view () {
        if (search_entry.text != "") {
            list_box.filter (Widgets.TorrentListBox.FilterType.SEARCH, search_entry.text);
            if (!list_box.has_visible_children ()) {
                stack.visible_child_name = "no_results";
            } else {
                stack.visible_child_name = "main";
            }
            return;
        }
        switch (view_mode.selected) {
            case 0:
                list_box.filter (Widgets.TorrentListBox.FilterType.ALL, null);
                break;
            case 1:
                list_box.filter (Widgets.TorrentListBox.FilterType.DOWNLOADING, null);
                break;
            case 2:
                list_box.filter (Widgets.TorrentListBox.FilterType.SEEDING, null);
                break;
            case 3:
                list_box.filter (Widgets.TorrentListBox.FilterType.PAUSED, null);
                break;
            default:
                break;
        }
        if (!list_box.has_visible_children ()) {
            stack.visible_child_name = "empty_category";
        } else {
            stack.visible_child_name = "main";
        }
    }

    private void build_main_interface () {
        list_box = new Widgets.TorrentListBox (torrent_manager.get_torrents ());
        list_box.torrent_removed.connect ((torrent, delete_files) => torrent_manager.remove_torrent (torrent, delete_files));
        list_box.open_torrent.connect ((id) => torrent_manager.open_torrent (id));
        list_box.open_torrent_location.connect ((id) => torrent_manager.open_torrent_location (id));
        list_box.link_copied.connect (on_link_copied);
        list_box_scroll = new Gtk.ScrolledWindow (null, null);
        list_box_scroll.add (list_box);
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
        view_mode.sensitive = true;
        stack.visible_child_name = "main";
    }

    private Gtk.Menu build_menu () {
        var app_menu = new Gtk.Menu ();

        var preferences_item = new Gtk.MenuItem.with_mnemonic (_("_Preferences"));
        preferences_item.set_action_name (ACTION_GROUP_PREFIX + ACTION_PREFERENCES);
        app_menu.append (preferences_item);

        app_menu.append (new Gtk.SeparatorMenuItem ());

        var quit_item = new Gtk.MenuItem.with_mnemonic (_("_Quit"));
        quit_item.set_action_name (ACTION_GROUP_PREFIX + ACTION_QUIT);
        app_menu.append (quit_item);

        app_menu.show_all ();

        return app_menu;
    }

    private void on_link_copied () {
        toast.title = _("Magnet Link Copied To Clipboard");
        toast.send_notification ();
    }

    private void on_preferences (SimpleAction action) {
        prefs_window = new PreferencesWindow (this);
        prefs_window.on_close.connect (() => {
            try {
                torrent_manager.close ();
            } catch (ThreadError e) {
                warning ("Error with thread while updating session settings. Error: %s", e.message);
            }
        });

        prefs_window.show_all ();
    }

    public void quit () {
        Source.remove (int_sig);
        Source.remove (term_sig);

        launcher_entry.progress_visible = false;
        quitting_for_real = true;
        close ();
    }

    private void on_quit (SimpleAction action) {
        quit ();
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

    private void on_open_magnet () {
        Gtk.Dialog dialog = new Gtk.Dialog ();

        dialog.add_buttons (Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL, Gtk.Stock.OK, Gtk.ResponseType.OK);

        Gtk.Entry entry = new Gtk.Entry ();
        entry.changed.connect (() => {
            // Only allow OK when there's text in the box.
            dialog.set_response_sensitive (Gtk.ResponseType.OK, entry.text.strip () != "");
        });

        dialog.width_request = 350;
        dialog.get_content_area ().spacing = 7;
        dialog.get_content_area ().border_width = 10;
        dialog.get_content_area ().pack_start (new Gtk.Label (_("Magnet URL:")));
        dialog.get_content_area ().pack_start (entry);
        dialog.get_widget_for_response (Gtk.ResponseType.OK).can_default = true;
        dialog.set_default_response (Gtk.ResponseType.OK);
        dialog.show_all ();

        var clipboard = Gtk.Clipboard.get (Gdk.SELECTION_CLIPBOARD);
        string? contents = clipboard.wait_for_text ();
        if (contents != null || contents != "") {
            entry.text = contents;
        }

        entry.activates_default = true;
        entry.select_region (0, -1);

        dialog.set_response_sensitive (Gtk.ResponseType.OK, entry.text.strip () != "");

        int response = dialog.run ();
        if (response == Gtk.ResponseType.OK) {
            add_magnet (entry.text, true);
        }

        dialog.destroy ();
    }

    private void on_download_folder_changed (File file, File? other_file, FileMonitorEvent event) {
        if (event == FileMonitorEvent.CREATED) {
            if (ContentType.guess (file.get_basename (), null, null) == "application/x-bittorrent") {
                add_monitored_file (file.get_path ());
            }
        }
    }

    private void add_monitored_file (string path) {
        var focused = (get_window ().get_state () & Gdk.WindowState.FOCUSED) != 0;

        Torrent? new_torrent;
        var result = torrent_manager.add_torrent_by_path (path, out new_torrent);
        if (result == Transmission.ParseResult.OK) {
            list_box.add_torrent (new_torrent);
            enable_main_view ();
            if (!focused) {
                var notification = new Notification (_("Torrent Added"));
                notification.set_body (_("Successfully added torrent file from Downloads"));
                notification.set_default_action ("app." + ACTION_SHOW_WINDOW);
                app.send_notification ("app.torrent-added", notification);
            }
        }
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

    public void add_magnet (string magnet, bool silent = false) {
        Torrent? new_torrent;
        var result = torrent_manager.add_torrent_by_magnet (magnet, out new_torrent);
        if (result == Transmission.ParseResult.OK) {
            list_box.add_torrent (new_torrent);
            enable_main_view ();
            var focused = (get_window ().get_state () & Gdk.WindowState.FOCUSED) != 0;
            if (!focused && !silent) {
                var notification = new Notification (_("Magnet Link"));
                notification.set_body (_("Successfully added magnet link"));
                notification.set_default_action ("app." + ACTION_SHOW_WINDOW);
                app.send_notification ("app.magnet-added", notification);
            }
        } else if (result == Transmission.ParseResult.ERR) {
            infobar.add_error (_("Failed to add magnet link as it doesn\u2019t appear to be valid."));
            infobar.show ();
            send_magnet_error_notification ();
        } else {
            infobar.add_error (_("Didn\u2019t add magnet link. An identical torrent has already been added."));
            infobar.show ();
            send_magnet_error_notification ();
        }
    }

    private void send_magnet_error_notification () {
        var focused = (get_window ().get_state () & Gdk.WindowState.FOCUSED) != 0;
        if (!focused) {
            var notification = new Notification (_("Magnet Link"));
            notification.set_body (_("Failed to add magnet link"));
            notification.set_default_action ("app." + ACTION_SHOW_WINDOW);
            app.send_notification ("app.magnet-added", notification);
        }
    }
}
