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

    construct {
        flags |= ApplicationFlags.HANDLES_OPEN;
        flags |= ApplicationFlags.HANDLES_COMMAND_LINE;

        application_id = "com.github.davidmhewitt.torrential";
        var app_launcher = application_id + ".desktop";

        if (AppInfo.get_default_for_uri_scheme ("magnet") == null) {
            var appinfo = new DesktopAppInfo (app_launcher);
            try {
                appinfo.set_as_default_for_type ("x-scheme-handler/magnet");
            } catch (Error e) {
                warning ("Unable to set self as default for magnet links: %s", e.message);
            }
        }

        if (AppInfo.get_default_for_type ("application/x-bittorrent", false) == null) {
            var appinfo = new DesktopAppInfo (app_launcher);
            try {
                appinfo.set_as_default_for_type ("application/x-bittorrent");
            } catch (Error e) {
                warning ("Unable to set self as default for torrent files: %s", e.message);
            }
        }
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
            window = new MainWindow (this);
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

    public override int command_line (ApplicationCommandLine cmd_line) {
        bool quit = false;

        OptionEntry[] options = new OptionEntry[1];
        options[0] = { "quit", 0, 0, OptionArg.NONE, ref quit, "Quit running instance", null };

        // We have to make an extra copy of the array, since .parse assumes
        // that it can remove strings from the array without freeing them.
        string[] args = cmd_line.get_arguments ();
        string*[] _args = new string[args.length];
        for (int i = 0; i < args.length; i++) {
            _args[i] = args[i];
        }

        unowned string[] tmp = _args;

        try {
            var opt_context = new OptionContext ("- Torrential");
            opt_context.set_help_enabled (true);
            opt_context.add_main_entries (options, null);
            opt_context.set_ignore_unknown_options (true);
            opt_context.parse (ref tmp);
        } catch (OptionError e) {
            cmd_line.print ("error: %s\n", e.message);
            cmd_line.print ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
            return 0;
        }

        if (quit) {
            if (window != null) {
                window.quit ();
            }
        }

        File[] files = {};
        for (int i = 1; i < tmp.length; i++) {
            files += File.new_for_commandline_arg (tmp[i]);
        }

        if (files.length > 0) {
            open (files, "");
            return 0;
        }

        activate ();
        return 0;
    }

    public void wait_for_close () {
        if (window != null) {
            window.wait_for_close ();
        }
    }
}

int main (string[] args) {
    var app = new Torrential.Application ();
    var ret_val = app.run (args);
    app.wait_for_close ();

    return ret_val;
}
