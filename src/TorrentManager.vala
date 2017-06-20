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

public class Torrential.TorrentManager {
    private Transmission.variant_dict settings;
    private Transmission.Session session;
    private Transmission.TorrentConstructor torrent_constructor;
    private unowned Transmission.Torrent[] transmission_torrents;
    private Gee.ArrayList <unowned Transmission.Torrent> added_torrents = new Gee.ArrayList <unowned Transmission.Torrent> ();

    public TorrentManager () {
        var config_dir = Path.build_path (Path.DIR_SEPARATOR_S, Environment.get_user_config_dir (), "torrential");

        Transmission.String.Units.mem_init (1024, _("kB"), _("MB"), _("GB"), _("TB"));
        settings = Transmission.variant_dict (0);
        Transmission.load_default_settings (ref settings, config_dir, "torrential");

        session = new Transmission.Session (config_dir, false, settings);
        torrent_constructor = new Transmission.TorrentConstructor (session);
        transmission_torrents = session.load_torrents (torrent_constructor);
    }

    public Gee.ArrayList<Torrent> get_torrents () {
        Gee.ArrayList<Torrent> torrents = new Gee.ArrayList<Torrent>();
        for (int i = 0; i < transmission_torrents.length; i++) {
            torrents.add (new Torrent (transmission_torrents[i]));
        }
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
            created_torrent = new Torrent (torrent);
            added_torrents.add (torrent);
        } else {
            created_torrent = null;
        }

        return result;
    }
}
