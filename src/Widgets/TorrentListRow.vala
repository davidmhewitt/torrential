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

public class Torrential.Widgets.TorrentListRow : Gtk.ListBoxRow {
    private Torrent torrent;
    private Gtk.ProgressBar progress;
    private Gtk.Label completeness;
    private Gtk.Label status;
    private Gtk.Label torrent_name;
    private Gtk.Button pause_button;

    private const string PAUSE_ICON_NAME = "media-playback-pause";
    private const string RESUME_ICON_NAME = "media-playback-start";

    public signal void torrent_removed (Torrent torrent);

    public TorrentListRow (Torrent torrent) {
        this.torrent = torrent;

        var grid = new Gtk.Grid ();
        grid.margin = 12;
        grid.column_spacing = 8;

        add (grid);

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
        var icon_image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DIALOG);
        grid.attach (icon_image, 0, 0, 1, 4);

        torrent_name = new Gtk.Label (torrent.name);
        torrent_name.halign = Gtk.Align.START;
        torrent_name.get_style_context ().add_class ("h3");
        grid.attach (torrent_name, 1, 0, 1, 1);

        completeness = new Gtk.Label (generate_completeness_text ());
        completeness.halign = Gtk.Align.START;
        grid.attach (completeness, 1, 1, 1, 1);

        progress = new Gtk.ProgressBar ();
        progress.hexpand = true;
        progress.fraction = torrent.progress;
        grid.attach (progress, 1, 2, 1, 1);

        if (!torrent.paused) {
            pause_button = new Gtk.Button.from_icon_name (PAUSE_ICON_NAME);
        } else {
            pause_button = new Gtk.Button.from_icon_name (RESUME_ICON_NAME);
        }
        pause_button.get_style_context ().add_class ("flat");
        pause_button.clicked.connect (() => {
            if (!torrent.paused) {
                torrent.pause ();
                pause_button.set_image (new Gtk.Image.from_icon_name (RESUME_ICON_NAME, Gtk.IconSize.BUTTON));
            } else {
                torrent.unpause ();
                pause_button.set_image (new Gtk.Image.from_icon_name (PAUSE_ICON_NAME, Gtk.IconSize.BUTTON));
            }
        });
        grid.attach (pause_button, 2, 1, 1, 4);

        status = new Gtk.Label (generate_status_text ());
        status.halign = Gtk.Align.START;
        grid.attach (status, 1, 3, 1, 1);
        show_all ();
    }

    public void update () {
        torrent_name.label = torrent.name;
        progress.fraction = torrent.progress;
        completeness.label = generate_completeness_text ();
        status.label = generate_status_text ();
        pause_button.set_image (new Gtk.Image.from_icon_name (torrent.paused ? RESUME_ICON_NAME : PAUSE_ICON_NAME, Gtk.IconSize.BUTTON));
    }

    private string generate_completeness_text () {
        if (!torrent.paused) {
            return _("%s of %s - %s remaining").printf (format_size (torrent.bytes_downloaded), format_size (torrent.bytes_total), time_to_string (torrent.seconds_remaining));
        } else {
            return _("%s of %s").printf (format_size (torrent.bytes_downloaded), format_size (torrent.bytes_total));
        }
    }

    private string generate_status_text () {
        if (!torrent.paused) {
            char[40] buf = new char[40];
            var down_speed = Transmission.String.Units.speed_KBps (buf, torrent.download_speed);
            var up_speed = Transmission.String.Units.speed_KBps (buf, torrent.upload_speed);
            return _("%i of %i peers connected. \u2b07%s \u2b06%s").printf (torrent.connected_peers, torrent.total_peers, down_speed, up_speed);
        } else {
            return _("Paused");
        }
    }

    public static string time_to_string (uint totalSeconds) {
        uint seconds = (totalSeconds % 60);
        uint minutes = (totalSeconds % 3600) / 60;
        uint hours = (totalSeconds % 86400) / 3600;
        uint days = (totalSeconds % (86400 * 30)) / 86400;

        var str_days = ngettext ("%d day", "%d days", days).printf (days);
        var str_hours = ngettext ("%d hour", "%d hours", hours).printf (hours);
        var str_minutes = ngettext ("%d minute", "%d minutes", minutes).printf (minutes);
        var str_seconds = ngettext ("%d second", "%d seconds", seconds).printf (seconds);

        var formatted = "";
        if (days > 0) {
            formatted = "%s, %s, %s, %s".printf (str_days, str_hours, str_minutes, str_seconds);
            return formatted;
        }
        if (hours > 0) {
            formatted = "%s, %s, %s".printf (str_hours, str_minutes, str_seconds);
            return formatted;
        }
        if (minutes > 0) {
            formatted = "%s, %s".printf (str_minutes, str_seconds);
            return formatted;
        }
        if (seconds > 0) {
            formatted = str_seconds;
            return formatted;
        }
        return "";
    }

    public void remove_torrent () {
        torrent_removed (torrent);
        destroy ();
    }

    public bool downloading { get { return torrent.downloading; } }
    public bool seeding { get { return torrent.seeding; } }
    public bool paused { get { return torrent.paused; } }
    public string display_name { get { return torrent.name; } }
    public time_t date_added { get { return torrent.date_added; } }
    public int id { get { return torrent.id; } }
}
