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

[DBus (name = "org.freedesktop.FileManager1")]
interface DBus.Files : Object {
    public abstract void show_items (string[] uris, string startup_id) throws IOError;
    public abstract void show_folders (string[] uris, string startup_id) throws IOError;
}

const string FILES_DBUS_ID = "org.freedesktop.FileManager1";
const string FILES_DBUS_PATH = "/org/freedesktop/FileManager1";

public class Torrential.TorrentManager : Object {
    private Transmission.variant_dict settings;
    private Transmission.Session session;
    private Transmission.TorrentConstructor torrent_constructor;
    private Gee.ArrayList <unowned Transmission.Torrent> added_torrents = new Gee.ArrayList <unowned Transmission.Torrent> ();

    public signal void torrent_completed (Torrent torrent);

    private static string CONFIG_DIR = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_config_dir (), "torrential");

    public TorrentManager () {
        Transmission.String.Units.mem_init (1024, _("KB"), _("MB"), _("GB"), _("TB"));
        Transmission.String.Units.speed_init (1024, _("KB/s"), _("MB/s"), _("GB/s"), _("TB/s"));
        settings = Transmission.variant_dict (0);
        Transmission.load_default_settings (ref settings, CONFIG_DIR, "torrential");

        session = new Transmission.Session (CONFIG_DIR, false, settings);
        torrent_constructor = new Transmission.TorrentConstructor (session);
        unowned Transmission.Torrent[] transmission_torrents = session.load_torrents (torrent_constructor);
        for (int i = 0; i < transmission_torrents.length; i++) {
            transmission_torrents[i].set_completeness_callback (on_completeness_changed); 
            added_torrents.add (transmission_torrents[i]);
        }
    }

    ~TorrentManager () {
        session.save_settings (CONFIG_DIR, settings);
    }

    public Gee.ArrayList<Torrent> get_torrents () {
        Gee.ArrayList<Torrent> torrents = new Gee.ArrayList<Torrent> ();
        foreach (unowned Transmission.Torrent torrent in added_torrents) {
            torrents.add (new Torrent (torrent));
        }
        return torrents;
    }

    public Transmission.ParseResult add_torrent_by_path (string path, out Torrent? created_torrent) {
        torrent_constructor = new Transmission.TorrentConstructor (session);
        torrent_constructor.set_metainfo_from_file (path);
        // TODO: Set path from settings
        torrent_constructor.set_download_dir (Transmission.ConstructionMode.FORCE, "/home/david/Downloads");
        
        Transmission.ParseResult result;
        int duplicate_id;
        unowned Transmission.Torrent torrent = torrent_constructor.instantiate (out result, out duplicate_id);
        if (result == Transmission.ParseResult.OK) {
            torrent.set_completeness_callback (on_completeness_changed);
            created_torrent = new Torrent (torrent);
            added_torrents.add (torrent);
        } else {
            created_torrent = null;
        }

        return result;
    }

    public Transmission.ParseResult add_torrent_by_magnet (string magnet, out Torrent? created_torrent) {
        warning ("parsing magnet: %s", magnet);
        torrent_constructor = new Transmission.TorrentConstructor (session);
        torrent_constructor.set_metainfo_from_magnet_link (magnet);
        // TODO: Set path from settings
        torrent_constructor.set_download_dir (Transmission.ConstructionMode.FORCE, "/home/david/Downloads");

        Transmission.ParseResult result;
        int duplicate_id;
        unowned Transmission.Torrent torrent = torrent_constructor.instantiate (out result, out duplicate_id);
        if (result == Transmission.ParseResult.OK) {
            torrent.set_completeness_callback (on_completeness_changed);
            created_torrent = new Torrent (torrent);
            added_torrents.add (torrent);
        } else {
            created_torrent = null;
        }

        return result;
    }

    public void remove_torrent (Torrent to_remove) {
        foreach (unowned Transmission.Torrent torrent in added_torrents) {
            if (torrent.id == to_remove.id) {
                added_torrents.remove (torrent);
                break;
            }
        }
        to_remove.remove ();
    }

    private void on_completeness_changed (Transmission.Torrent torrent, Transmission.Completeness completeness, bool wasRunning) {
        if (wasRunning && completeness != Transmission.Completeness.LEECH) {
            torrent_completed (new Torrent (torrent));
        }
    }

    public void open_torrent_location (int torrent_id) {
        foreach (unowned Transmission.Torrent torrent in added_torrents) {
            if (torrent.id == torrent_id) {
                DBus.Files files = Bus.get_proxy_sync (BusType.SESSION, FILES_DBUS_ID, FILES_DBUS_PATH);
                var path = Path.build_path (Path.DIR_SEPARATOR_S, torrent.download_dir, new Torrent (torrent).files[0].name);
                var file = File.new_for_path (path);
                if (file.query_exists ()) {
                    files.show_items ({ path }, "torrential");
                } else {
                    path += ".part";
                    file = file.new_for_path (path);
                    if (file.query_exists ()) {
                        files.show_items ({ path }, "torrential");
                    } else {
                        path = path.substring (0, path.last_index_of ("/"));
                        files.show_folders ({ path }, "torrential");
                    }
                }
                break;
            }
        }
    }
}
