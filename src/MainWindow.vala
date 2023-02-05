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
    private Gtk.Button magnet_button;
    private Gtk.Stack stack;
    private Granite.Toast toast;
    private Widgets.MultiInfoBar infobar;
    private Widgets.TorrentListBox list_box;

    private Gtk.SearchEntry search_entry;

    private SimpleActionGroup actions = new SimpleActionGroup ();

    public TorrentManager torrent_manager;
    private FileMonitor download_monitor;

    private const string ACTION_GROUP_PREFIX_NAME = "tor";
    private const string ACTION_GROUP_PREFIX = ACTION_GROUP_PREFIX_NAME + ".";

    private const string ACTION_FILTER = "action-filter";
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

        var filter_action = new SimpleAction.stateful (ACTION_FILTER, new VariantType ("y"), new Variant.byte (Widgets.TorrentListBox.FilterType.ALL));
        filter_action.activate.connect ((parameter) => {
            var filter_type = (Widgets.TorrentListBox.FilterType) parameter.get_byte ();
            list_box.filter (filter_type, null);

            filter_action.set_state (parameter);
        });
        actions.add_action (filter_action);

        infobar = new Widgets.MultiInfoBar ();

        list_box = new Widgets.TorrentListBox (torrent_manager.get_torrents ());
        list_box.torrent_removed.connect ((torrent) => torrent_manager.remove_torrent (torrent));
        list_box.open_torrent.connect ((id) => torrent_manager.open_torrent (id));
        list_box.open_torrent_location.connect ((id) => torrent_manager.open_torrent_location (id));
        list_box.link_copied.connect (on_link_copied);

        var list_box_scroll = new Gtk.ScrolledWindow () {
            child = list_box
        };

        var welcome_screen = new Granite.Placeholder (_("No Torrents Added")) {
            description = _("Add a torrent file to begin downloading.")
        };

        var open_button = welcome_screen.append_button (
            new ThemedIcon ("folder"),
            _("Open Torrent"),
            _("Open a torrent file from your computer.")
        );
        open_button.action_name = ACTION_GROUP_PREFIX + ACTION_OPEN;

        var preferences_button = welcome_screen.append_button (
            new ThemedIcon ("open-menu"),
            _("Preferences"),
            _("Set download folder and other preferences.")
        );
        preferences_button.action_name = ACTION_GROUP_PREFIX + ACTION_PREFERENCES;

        var no_results_alertview = new Granite.Placeholder (_("No Search Results")) {
            description = _("Try changing search terms"),
            icon = new ThemedIcon ("edit-find-symbolic")
        };

        var empty_category_alertview = new Granite.Placeholder (_("No Torrents Here")) {
            description = _("Try a different category"),
            icon = new ThemedIcon ("edit-find-symbolic")
        };

        stack = new Gtk.Stack ();
        stack.add_named (welcome_screen, "welcome");
        stack.add_named (list_box_scroll, "main");
        stack.add_named (no_results_alertview, "no_results");
        stack.add_named (empty_category_alertview, "empty_category");
        stack.visible_child_name = "welcome";

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.append (infobar);
        box.append (stack);

        toast = new Granite.Toast ("");

        var overlay = new Gtk.Overlay ();
        overlay.add_overlay (box);
        overlay.add_overlay (toast);

        child = overlay;

        set_titlebar (build_headerbar ());

        var torrents = torrent_manager.get_torrents ();
        if (torrents.size > 0) {
            enable_main_view ();
            update_category_totals (torrents);
        }

        torrent_manager.torrent_completed.connect ((torrent) => {
            var focused = application.get_active_window ().is_active;
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
            var focused = application.get_active_window ().is_active;
            if (!focused && list_box.has_visible_children ()) {
                Granite.Services.Application.set_progress_visible.begin (true);
            } else {
                Granite.Services.Application.set_progress_visible.begin (false);
            }
            return true;
        });

        close_request.connect (() => {
            var settings = new GLib.Settings ("com.github.davidmhewitt.torrential.settings");
            if (!quitting && settings.get_boolean ("hide-on-close") && torrent_manager.has_active_torrents ()) {
                return hide_on_close;
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
            ((SimpleAction) actions.lookup_action (ACTION_FILTER)).set_enabled (false);
            stack.visible_child_name = "welcome";
        }
    }

    private Gtk.Widget build_headerbar () {
        var headerbar = new Gtk.HeaderBar () {
            show_title_buttons = true
        };

        var menu = new Menu ();
        menu.append (_("_Preferences"), ACTION_GROUP_PREFIX + ACTION_PREFERENCES);
        menu.append (_("_Quit"), ACTION_GROUP_PREFIX + ACTION_QUIT);

        var menu_button = new Gtk.MenuButton () {
            icon_name = "open-menu",
            menu_model = menu,
            primary = true,
            tooltip_text = _("Application menu")
        };
        menu_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);
        headerbar.pack_end (menu_button);

        var open_button = new Gtk.Button.from_icon_name ("document-open") {
            action_name = ACTION_GROUP_PREFIX + ACTION_OPEN,
            tooltip_text = _("Open .torrent file")
        };
        open_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);
        headerbar.pack_start (open_button);

        magnet_button = new Gtk.Button.from_icon_name ("open-magnet") {
            action_name = ACTION_GROUP_PREFIX + ACTION_OPEN_MAGNET,
            tooltip_text = _("Open magnet link")
        };
        magnet_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);
        headerbar.pack_start (magnet_button);

        search_entry = new Gtk.SearchEntry () {
            hexpand = true,
            placeholder_text = _("Search Torrents"),
            sensitive = false,
            valign = Gtk.Align.CENTER
        };

        search_entry.search_changed.connect (() => {
            update_view ();
        });

        var view_mode_model = new Menu ();
        view_mode_model.append (_("All"), Action.print_detailed_name (
            ACTION_GROUP_PREFIX + ACTION_FILTER, new Variant.byte (Widgets.TorrentListBox.FilterType.ALL))
        );
        view_mode_model.append (_("Downloading"), Action.print_detailed_name (
            ACTION_GROUP_PREFIX + ACTION_FILTER, new Variant.byte (Widgets.TorrentListBox.FilterType.DOWNLOADING))
        );
        view_mode_model.append (_("Seeding"), Action.print_detailed_name (
            ACTION_GROUP_PREFIX + ACTION_FILTER, new Variant.byte (Widgets.TorrentListBox.FilterType.SEEDING))
        );
        view_mode_model.append (_("Paused"), Action.print_detailed_name (
            ACTION_GROUP_PREFIX + ACTION_FILTER, new Variant.byte (Widgets.TorrentListBox.FilterType.PAUSED))
        );

        var view_mode_button = new Gtk.MenuButton () {
            icon_name = "filter",
            menu_model = view_mode_model,
            tooltip_text = _("Filter")
        };
        view_mode_button.add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);

        headerbar.pack_end (view_mode_button);

        headerbar.title_widget = search_entry;

        var window_handle = new Gtk.WindowHandle () {
            child = headerbar
        };

        return window_handle;
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

        if (!list_box.has_visible_children ()) {
            stack.visible_child_name = "empty_category";
        } else {
            stack.visible_child_name = "main";
        }
    }

    private void enable_main_view () {
        search_entry.sensitive = true;
        ((SimpleAction) actions.lookup_action (ACTION_FILTER)).set_enabled (true);
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
        prefs_window.present ();
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
                add_files (filech.get_files ());
            }
        });
    }

    private void on_open_magnet () {
        var entry = new Gtk.Entry ();

        var clipboard = Gdk.Display.get_default ().get_clipboard ();

        try {
            var contents = clipboard.get_content ();
            if (contents != null) {
                var value = Value (typeof (string));
                contents.get_value (ref value);

                string? value_string = value.get_string ();
                if (value_string!= null && value_string.has_prefix ("magnet:")) {
                    entry.text = value_string;
                }
            }
        } catch (Error e) {
            critical (e.message);
        }

        var label = new Gtk.Label (_("Magnet URL:")) {
            halign = Gtk.Align.START
        };

        var add_button = new Gtk.Button.with_label (_("Add Magnet Link")) {
            sensitive = entry.text.strip () != ""
        };

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 3) {
            margin_top = 6,
            margin_end = 6,
            margin_bottom = 6,
            margin_start = 6
        };
        content_box.append (label);
        content_box.append (entry);
        content_box.append (add_button);

        var popover = new Gtk.Popover () {
            child = content_box
        };
        popover.set_parent (magnet_button);
        popover.popup ();

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
    }

    private void on_download_folder_changed (File file, File? other_file, FileMonitorEvent event) {
        if (event == FileMonitorEvent.CREATED) {
            if (ContentType.guess (file.get_basename (), null, null) == "application/x-bittorrent") {
                add_monitored_file (file.get_path ());
            }
        }
    }

    private void add_monitored_file (string path) {
        var focused = application.get_active_window ().is_active;

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

    public void add_files (ListModel files) {
        var errors = new Gee.ArrayList<string> ();
        for (int i = 0; i < files.get_n_items (); i++) {
            var file = (File) files.get_item (i);
            Torrent? new_torrent;
            var result = torrent_manager.add_torrent_by_path (file.get_path (), out new_torrent);
            if (result == Transmission.ParseResult.OK) {
                list_box.add_torrent (new_torrent);
            } else if (result == Transmission.ParseResult.ERR) {
                errors.add (_("Failed to add \u201C%s\u201D as it doesn\u2019t appear to be a valid torrent.").printf (file.get_basename ()));
            } else {
                errors.add (_("Didn\u2019t add \u201C%s\u201D. An identical torrent has already been added.").printf (file.get_basename ()));
            }
        }

        if (files.get_n_items () - errors.size > 0) {
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
            var focused = application.get_active_window ().is_active;
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
        var focused = application.get_active_window ().is_active;
        if (!focused) {
            var notification = new Notification (_("Magnet Link"));
            notification.set_body (_("Failed to add magnet link"));
            notification.set_default_action ("app." + ACTION_SHOW_WINDOW);
            application.send_notification ("app.magnet-added", notification);
        }
    }
}
