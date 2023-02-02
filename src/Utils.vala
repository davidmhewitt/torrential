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

public class Torrential.Utils {
    public static string get_downloads_folder () {
        var settings = new GLib.Settings ("com.github.davidmhewitt.torrential.settings");
        var download_folder = settings.get_string ("download-folder");

        if (download_folder == "") {
            download_folder = Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD);
        } else {
            var download_folder_file = File.new_for_path (download_folder);
            if (!download_folder_file.query_exists ()) {
                download_folder = Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD);
            }
        }

        return download_folder;
    }
}

