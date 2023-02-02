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

[DBus (name = "org.freedesktop.FileManager1")]
interface DBus.Files : Object {
    public abstract void show_items (string[] uris, string startup_id) throws IOError, DBusError;
    public abstract void show_folders (string[] uris, string startup_id) throws IOError, DBusError;
}

const string FILES_DBUS_ID = "org.freedesktop.FileManager1";
const string FILES_DBUS_PATH = "/org/freedesktop/FileManager1";

public class Torrential.TorrentManager : Object {
    private Transmission.variant_dict variant_dict;
    private Transmission.Session session;
    private Transmission.TorrentConstructor torrent_constructor;
    private Gee.ArrayList <unowned Transmission.Torrent> added_torrents = new Gee.ArrayList <unowned Transmission.Torrent> ();
    private GLib.Settings settings;

    public signal void torrent_completed (Torrent torrent);

    private static string CONFIG_DIR = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_config_dir (), "torrential");

    construct {
        settings = new GLib.Settings ("com.github.davidmhewitt.torrential.settings");

        Transmission.String.Units.mem_init (1024, _("KB"), _("MB"), _("GB"), _("TB"));
        Transmission.String.Units.speed_init (1024, _("KB/s"), _("MB/s"), _("GB/s"), _("TB/s"));
        variant_dict = Transmission.variant_dict (0);
        Transmission.load_default_settings (ref variant_dict, CONFIG_DIR, "torrential");

        session = new Transmission.Session (CONFIG_DIR, false, variant_dict);

        torrent_constructor = new Transmission.TorrentConstructor (session);
        unowned Transmission.Torrent[] transmission_torrents = session.load_torrents (torrent_constructor);
        for (int i = 0; i < transmission_torrents.length; i++) {
            transmission_torrents[i].set_completeness_callback (on_completeness_changed);
            added_torrents.add (transmission_torrents[i]);
        }
    }

    public void close_session () {
        update_session_settings ();
        session.save_settings (CONFIG_DIR, variant_dict);
        session = null;
    }

    public bool has_active_torrents () {
        foreach (var torrent in get_torrents ()) {
            if (torrent.seeding || torrent.downloading || torrent.waiting) {
                return true;
            }
        }
        return false;
    }

    public void update_session_settings () {
        variant_dict.add_int (Transmission.Prefs.download_queue_size, settings.get_int ("max-downloads"));

        if (settings.get_int ("download-speed-limit") == 0) {
            variant_dict.add_bool (Transmission.Prefs.speed_limit_down_enabled, false);
        } else {
            variant_dict.add_bool (Transmission.Prefs.speed_limit_down_enabled, true);
            variant_dict.add_int (Transmission.Prefs.speed_limit_down, settings.get_int ("download-speed-limit"));
        }

        if (settings.get_int ("upload-speed-limit") == 0) {
            variant_dict.add_bool (Transmission.Prefs.speed_limit_up_enabled, false);
        } else {
            variant_dict.add_bool (Transmission.Prefs.speed_limit_up_enabled, true);
            variant_dict.add_int (Transmission.Prefs.speed_limit_up, settings.get_int ("upload-speed-limit"));
        }

        variant_dict.add_bool (Transmission.Prefs.peer_port_random_on_start, settings.get_boolean ("randomize-port"));
        if (settings.get_boolean ("randomize-port")) {
            int64 port = 0;
            if (variant_dict.find_int (Transmission.Prefs.peer_port, out port)) {
                settings.set_int ("peer-port", (int) port);
            }
        } else {
            variant_dict.add_int (Transmission.Prefs.peer_port, settings.get_int ("peer-port"));
        }

        if (settings.get_boolean ("force-encryption")) {
            variant_dict.add_int (Transmission.Prefs.encryption, Transmission.EncryptionMode.ENCRYPTION_REQUIRED);
        } else {
            variant_dict.add_int (Transmission.Prefs.encryption, Transmission.EncryptionMode.ENCRYPTION_PREFERRED);
        }

        session.update_settings (variant_dict);
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
        torrent_constructor.set_download_dir (Transmission.ConstructionMode.FORCE, Utils.get_downloads_folder ());

        Transmission.ParseResult result;
        int duplicate_id;
        unowned Transmission.Torrent torrent = torrent_constructor.instantiate (out result, out duplicate_id);
        if (result == Transmission.ParseResult.OK) {
            torrent.set_completeness_callback (on_completeness_changed);
            created_torrent = new Torrent (torrent);
            added_torrents.add (torrent);

            check_trash ();
        } else {
            created_torrent = null;
        }

        return result;
    }

    public Transmission.ParseResult add_torrent_by_magnet (string magnet, out Torrent? created_torrent) {
        torrent_constructor = new Transmission.TorrentConstructor (session);
        torrent_constructor.set_metainfo_from_magnet_link (magnet);
        torrent_constructor.set_download_dir (Transmission.ConstructionMode.FORCE, Utils.get_downloads_folder ());

        Transmission.ParseResult result;
        int duplicate_id;
        unowned Transmission.Torrent torrent = torrent_constructor.instantiate (out result, out duplicate_id);
        if (result == Transmission.ParseResult.OK) {
            torrent.set_completeness_callback (on_completeness_changed);
            created_torrent = new Torrent (torrent);
            added_torrents.add (torrent);

            check_trash ();
        } else {
            created_torrent = null;
        }

        return result;
    }

    private void check_trash () {
        if (settings.get_boolean ("trash-original-torrents")) {
            var path = torrent_constructor.source_file;
            if (path != null && !path.has_prefix (CONFIG_DIR)) {
                var file = File.new_for_path (path);
                try {
                    file.trash ();
                } catch (Error e) {
                    warning ("An error occured while trying to trash the original torrent file");
                }
            }
        }
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

    public void open_torrent (int torrent_id) {
        foreach (unowned Transmission.Torrent torrent in added_torrents) {
            if (torrent.id == torrent_id) {
                if (torrent.stat.activity == Transmission.Activity.SEED && torrent.info.files.length == 1) {
                    var files = torrent.info.files;
                    if (files != null && files.length > 0) {
                    bool certain = false;
                    var content_type = ContentType.guess (files[0].name, null, out certain);
                        var appinfo = AppInfo.get_default_for_type (content_type, true);
                        if (appinfo != null) {
                            var path = Path.build_path (Path.DIR_SEPARATOR_S, torrent.download_dir, files[0].name);
                            var file = File.new_for_path (path);
                            if (file.query_exists ()) {
                                var file_list = new List<string> ();
                                file_list.append (file.get_uri ());
                                try {
                                    appinfo.launch_uris (file_list, null);
                                    return;
                                } catch (Error e) {
                                    warning ("Unable to launch default handler for %s, falling back to file manager", content_type);
                                    open_torrent_location (torrent_id);
                                }
                            }
                        }
                    }
                }
                break;
            }
        }

        open_torrent_location (torrent_id);
    }

    public void open_torrent_location (int torrent_id) {
        foreach (unowned Transmission.Torrent torrent in added_torrents) {
            if (torrent.id == torrent_id) {
                DBus.Files files;
                try {
                    files = Bus.get_proxy_sync (BusType.SESSION, FILES_DBUS_ID, FILES_DBUS_PATH);
                } catch (IOError e) {
                    warning ("Unable to connect to FileManager1 interface to show file. Error: %s", e.message);
                    return;
                }
                var path = Path.build_path (Path.DIR_SEPARATOR_S, torrent.download_dir, new Torrent (torrent).files[0].name);
                var file = File.new_for_path (path);
                if (file.query_exists ()) {
                    info (file.get_uri ());
                    try {
                        files.show_items ({ file.get_uri () }, "torrential");
                    } catch (Error e) {
                        warning ("Unable to instruct file manager to show file. Error: %s", e.message);
                        return;
                    }
                } else {
                    path += ".part";
                    file = File.new_for_path (path);
                    if (file.query_exists ()) {
                        try {
                            files.show_items ({ file.get_uri () }, "torrential");
                        } catch (Error e) {
                            warning ("Unable to instruct file manager to show file. Error: %s", e.message);
                            return;
                        }
                    } else {
                        path = path.substring (0, path.last_index_of ("/"));
                        try {
                            string uri = "";
                            try {
                                uri = Filename.to_uri (path);
                            } catch (ConvertError e) {
                                warning ("Unable to convert path to URI to open filemanager: %s", e.message);
                                return;
                            }
                            files.show_folders ({ uri }, "torrential");
                        } catch (Error e) {
                            warning ("Unable to instruct file manager to show folder. Error: %s", e.message);
                            return;
                        }
                    }
                }
                break;
            }
        }
    }

    public float get_overall_progress () {
        if (added_torrents.size == 0) {
            return 0.0f;
        }
        int count = 0;
        float totalProgress = 0.0f;
        foreach (unowned Transmission.Torrent torrent in added_torrents) {
            var torrential_torrent = new Torrent (torrent);
            if (torrential_torrent.downloading) {
                totalProgress += torrential_torrent.progress;
                count++;
            }
        }
        if (count == 0) {
            return 1.0f;
        }
        return totalProgress / count;
    }
}
