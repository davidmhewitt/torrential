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
    private Settings saved_state = Settings.get_default ();

    private Thread<void*>? update_session_thread = null;

    public signal void torrent_completed (Torrent torrent);
    public signal void blocklist_load_failed ();
    public signal void blocklist_load_complete ();

    private static string CONFIG_DIR = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_config_dir (), "torrential");

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

        update_blocklists ();
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

    public void update_blocklists (bool force = false) {
        load_blocklists.begin (force, (obj, res) => {
            bool success = load_blocklists.end (res);
            blocklist_load_complete ();
            if (!success) {
                foreach (unowned Transmission.Torrent torrent in added_torrents) {
                    torrent.stop ();
                }
                blocklist_load_failed ();
            }
        });
    }

    public bool has_active_torrents () {
        foreach (var torrent in get_torrents ()) {
            if (torrent.seeding || torrent.downloading || torrent.waiting) {
                return true;
            }
        }
        return false;
    }

    private async bool load_blocklists (bool force = false) {
        var dest_folder = Path.build_path (Path.DIR_SEPARATOR_S, CONFIG_DIR, "blocklists");

        // Delete any old blocklists if there's no blocklist specified anymore
        if (saved_state.blocklist_url.strip ().length == 0) {
            Dir d;
            try {
                d = Dir.open (dest_folder);
            } catch (FileError e) {
                warning ("Could not open blocklists folder for deletion of old blocklists. Error: %s", e.message);
                return true;
            }
            unowned string? name;
            while ((name = d.read_name ()) != null) {
                try {
                    string path = Path.build_filename(dest_folder, name);
                    yield File.new_for_path (path).delete_async ();
                } catch (Error e) {
                    warning ("Could not delete one of the old blocklists. Error: %s", e.message);
                }
            }
            saved_state.blocklist_updated_timestamp = 0;
            return true;
        }

        int blocklist_count = 0;
        try {
            var d = Dir.open (dest_folder);
            unowned string? name;
            while ((name = d.read_name ()) != null) {
                blocklist_count++;
            }
        } catch (FileError e) {
            warning ("Could not open blocklists folder for checking blocklists. Error: %s", e.message);
        }

        if (blocklist_count == 0) force = true;

        // Don't update if we downloaded within the last day
        if (!force && new DateTime.now_local ().to_unix () - saved_state.blocklist_updated_timestamp < 86400) {
            return true;
        }

        var archive_filename = saved_state.blocklist_url.substring (saved_state.blocklist_url.last_index_of ("/"));
        var dest_file = Path.build_path (Path.DIR_SEPARATOR_S, dest_folder, archive_filename);

        var source = File.new_for_uri (saved_state.blocklist_url);
        var dest = File.new_for_path (dest_file);
        try {
            yield source.copy_async (dest, FileCopyFlags.OVERWRITE);
        } catch (Error e) {
            critical ("Failed to download blocklist '%s'. Error: %s", source.get_uri (), e.message);
            return false;
        }

        SourceFunc callback = load_blocklists.callback;
        bool thread_output = false;

        ThreadFunc<void*> run = () => {
            // initialize the archive
            var archive = new Archive.Read();

            // automatically detect archive type
            archive.support_compression_all();
            archive.support_format_all();
            archive.support_format_raw ();

            // open the archive
            if (archive.open_filename(dest_file, 4096) != Archive.Result.OK) {
                critical ("Failed to extract blocklist. Error: %s", archive.error_string ());
                Idle.add ((owned) callback);
                return null;
            }

            // extract the archive
            weak Archive.Entry entry;
            while (archive.next_header (out entry) == Archive.Result.OK) {
                var fpath = Path.build_filename (dest_folder, entry.pathname ());
                var file = GLib.File.new_for_path (fpath);

                if (Posix.S_ISDIR (entry.mode ())) {
                    try {
                        file.make_directory_with_parents (null);
                    } catch (Error e) {
                        critical ("Failed to extract blocklist. Error: %s", e.message);
                        Idle.add ((owned) callback);
                        return null;
                    }
                } else {
                    var parent = file.get_parent ();
                    if (!parent.query_exists (null)) {
                        try {
                            parent.make_directory_with_parents (null);
                        } catch (Error e) {
                            critical ("Failed to extract blocklist. Error: %s", e.message);
                            Idle.add ((owned) callback);
                            return null;
                        }
                    }

                    try {
                        if (!file.query_exists (null)) {
                            file.create (FileCreateFlags.REPLACE_DESTINATION, null);
                        }
                    } catch (Error e) {
                        critical ("Failed to extract blocklist. Error: %s", e.message);
                        Idle.add ((owned) callback);
                        return null;
                    }
                    int fd = Posix.open (fpath, Posix.O_WRONLY, 0644);
                    archive.read_data_into_fd (fd);
                    Posix.close (fd);
                }
            }
            thread_output = true;
            Idle.add ((owned) callback);
            return null;
        };
        try {
            Thread.create<void*>(run, false);
        } catch (ThreadError e) {
            critical ("Failed to start thread to extract blocklist. Error: %s", e.message);
            return false;
        }

        yield;

        if (!thread_output) {
            return false;
        }

        try {
            yield File.new_for_path (dest_file).delete_async ();
        } catch (Error e) {
            warning ("Failed to delete extracted blocklist archive. Error: %s", e.message);
        }
        session.reload_block_lists ();
        saved_state.blocklist_updated_timestamp = new DateTime.now_local ().to_unix ();
        return true;
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
                    } catch (IOError e) {
                        warning ("Unable to instruct file manager to show file. Error: %s", e.message);
                        return;
                    }
                } else {
                    path += ".part";
                    file = File.new_for_path (path);
                    if (file.query_exists ()) {
                        try {
                            files.show_items ({ file.get_uri () }, "torrential");
                        } catch (IOError e) {
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
                        } catch (IOError e) {
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
