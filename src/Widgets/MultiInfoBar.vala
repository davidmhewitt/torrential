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

public class Torrential.Widgets.MultiInfoBar : Gtk.InfoBar {
    
    private Gtk.Label infobar_label = new Gtk.Label ("");
    private Gee.ArrayQueue<string> infobar_errors;
    private Gtk.Button next_button;

    construct {
        var content = get_content_area ();
        content.add (infobar_label);

        var action = get_action_area () as Gtk.ButtonBox;
        next_button = new Gtk.Button.with_label (_("Next Warning"));
        next_button.clicked.connect (() => set_errors (infobar_errors));
        var close_button = new Gtk.Button.with_label (_("Close"));
        close_button.clicked.connect (() => hide ());
        action.add (next_button);
        action.add (close_button);
        action.show_all ();
    }

    public void set_errors (Gee.ArrayQueue<string> errors) {
        infobar_errors = errors;
        if (infobar_errors.size > 0) {
            infobar_label.label = infobar_errors.poll ();
            if (infobar_errors.size > 0) {
                var n = infobar_errors.size;
                infobar_label.label += " " + ngettext ("(Plus %d more warning\u2026)", "(Plus %d more warnings\u2026)", n).printf (n);
                next_button.show ();
            } else {
                next_button.hide ();
            }
            infobar_label.show ();
        }
    }

}
