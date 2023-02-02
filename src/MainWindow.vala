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

public class Torrential.MainWindow : Gtk.ApplicationWindow {
    private Granite.Widgets.ModeButton view_mode;
    private Gtk.Button magnet_button;
    private Gtk.Stack stack;
    private Granite.Widgets.Welcome welcome_screen;
    private Granite.Widgets.Toast toast;
    private Widgets.MultiInfoBar infobar;
    private Widgets.TorrentListBox list_box;

    private Gtk.SearchEntry search_entry;

    private SimpleActionGroup actions = new SimpleActionGroup ();

    public TorrentManager torrent_manager;
    private GLib.Settings settings;
    private FileMonitor download_monitor;

    private const string ACTION_GROUP_PREFIX_NAME = "tor";
    private const string ACTION_GROUP_PREFIX = ACTION_GROUP_PREFIX_NAME + ".";

    private const string ACTION_PREFERENCES = "preferences";
    private const string ACTION_QUIT = "quit";
    private const string ACTION_OPEN = "open";
    private const string ACTION_OPEN_MAGNET = "open-magnet";
    private const string ACTION_OPEN_COMPLETED_TORRENT = "show-torrent";
    private const string ACTION_SHOW_WINDOW = "show-window";

    private bool quitting = false;

    private const ActionEntry[] action_entries = {
        {ACTION_PREFERENCES,                on_preferences          },
        {ACTION_QUIT,                       on_quit                 },
        {ACTION_OPEN,                       on_open                 },
        {ACTION_OPEN_MAGNET,                on_open_magnet          }
    };

    public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
    static construct {
        action_accelerators.set (ACTION_PREFERENCES, "<Ctrl>comma");
        action_accelerators.set (ACTION_QUIT, "<Ctrl>q");
        action_accelerators.set (ACTION_OPEN, "<Ctrl>o");
        action_accelerators.set (ACTION_OPEN_MAGNET, "<Ctrl>m");
    }

