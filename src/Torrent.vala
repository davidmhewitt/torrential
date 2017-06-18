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
            if (torrent.stat_cached != null) {
                return torrent.stat_cached.percentComplete;
            } else {
                return 0.0f;
            }
        }
    }

    public float download_speed_kbps {
        get {
            if (torrent.stat_cached != null) {
                return torrent.stat_cached.rawDownloadSpeed_KBps;
            } else {
                return 0.0f;
            }
        }
    }

    public int seconds_remaining {
        get {
            if (torrent.stat_cached != null) {
                return torrent.stat_cached.eta;
            } else {
                return -1;
            }
        }
    }

    public uint64 bytes_downloaded {
        get {
            if (torrent.stat_cached != null) {
                return torrent.stat_cached.haveValid;
            } else {
                return 0;
            }
        }
    }

    public uint64 bytes_total {
        get {
            if (torrent.stat_cached != null) {
                return torrent.stat_cached.sizeWhenDone;
            } else {
                return 0;
            }
        }
    }

    public int connected_peers {
        get {
            if (torrent.stat_cached != null) {
                return torrent.stat_cached.peersConnected;
            } else {
                return 0;
            }
        }
    }

    public int total_peers {
        get {
            int total = 0;
            if (torrent.stat_cached != null) {
                for (int i = 0; i < torrent.stat_cached.peersFrom.length; i++) {
                    total += torrent.stat_cached.peersFrom[i];
                }
            }
            return total;
        }
    }

    public bool paused {
        get {
            if (torrent.stat_cached != null) {
                return torrent.stat_cached.activity == Transmission.Activity.STOPPED;
            } else {
                return false;
            }
        }
    }

    public int file_count {
        get {
            if (torrent.info != null) {
                return torrent.info.files.length;
            } else {
                return -1;
            }
        }
    }

    public void pause () {
        torrent.stop ();
    }

    public void unpause () {
        torrent.start ();
    }

    public void remove () {
        torrent.remove (false, null);
    }
    
    public Torrent (Transmission.Torrent torrent) {
        this.torrent = torrent;
    }
        
}
