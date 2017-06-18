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
    private Gtk.Label status;

    public TorrentListRow (Torrent torrent) {
        this.torrent = torrent;

        var grid = new Gtk.Grid ();
        grid.margin = 12;
        grid.column_spacing = 8;

        add (grid);

        var icon = GLib.ContentType.get_icon ("application/x-bittorrent");
        var icon_image = new Gtk.Image.from_gicon (icon, Gtk.IconSize.DIALOG);
        grid.attach (icon_image, 0, 0, 1, 3);

        var name = new Gtk.Label (torrent.name);
        name.halign = Gtk.Align.START;
        grid.attach (name, 1, 0, 1, 1);

        progress = new Gtk.ProgressBar ();
        progress.hexpand = true;
        progress.fraction = torrent.progress;
        grid.attach (progress, 1, 1, 1, 1);

        status = new Gtk.Label (generate_status_text ());
        status.halign = Gtk.Align.START;
        grid.attach (status, 1, 2, 1, 1);
    }

    public void update () {
        progress.fraction = torrent.progress;
        status.label = generate_status_text ();
    }

    private string generate_status_text () {
        return time_to_string (torrent.secondsRemaining);
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

}
