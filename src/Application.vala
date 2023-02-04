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

public class Torrential.Application : Gtk.Application {
    private TorrentManager torrent_manager = null;

    const OptionEntry[] ENTRIES = {
        { "quit", 0, 0, OptionArg.NONE, null, N_("Quit running instance"), null },
        { GLib.OPTION_REMAINING, 0, 0, OptionArg.FILENAME_ARRAY, null, null, N_("[FILE…]") },
        { null }
    };

    construct {
        flags |= ApplicationFlags.HANDLES_OPEN;
        flags |= ApplicationFlags.HANDLES_COMMAND_LINE;

        application_id = "com.github.davidmhewitt.torrential";

        add_main_option_entries (ENTRIES);

        torrent_manager = new TorrentManager ();
    }

    public override void startup () {
        base.startup ();

        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        Gtk.IconTheme.get_for_display (Gdk.Display.get_default ()).add_resource_path ("/com/github/davidmhewitt/torrential");

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });
    }

    public override void open (File[] files, string hint) {
        if (files[0].has_uri_scheme ("magnet")) {
            var magnet = files[0].get_uri ();
            magnet = magnet.replace ("magnet:///?", "magnet:?");

            activate ();
            ((MainWindow) active_window).add_magnet (magnet);
            return;
        }

        var file_list = new SList<File> ();
        foreach (unowned var file in files) {
            file_list.append (file);
        }

        activate ();
        ((MainWindow) active_window).add_files (file_list);
    }

    public override void activate () {
        if (active_window == null) {
            var window = new MainWindow (this, torrent_manager);
            add_window (window);

            /*
            * This is very finicky. Bind size after present else set_titlebar gives us bad sizes
            * Set maximize after height/width else window is min size on unmaximize
            * Bind maximize as SET else get get bad sizes
            */
            var settings = new Settings ("com.github.davidmhewitt.torrential.settings");
            settings.bind ("window-height", window, "default-height", SettingsBindFlags.DEFAULT);
            settings.bind ("window-width", window, "default-width", SettingsBindFlags.DEFAULT);

            if (settings.get_boolean ("window-maximized")) {
                window.maximize ();
            }

            settings.bind ("window-maximized", window, "maximized", SettingsBindFlags.SET);
        }

        active_window.present ();
    }

    public override int command_line (GLib.ApplicationCommandLine command_line) {
        var options = command_line.get_options_dict ();

        if (options.contains ("quit")) {
            if (active_window != null) {
                ((MainWindow) active_window).quit ();
                return Posix.EXIT_SUCCESS;
            }
        }

        activate ();

        if (options.contains (GLib.OPTION_REMAINING)) {
            File[] files = {};

            (unowned string)[] remaining = options.lookup_value (
                GLib.OPTION_REMAINING,
                VariantType.BYTESTRING_ARRAY
            ).get_bytestring_array ();

            for (int i = 0; i < remaining.length; i++) {
                unowned string file = remaining[i];
                files += command_line.create_file_for_arg (file);
            }

            open (files, "");
        }

        return Posix.EXIT_SUCCESS;
    }

    private void close_session () {
        torrent_manager.close_session ();
    }

    public static int main (string[] args) {
        var app = new Torrential.Application ();
        var result = app.run (args);

        app.close_session ();

        return result;
    }
}
