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

    private uint refresh_timer;

    private Gtk.Menu app_menu = new Gtk.Menu();
    private Gtk.MenuItem preferences_item;
    private Gtk.MenuItem about_item;

    private Gtk.Stack stack;
    private Gtk.HeaderBar headerbar;
    private Gtk.Paned main_pane;
    private Granite.Widgets.Welcome welcome_screen;
    private Widgets.MultiInfoBar infobar;
    private Widgets.TorrentListBox list_box;

    private Granite.Widgets.SourceList.Item all_category;
    private Granite.Widgets.SourceList.Item downloading_category;
    private Granite.Widgets.SourceList.Item seeding_category;
    private Granite.Widgets.SourceList.Item paused_category;
    private Granite.Widgets.SourceList.Item search_category;

    private Gtk.SearchEntry search_entry;

    private SimpleActionGroup actions = new SimpleActionGroup ();
    
    private TorrentManager torrent_manager;

    private const string ACTION_GROUP_PREFIX_NAME = "tor";
    private static string ACTION_GROUP_PREFIX = ACTION_GROUP_PREFIX_NAME + ".";

    private const string ACTION_PREFERENCES = "undo";
    private const string ACTION_ABOUT = "redo";
    private const string ACTION_QUIT = "quit";
    private const string ACTION_OPEN = "open";

    private const ActionEntry[] action_entries = {
        {ACTION_PREFERENCES,                on_preferences          },
        {ACTION_ABOUT,                      on_about                },
        {ACTION_QUIT,                       on_quit                 },
        {ACTION_OPEN,                       on_open                 }
    };

    public static Gee.MultiMap<string, string> action_accelerators = new Gee.HashMultiMap<string, string> ();
    static construct {
        action_accelerators.set (ACTION_PREFERENCES, "<Ctrl>comma");
        action_accelerators.set (ACTION_QUIT, "<Ctrl>q");
        action_accelerators.set (ACTION_OPEN, "<Ctrl>o");
    }

    public MainWindow (Application app) {
        actions.add_action_entries (action_entries, this);
        insert_action_group (ACTION_GROUP_PREFIX_NAME, actions);
        foreach (var action in action_accelerators.get_keys ()) {
            app.set_accels_for_action (ACTION_GROUP_PREFIX + action,
                                       action_accelerators[action].to_array ());
        }

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

        set_default_size (900, 600);
        set_titlebar (headerbar);
        show_all ();

        var torrents = torrent_manager.get_torrents ();
        if (torrents.size > 0) {
            enable_main_view ();
            update_category_totals (torrents);
        }

        refresh_timer = Timeout.add_seconds (1, () => {
            list_box.update ();
            update_category_totals (torrent_manager.get_torrents ());
            return true;
        });

        delete_event.connect (() => {
            Source.remove (refresh_timer);
            return false;
        });
    }

    private void update_category_totals (Gee.ArrayList<Torrent> torrents) {
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
    }

    private void build_main_interface () {
        all_category = new Granite.Widgets.SourceList.Item (_("All"));
        all_category.icon = Icon.new_for_string ("folder");
        all_category.badge = "0";
        downloading_category = new Granite.Widgets.SourceList.Item (_("Downloading"));
        downloading_category.icon = Icon.new_for_string ("go-down");
        downloading_category.badge = "0";
        seeding_category = new Granite.Widgets.SourceList.Item (_("Seeding"));
        seeding_category.icon = Icon.new_for_string ("go-up");
        seeding_category.badge = "0";
        paused_category = new Granite.Widgets.SourceList.Item (_("Paused"));
        paused_category.icon = Icon.new_for_string ("media-playback-pause");
        paused_category.badge = "0";
        search_category = new Granite.Widgets.SourceList.Item (_("Search Results"));
        search_category.icon = Icon.new_for_string ("edit-find");
        search_category.badge = "0";
        search_category.visible = false;

        var sidebar = new Granite.Widgets.SourceList ();
        var root = sidebar.root;
        root.add (all_category);
        root.add (downloading_category);
        root.add (seeding_category);
        root.add (paused_category);
        root.add (search_category);

        main_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
        main_pane.position = 175;

        main_pane.add1 (sidebar);
        list_box = new Widgets.TorrentListBox (torrent_manager.get_torrents ());
        main_pane.add2 (list_box);
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
        preferences_item = new Gtk.MenuItem.with_mnemonic (_("_Preferences"));
        preferences_item.set_action_name (ACTION_GROUP_PREFIX + ACTION_PREFERENCES);
        app_menu.append (preferences_item);

        about_item = new Gtk.MenuItem.with_mnemonic (_("_About"));
        about_item.set_action_name (ACTION_GROUP_PREFIX + ACTION_ABOUT);
        app_menu.append (about_item);

        app_menu.show_all ();

        return app_menu;
    }

    private void on_preferences (SimpleAction action) {
        var prefs_window = new PreferencesWindow (this);
        prefs_window.show_all ();
    }

    private void on_about (SimpleAction action) {
        show_about (this);
    }

    private void on_quit (SimpleAction action) {
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
            var uris = filech.get_uris ();
            Gee.ArrayQueue<string> errors = new Gee.ArrayQueue<string> ();
            foreach (string uri in filech.get_uris ()) {
                var path = Filename.from_uri (uri);
                Torrent? new_torrent;
                var result = torrent_manager.add_torrent_by_path (path, out new_torrent);
                if (result == Transmission.ParseResult.OK) {
                    list_box.add_torrent (new_torrent);
                } else if (result == Transmission.ParseResult.ERR) {
                    var basename = Filename.display_basename (path);
                    errors.offer (_("Failed to add \u201C%s\u201D as it doesn\u2019t appear to be a valid torrent.").printf (basename));
                } else {
                    var basename = Filename.display_basename (path);
                    errors.offer (_("Didn\u2019t add \u201C%s\u201D. An identical torrent has already been added.").printf (basename));
                }
            }
            if (uris.length () - errors.size > 0) {
                enable_main_view ();
            }
            if (errors.size > 0) {
                infobar.set_errors (errors);
                infobar.show ();
            }
        }

        filech.close ();
    }
}