    public MainWindow (Application app, TorrentManager torrent_manager) {
        Object (
            application: app,
            title: "Torrential"
        );

        this.torrent_manager = torrent_manager;

        settings = new GLib.Settings ("com.github.davidmhewitt.torrential.settings");

        set_default_size (
            settings.get_int ("window-width"),
            settings.get_int ("window-height")
        );

        // Maximize window if necessary
        switch (settings.get_string ("window-state")) {
            case "maximized":
                this.maximize ();
                break;
            default:
                break;
        }

        actions.add_action_entries (action_entries, this);
        insert_action_group (ACTION_GROUP_PREFIX_NAME, actions);
        foreach (var action in action_accelerators.get_keys ()) {
            application.set_accels_for_action (ACTION_GROUP_PREFIX + action,
                                       action_accelerators[action].to_array ());
        }

        SimpleAction open_torrent = new SimpleAction (ACTION_OPEN_COMPLETED_TORRENT, VariantType.INT32);
        open_torrent.activate.connect ((parameter) => {
            torrent_manager.open_torrent (parameter.get_int32 ());
        });
        application.add_action (open_torrent);

        SimpleAction show_window = new SimpleAction (ACTION_SHOW_WINDOW, null);
        show_window.activate.connect (() => {
            present ();
            present_with_time (0);
        });
        application.add_action (show_window);

        infobar = new Widgets.MultiInfoBar () {
            revealed = false,
            message_type = Gtk.MessageType.WARNING
        };

        list_box = new Widgets.TorrentListBox (torrent_manager.get_torrents ());
        list_box.torrent_removed.connect ((torrent) => torrent_manager.remove_torrent (torrent));
        list_box.open_torrent.connect ((id) => torrent_manager.open_torrent (id));
        list_box.open_torrent_location.connect ((id) => torrent_manager.open_torrent_location (id));
        list_box.link_copied.connect (on_link_copied);
        var list_box_scroll = new Gtk.ScrolledWindow (null, null);
        list_box_scroll.add (list_box);

        build_welcome_screen ();

        var no_results_alertview = new Granite.Widgets.AlertView (_("No Search Results"), _("Try changing search terms"), "edit-find-symbolic");
        var empty_category_alertview = new Granite.Widgets.AlertView (_("No Torrents Here"), _("Try a different category"), "edit-find-symbolic");

        stack = new Gtk.Stack ();
        stack.add_named (welcome_screen, "welcome");
        stack.add_named (list_box_scroll, "main");
        stack.add_named (no_results_alertview, "no_results");
        stack.add_named (empty_category_alertview, "empty_category");
        stack.visible_child_name = "welcome";

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.add (infobar);
        box.add (stack);

        var overlay = new Gtk.Overlay ();
        toast = new Granite.Widgets.Toast ("");
        overlay.add_overlay (box);
        overlay.add_overlay (toast);

        add (overlay);

        set_titlebar (build_headerbar ());
        show_all ();

        var torrents = torrent_manager.get_torrents ();
        if (torrents.size > 0) {
            enable_main_view ();
            update_category_totals (torrents);
        }

        torrent_manager.torrent_completed.connect ((torrent) => {
            var focused = (get_window ().get_state () & Gdk.WindowState.FOCUSED) != 0;
            if (!focused) {
                var notification = new Notification (_("Torrent Complete"));
                notification.set_body (_("\u201C%s\u201D has finished downloading").printf (torrent.name));
                notification.set_default_action_and_target_value ("app." + ACTION_OPEN_COMPLETED_TORRENT, new Variant.int32 (torrent.id));
                application.send_notification ("app.torrent-completed", notification);
            }
        });

        Timeout.add_seconds (1, () => {
            list_box.update ();
            update_category_totals (torrent_manager.get_torrents ());
            Granite.Services.Application.set_progress.begin (torrent_manager.get_overall_progress ());
            var focused = (get_window ().get_state () & Gdk.WindowState.FOCUSED) != 0;
            if (!focused && list_box.has_visible_children ()) {
                Granite.Services.Application.set_progress_visible.begin (true);
            } else {
                Granite.Services.Application.set_progress_visible.begin (false);
            }
            return true;
        });

        delete_event.connect (() => {
            if (!quitting && settings.get_boolean ("hide-on-close") && torrent_manager.has_active_torrents ()) {
                return hide_on_delete ();
            }

            int window_width;
            int window_height;
            get_size (out window_width, out window_height);
            settings.set_int ("window-width", window_width);
            settings.set_int ("window-height", window_height);
            if (is_maximized) {
                settings.set_string ("window-state", "maximized");
            } else {
                settings.set_string ("window-state", "normal");
            }

            return false;
        });

        var download_folder = File.new_for_path (Environment.get_user_special_dir (UserDirectory.DOWNLOAD));
        try {
            download_monitor = download_folder.monitor (FileMonitorFlags.NONE, null);
            download_monitor.changed.connect (on_download_folder_changed);
        } catch (Error e) {
            warning ("Error setting up watchfolder on Download folder: %s", e.message);
        }
    }

    private void update_category_totals (Gee.ArrayList<Torrent> torrents) {
        if (torrents.size == 0) {
            search_entry.sensitive = false;
            view_mode.sensitive = false;
            stack.visible_child_name = "welcome";
        }
    }

