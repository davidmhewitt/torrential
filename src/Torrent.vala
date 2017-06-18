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

public class Torrential.Torrent {
    private unowned Transmission.Torrent torrent;

    public string name {
        get {
            return torrent.name;
        }
    }

    public float progress {
        get {
            return torrent.stat.percentComplete;
        }
    }

    public float download_speed_kbps {
        get {
            return torrent.stat.rawDownloadSpeed_KBps;
        }
    }

    public int seconds_remaining {
        get {
            return torrent.stat.eta;
        }
    }

    public uint64 bytes_downloaded {
        get {
            return torrent.stat.haveValid;
        }
    }

    public uint64 bytes_total {
        get {
            return torrent.stat.sizeWhenDone;
        }
    }

    public int connected_peers {
        get {
            return torrent.stat.peersConnected;
        }
    }

    public int total_peers {
        get {
            int total = 0;
            for (int i = 0; i < torrent.stat.peersFrom.length; i++) {
                total += torrent.stat.peersFrom[i];
            }
            return total;
        }
    }

    public bool paused {
        get {
            return torrent.stat.activity == Transmission.Activity.STOPPED;
        }
    }

    public void pause () {
        torrent.stop ();
    }

    public void unpause () {
        torrent.start ();
    }
    
    public Torrent (Transmission.Torrent torrent) {
        this.torrent = torrent;
    }
        
}
