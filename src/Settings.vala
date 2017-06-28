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

public class Torrential.Settings : Granite.Services.Settings {
    public enum WindowState {
        NORMAL,
        MAXIMIZED
    }

    public int window_width { get; set; }
    public int window_height { get; set; }
    public WindowState window_state { get; set; }

    public string download_folder { get; set; }
    public bool hide_on_close { get; set; }
    public int max_downloads { get; set; }
    public int download_speed_limit { get; set; }
    public int upload_speed_limit { get; set; }
    public int peer_port { get; set; }
    public bool randomize_port { get; set; }
    public bool force_encryption { get; set; }
    public string blocklist_url { get; set; }
    public int64 blocklist_updated_timestamp { get; set; }
    public bool seed_ratio_enabled { get; set; }
    public double seed_ratio { get; set; }

    private static Settings _settings;
    public static unowned Settings get_default () {
        if (_settings == null) {
            _settings = new Settings ();
        }
        return _settings;
    }

    private Settings ()  {
        base ("com.github.davidmhewitt.torrential.settings");

        if (download_folder == "") {
            download_folder = Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD);
        } else {
            var download_folder_file = File.new_for_path (download_folder);
            if (!download_folder_file.query_exists ()) {
                download_folder = Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD);
            }
        }
    }
}

