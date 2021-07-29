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

public class Torrential.Application : Gtk.Application {
    private MainWindow? window = null;
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

    public override void open (File[] files, string hint) {
        if (files[0].has_uri_scheme ("magnet")) {
            var magnet = files[0].get_uri ();
            magnet = magnet.replace ("magnet:///?", "magnet:?");

            if (window != null) {
                window.add_magnet (magnet);
            } else {
                activate ();
                window.add_magnet (magnet);
            }
            return;
        }

        var uris = new SList<string> ();
        foreach (var file in files) {
            uris.append (file.get_uri ());
        }

        activate ();
        window.add_files (uris);
    }

    public override void activate () {
        if (window == null) {
            window = new MainWindow (this, torrent_manager);
            add_window (window);
        }

        window.present ();
        window.present_with_time (0);

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });
    }

    public override int command_line (GLib.ApplicationCommandLine command_line) {
        var options = command_line.get_options_dict ();

        if (options.contains ("quit")) {
            if (window != null) {
                window.quit ();
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

    public void close_session () {
        torrent_manager.close_session ();
    }
}

int main (string[] args) {
    var app = new Torrential.Application ();
    var result = app.run (args);

    app.close_session ();

    return result;
}
