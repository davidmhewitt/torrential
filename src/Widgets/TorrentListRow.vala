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

public class Torrential.Widgets.TorrentListRow : Gtk.ListBoxRow {
    private Torrent torrent;
    private Gtk.ProgressBar progress;
    private Gtk.Label completeness;
    private Gtk.Label status;
    private Gtk.Label torrent_name;
    private Gtk.Button pause_button;

    private Gtk.CssProvider green_progress_provider;

    private const string PAUSE_ICON_NAME = "media-playback-pause-symbolic";
    private const string RESUME_ICON_NAME = "media-playback-start-symbolic";

    public signal void torrent_removed (Torrent torrent);

    public bool multi_file_torrent {
        get {
            return torrent.file_count > 1;
        }
    }

    public TorrentListRow (Torrent torrent) {
        this.torrent = torrent;

        green_progress_provider = new Gtk.CssProvider ();
        try {
            green_progress_provider.load_from_data ("@define-color accent_color @LIME_300;".data);
        } catch (Error e) {
            warning ("Failed to load custom CSS to make green progress bars. Error: %s", e.message);
        }

        Icon icon;
        if (torrent.file_count > 1) {
            icon = ContentType.get_icon ("inode/directory");
        } else {
            var files = torrent.files;
            if (files != null && files.length > 0) {
                bool certain = false;
                var content_type = ContentType.guess (files[0].name, null, out certain);
                icon = ContentType.get_icon (content_type);
            } else {
                icon = ContentType.get_icon ("application/x-bittorrent");
            }
        }
        var icon_image = new Gtk.Image.from_gicon (icon) {
            icon_size = Gtk.IconSize.LARGE
        };

        torrent_name = new Gtk.Label (torrent.name) {
            halign = Gtk.Align.START,
            ellipsize = Pango.EllipsizeMode.END
        };
        torrent_name.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        completeness = new Gtk.Label (generate_completeness_text ()) {
            halign = Gtk.Align.START
        };
        completeness.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        progress = new Gtk.ProgressBar () {
            hexpand = true
        };

        progress.fraction = torrent.progress;
        if (torrent.seeding) {
            progress.get_style_context ().add_provider (green_progress_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        }

        if (!torrent.paused) {
            pause_button = new Gtk.Button.from_icon_name (PAUSE_ICON_NAME) {
                tooltip_text = _("Pause torrent")
            };
        } else {
            pause_button = new Gtk.Button.from_icon_name (RESUME_ICON_NAME) {
                tooltip_text = _("Resume torrent")
            };
        }

        pause_button.add_css_class (Granite.STYLE_CLASS_FLAT);
        pause_button.clicked.connect (() => {
            toggle_pause ();
        });

        status = new Gtk.Label (generate_status_text ()) {
            halign = Gtk.Align.START
        };
        status.add_css_class (Granite.STYLE_CLASS_SMALL_LABEL);

        var grid = new Gtk.Grid () {
            column_spacing = 12,
            row_spacing = 3,
            margin_top = 6,
            margin_end = 12,
            margin_bottom = 6,
            margin_start = 12
        };
        grid.attach (icon_image, 0, 0, 1, 4);
        grid.attach (torrent_name, 1, 0);
        grid.attach (completeness, 1, 1);
        grid.attach (progress, 1, 2);
        grid.attach (status, 1, 3);
        grid.attach (pause_button, 2, 1, 1, 4);

        child = grid;
    }

    public void update () {
        torrent_name.label = torrent.name;
        progress.fraction = torrent.progress;
        completeness.label = generate_completeness_text ();
        status.label = generate_status_text ();
        pause_button.icon_name = torrent.paused ? RESUME_ICON_NAME : PAUSE_ICON_NAME;

        if (torrent.seeding) {
            progress.get_style_context ().add_provider (green_progress_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER);
        } else {
            progress.get_style_context ().remove_provider (green_progress_provider);
        }
    }

    public void edit_files () {
        var dialog = new Dialogs.FileSelectDialog (torrent);
        dialog.run ();
        dialog.destroy ();
    }

    private string generate_completeness_text () {
        if (!torrent.has_metadata) {
            return _("Trying to find metadata for magnet link");
        } else if (torrent.downloading) {
            return _("%s of %s — %s remaining").printf (format_size (torrent.bytes_downloaded), format_size (torrent.bytes_total), time_to_string (torrent.seconds_remaining));
        } else if (torrent.paused || torrent.waiting) {
            return _("%s of %s").printf (format_size (torrent.bytes_downloaded), format_size (torrent.bytes_total));
        } else if (torrent.seeding) {
            return _("%s uploaded").printf (format_size (torrent.bytes_uploaded));
        } else {
            return "";
        }
    }

    private string generate_status_text () {
        if (torrent.downloading || torrent.seeding) {
            char[] buf = new char[40];
            var down_speed = Transmission.String.Units.speed_KBps (buf, torrent.download_speed);
            var up_speed = Transmission.String.Units.speed_KBps (buf, torrent.upload_speed);
            return _("%i of %i peers connected. \u2b07%s \u2b06%s").printf (torrent.connected_peers, torrent.total_peers, down_speed, up_speed);
        } else if (torrent.paused) {
            return _("Paused");
        } else if (torrent.waiting) {
            return _("Waiting in queue");
        } else if (torrent.checking) {
            return _("Checking");
        } else {
            return "";
        }
    }

    public static string time_to_string (int totalSeconds) {
        if (totalSeconds < 0) {
            return "...";
        }

        uint seconds = (totalSeconds % 60);
        uint minutes = (totalSeconds % 3600) / 60;
        uint hours = (totalSeconds % 86400) / 3600;
        uint days = (totalSeconds % (86400 * 30)) / 86400;

        var str_days = ngettext ("%u day", "%u days", days).printf (days);
        var str_hours = ngettext ("%u hour", "%u hours", hours).printf (hours);
        var str_minutes = ngettext ("%u minute", "%u minutes", minutes).printf (minutes);
        var str_seconds = ngettext ("%u second", "%u seconds", seconds).printf (seconds);

        var formatted = "";
        if (days > 0) {
            formatted = "%s, %s, %s, %s".printf (str_days, str_hours, str_minutes, str_seconds);
        }
        else if (hours > 0) {
            formatted = "%s, %s, %s".printf (str_hours, str_minutes, str_seconds);
        }
        else if (minutes > 0) {
            formatted = "%s, %s".printf (str_minutes, str_seconds);
        }
        else if (seconds > 0) {
            formatted = str_seconds;
        }
        return formatted;
    }

    private void toggle_pause () {
        if (!torrent.paused) {
            pause_torrent ();
        } else {
            resume_torrent ();
        }
    }

    public void remove_torrent () {
        torrent_removed (torrent);
        destroy ();
    }

    public void pause_torrent () {
        torrent.pause ();
        pause_button.icon_name = RESUME_ICON_NAME;
        pause_button.tooltip_text = _("Resume torrent");
    }

    public void resume_torrent () {
        torrent.unpause ();
        pause_button.icon_name = PAUSE_ICON_NAME;
        pause_button.tooltip_text = _("Pause torrent");
    }

    public void copy_magnet_link () {
        var link = torrent.magnet_link;
        var clipboard = Gtk.Clipboard.get_for_display (get_display (), Gdk.SELECTION_CLIPBOARD);
        clipboard.set_text (link, -1);
    }

    public bool downloading { get { return torrent.downloading; } }
    public bool seeding { get { return torrent.seeding; } }
    public bool paused { get { return torrent.paused; } }
    public string display_name { get { return torrent.name; } }
    public DateTime date_added { owned get { return torrent.date_added; } }
    public int id { get { return torrent.id; } }
    public bool has_metadata { get { return torrent.has_metadata; } }
}
