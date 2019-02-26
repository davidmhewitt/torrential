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
    public abstract void show_items (string[] uris, string startup_id) throws IOError, DBusError;
    public abstract void show_folders (string[] uris, string startup_id) throws IOError, DBusError;
}

const string FILES_DBUS_ID = "org.freedesktop.FileManager1";
const string FILES_DBUS_PATH = "/org/freedesktop/FileManager1";

public class Torrential.TorrentManager : Object {
    public bool blocklist_updating { get; private set; default = false; }

    private Transmission.variant_dict settings;
    private Transmission.Session session;
    private Transmission.TorrentConstructor torrent_constructor;
    private Gee.ArrayList <unowned Transmission.Torrent> added_torrents = new Gee.ArrayList <unowned Transmission.Torrent> ();
    private Settings saved_state = Settings.get_default ();

    private Thread<void*>? update_session_thread = null;

    public signal void torrent_completed (Torrent torrent);
    public signal void blocklist_load_failed ();

    private static string CONFIG_DIR = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_config_dir (), "torrential");

    private static int next_tag = 0;

    public TorrentManager () {
        Transmission.String.Units.mem_init (1024, _("KB"), _("MB"), _("GB"), _("TB"));
        Transmission.String.Units.speed_init (1024, _("KB/s"), _("MB/s"), _("GB/s"), _("TB/s"));
        settings = Transmission.variant_dict (0);
        Transmission.load_default_settings (ref settings, CONFIG_DIR, "torrential");

        update_session_settings ();

        session = new Transmission.Session (CONFIG_DIR, false, settings);
        info (session.blocklist.count.to_string ());
        torrent_constructor = new Transmission.TorrentConstructor (session);
        unowned Transmission.Torrent[] transmission_torrents = session.load_torrents (torrent_constructor);
        for (int i = 0; i < transmission_torrents.length; i++) {
            transmission_torrents[i].set_completeness_callback (on_completeness_changed);
            added_torrents.add (transmission_torrents[i]);
        }

        // Only auto-update blocklist once every day
        if (new DateTime.now_local ().to_unix () - saved_state.blocklist_updated_timestamp > 3600 * 24) {
            update_blocklist ();
        }
    }

    ~TorrentManager () {
        session.save_settings (CONFIG_DIR, settings);
    }

    public void close () throws ThreadError {
        ThreadFunc<void*> run = () => {
            update_session_settings ();
            session.update_settings (settings);

            return null;
        };
        update_session_thread = new Thread<void*> ("update-session-settings", run);
    }

    public void wait_for_close () {
        if (update_session_thread != null) {
            update_session_thread.join ();
        }
    }

    public bool has_active_torrents () {
        foreach (var torrent in get_torrents ()) {
            if (torrent.seeding || torrent.downloading || torrent.waiting) {
                return true;
            }
        }
        return false;
    }

    public void update_blocklist () {
        // Only update the blocklist if we have one set
        if (saved_state.blocklist_url.strip ().length == 0) {
            return;
        }

        settings.add_str (Transmission.Prefs.blocklist_url, saved_state.blocklist_url.strip ());
        session.blocklist.url = saved_state.blocklist_url.strip ();

        next_tag++;
        blocklist_updating = true;

        var request = Transmission.variant_dict (2);
        request.add_str (Transmission.Prefs.method, "blocklist-update");
        request.add_int (Transmission.Prefs.tag, next_tag);

        Transmission.exec_JSON_RPC (session, request, on_blocklist_response);
    }

    private void on_blocklist_response (Transmission.Session session, Transmission.variant_dict response) {
        int64 rulecount = 0;
        Transmission.variant_dict args;

        if (!response.find_doc (Transmission.Prefs.arguments, out args) || !args.find_int (Transmission.Prefs.blocklist_size, out rulecount)) {
            rulecount = -1;
        }

        if (rulecount == -1) {
            Idle.add (() => {
                blocklist_load_failed ();
                foreach (unowned Transmission.Torrent torrent in added_torrents) {
                    torrent.stop ();
                }

                return Source.REMOVE;
            });
        } else {
            Idle.add (() => {
                saved_state.blocklist_updated_timestamp = new DateTime.now_local ().to_unix ();
                return Source.REMOVE;
            });
        }

        blocklist_updating = false;
    }

    private void update_session_settings () {
        settings.add_int (Transmission.Prefs.download_queue_size, saved_state.max_downloads);

        if (saved_state.download_speed_limit == 0) {
            settings.add_bool (Transmission.Prefs.speed_limit_down_enabled, false);
        } else {
            settings.add_bool (Transmission.Prefs.speed_limit_down_enabled, true);
            settings.add_int (Transmission.Prefs.speed_limit_down, saved_state.download_speed_limit);
        }

        if (saved_state.upload_speed_limit == 0) {
            settings.add_bool (Transmission.Prefs.speed_limit_up_enabled, false);
        } else {
            settings.add_bool (Transmission.Prefs.speed_limit_up_enabled, true);
            settings.add_int (Transmission.Prefs.speed_limit_up, saved_state.upload_speed_limit);
        }

        settings.add_bool (Transmission.Prefs.peer_port_random_on_start, saved_state.randomize_port);
        if (saved_state.randomize_port) {
            int64 port = 0;
            if (settings.find_int (Transmission.Prefs.peer_port, out port)) {
                saved_state.peer_port = (int)port;
            }
        } else {
            settings.add_int (Transmission.Prefs.peer_port, saved_state.peer_port);
        }

        if (saved_state.force_encryption) {
            settings.add_int (Transmission.Prefs.encryption, Transmission.EncryptionMode.ENCRYPTION_REQUIRED);
        } else {
            settings.add_int (Transmission.Prefs.encryption, Transmission.EncryptionMode.ENCRYPTION_PREFERRED);
        }

        if (saved_state.blocklist_url.strip ().length > 0) {
            settings.add_bool (Transmission.Prefs.blocklist_enabled, true);
            settings.add_str (Transmission.Prefs.blocklist_url, saved_state.blocklist_url.strip ());
        } else {
            settings.add_bool (Transmission.Prefs.blocklist_enabled, false);
        }

        settings.add_bool (Transmission.Prefs.ratio_limit_enabled, saved_state.seed_ratio_enabled);
        settings.add_real (Transmission.Prefs.ratio_limit, saved_state.seed_ratio);
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
        torrent_constructor.set_download_dir (Transmission.ConstructionMode.FORCE, saved_state.download_folder);

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
        torrent_constructor.set_download_dir (Transmission.ConstructionMode.FORCE, saved_state.download_folder);

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
        if (Settings.get_default ().trash_original_torrents) {
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

    public void remove_torrent (Torrent to_remove, bool delete_files) {
        foreach (unowned Transmission.Torrent torrent in added_torrents) {
            if (torrent.id == to_remove.id) {
                added_torrents.remove (torrent);
                break;
            }
        }
        to_remove.remove (delete_files);
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
