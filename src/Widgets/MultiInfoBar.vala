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

public class Torrential.Widgets.MultiInfoBar : Gtk.Box {
    private Gtk.Label infobar_label;
    private Gee.ArrayQueue<string> infobar_errors = new Gee.ArrayQueue<string> ();
    private Gtk.Button next_button;
    private Gtk.InfoBar infobar;

    construct {
        infobar_label = new Gtk.Label ("") {
            wrap = true,
            xalign = 0
        };

        infobar = new Gtk.InfoBar () {
            hexpand = true,
            message_type = Gtk.MessageType.WARNING,
            revealed = false
        };
        infobar.add_child (infobar_label);

        next_button = (Gtk.Button) infobar.add_button (_("Next Warning"), 0);
        next_button.clicked.connect (() => next_error ());

        var close_button = (Gtk.Button) infobar.add_button (_("Close"), Gtk.ResponseType.CLOSE);
        close_button.clicked.connect (() => close_bar ());

        append (infobar);
    }

    public void add_errors (Gee.ArrayList<string> errors) {
        foreach (var error in errors) {
            infobar_errors.offer (error);
        }
        refresh_bar ();
    }

    public void add_error (string error) {
        infobar_errors.offer (error);
        refresh_bar ();
    }

    private void next_error () {
        infobar_errors.poll ();
        refresh_bar ();
    }

    private void close_bar () {
        infobar.revealed = false;
        infobar_errors.clear ();
    }

    private void refresh_bar () {
        if (infobar_errors.size > 0) {
            infobar_label.label = infobar_errors.peek ();
            if (infobar_errors.size > 1) {
                var n = infobar_errors.size - 1;
                infobar_label.label += " " + ngettext ("(Plus %d more warning\u2026)", "(Plus %d more warnings\u2026)", n).printf (n);
                next_button.show ();
            } else {
                next_button.hide ();
            }
            infobar_label.show ();
            infobar.revealed = true;
        }
    }
}
