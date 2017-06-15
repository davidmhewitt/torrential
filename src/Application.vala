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

public class Torrential.Application : Granite.Application {
    private static Torrential.Application? _instance = null;
    private TorrentManager torrent_manager = TorrentManager.get_default ();

    construct {
        application_id = "com.github.davidmhewitt.torrential";
        flags = ApplicationFlags.FLAGS_NONE;

        program_name = "Torrential";
        app_years = "2017";

        build_version = "0.1";
        //app_icon = "applications-interfacedesign";
        main_url = "https://github.com/davidmhewitt/torrential";
        bug_url = "https://github.com/davidmhewitt/torrential/issues";
        help_url = "https://github.com/davidmhewitt/torrential/issues";
        //translate_url = "https://l10n.elementary.io/projects/desktop/granite";

        about_documenters = { null };
        about_artists = { null };
        about_authors = {
            "David Hewitt <davidmhewitt@gmail.com>",
        };

        about_comments = "A simple torrent client";
        about_translators = _("translator-credits");
        about_license_type = Gtk.License.GPL_2_0;
    }

    public override void activate () {
        var window = new MainWindow ();
        add_window (window);
    }

    public static new Torrential.Application get_default () {
        if (_instance == null) {
            _instance = new Torrential.Application ();
        }
        return _instance;
    }
}

int main (string[] args) {
    var app = Torrential.Application.get_default ();
    return app.run (args);
}