    private Gtk.HeaderBar build_headerbar () {
        var headerbar = new Gtk.HeaderBar () {
            show_close_button = true,
            title = title
        };

        var menu = new Menu ();
        menu.append (_("_Preferences"), ACTION_GROUP_PREFIX + ACTION_PREFERENCES);
        menu.append (_("_Quit"), ACTION_GROUP_PREFIX + ACTION_QUIT);

        var menu_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR),
            menu_model = menu,
            tooltip_text = _("Application menu"),
            use_popover = true
        };
        headerbar.pack_end (menu_button);

        var open_button = new Gtk.Button.from_icon_name ("document-open", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = ACTION_GROUP_PREFIX + ACTION_OPEN,
            tooltip_text = _("Open .torrent file")
        };
        headerbar.pack_start (open_button);

        magnet_button = new Gtk.Button.from_icon_name ("open-magnet", Gtk.IconSize.LARGE_TOOLBAR) {
            action_name = ACTION_GROUP_PREFIX + ACTION_OPEN_MAGNET,
            tooltip_text = _("Open magnet link")
        };
        headerbar.pack_start (magnet_button);

        search_entry = new Gtk.SearchEntry () {
            placeholder_text = _("Search Torrents"),
            sensitive = false,
            valign = Gtk.Align.CENTER
        };
        headerbar.pack_end (search_entry);
        search_entry.search_changed.connect (() => {
            update_view ();
        });

        view_mode = new Granite.Widgets.ModeButton () {
            sensitive = false,
            margin_start = 20,
            valign = Gtk.Align.CENTER
        };
        view_mode.append_text (_("All"));
        view_mode.append_text (_("Downloading"));
        view_mode.append_text (_("Seeding"));
        view_mode.append_text (_("Paused"));
        view_mode.selected = 0;

        view_mode.notify["selected"].connect (() => {
            update_view ();
        });

        headerbar.set_custom_title (view_mode);

        return headerbar;
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

    private void on_link_copied () {
        toast.title = _("Magnet Link Copied To Clipboard");
        toast.send_notification ();
    }

    private void on_preferences (SimpleAction action) {
        var prefs_window = new PreferencesWindow (this);
        prefs_window.on_close.connect (() => {
            torrent_manager.update_session_settings ();
        });

        prefs_window.show_all ();
    }

    public void quit () {
        quitting = true;
        close ();
    }

    private void on_quit (SimpleAction action) {
        quit ();
    }

    private void on_open (SimpleAction action) {
        var all_files_filter = new Gtk.FileFilter ();
        all_files_filter.set_filter_name (_("All files"));
        all_files_filter.add_pattern ("*");

        var torrent_files_filter = new Gtk.FileFilter ();
        torrent_files_filter.set_filter_name (_("Torrent files"));
        torrent_files_filter.add_mime_type ("application/x-bittorrent");

        var filech = new Gtk.FileChooserNative (_("Open some torrents"), this, Gtk.FileChooserAction.OPEN, _("Open"), _("Cancel"));
        filech.set_select_multiple (true);
        filech.add_filter (torrent_files_filter);
        filech.add_filter (all_files_filter);

        filech.show ();

        filech.response.connect ((response) => {
            if (response == Gtk.ResponseType.ACCEPT) {
                add_files (filech.get_uris ());
            }
        });
    }

    private void on_open_magnet () {
        Gtk.Popover popover = new Gtk.Popover (magnet_button);

        var add_button = new Gtk.Button.with_label (_("Add Magnet Link")) {
            sensitive = false
        };

        var entry = new Gtk.Entry ();
        entry.changed.connect (() => {
            // Only allow OK when there's text in the box.
            add_button.sensitive = entry.text.strip () != "";
        });

        entry.activate.connect (() => {
            add_button.activate ();
        });

        add_button.clicked.connect (() => {
            add_magnet (entry.text, true);
            popover.popdown ();
        });

        var clipboard = Gtk.Clipboard.get (Gdk.SELECTION_CLIPBOARD);
        string? contents = clipboard.wait_for_text ();
        if (contents != null && contents.has_prefix ("magnet:")) {
            entry.text = contents;
        }

        var label = new Gtk.Label (_("Magnet URL:")) {
            halign = Gtk.Align.START
        };

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3) {
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        content_box.add (label);
        content_box.add (entry);
        content_box.add (add_button);

        popover.add (content_box);

        popover.show_all ();
        popover.popup ();
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
                application.send_notification ("app.torrent-added", notification);
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
                application.send_notification ("app.magnet-added", notification);
            }
        } else if (result == Transmission.ParseResult.ERR) {
            infobar.add_error (_("Failed to add magnet link as it doesn\u2019t appear to be valid."));
            send_magnet_error_notification ();
        } else {
            infobar.add_error (_("Didn\u2019t add magnet link. An identical torrent has already been added."));
            send_magnet_error_notification ();
        }
    }

    private void send_magnet_error_notification () {
        var focused = (get_window ().get_state () & Gdk.WindowState.FOCUSED) != 0;
        if (!focused) {
            var notification = new Notification (_("Magnet Link"));
            notification.set_body (_("Failed to add magnet link"));
            notification.set_default_action ("app." + ACTION_SHOW_WINDOW);
            application.send_notification ("app.magnet-added", notification);
        }
    }
}
