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
    }

    public void wait_for_close () {
        window.wait_for_close ();
    }
}

int main (string[] args) {
    var app = new Torrential.Application ();
    var ret_val = app.run (args);
    app.wait_for_close ();

    return ret_val;
}
