/* Copyright 2015 Marvin Beckers <beckersmarvin@gmail.com>
*
* This program is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with this program. If not, see http://www.gnu.org/licenses/.
*/

public class Torrential.PreferencesWindow : Gtk.Dialog {

    public const int MIN_WIDTH = 420;
    public const int MIN_HEIGHT = 300;

    private Settings saved_state = Settings.get_default ();

    private Gtk.FileChooserButton location_chooser;

    public PreferencesWindow (Torrential.MainWindow parent) {
        // Window properties        
        title = _("Preferences");
        set_size_request (MIN_WIDTH, MIN_HEIGHT);
        resizable = false;
        deletable = false;
        destroy_with_parent = true;
        window_position = Gtk.WindowPosition.CENTER;
        set_transient_for (parent);

        var location_heading = create_heading (_("Download Location"));

        location_chooser = new Gtk.FileChooserButton (_("Select Download Folder…"), Gtk.FileChooserAction.SELECT_FOLDER);
        location_chooser.hexpand = true;
        location_chooser.set_current_folder (saved_state.download_folder);
        location_chooser.file_set.connect (() => {
            saved_state.download_folder = location_chooser.get_file ().get_path ();
        });
        
        var download_heading = create_heading (_("Download Management"));
                
        var delete_torrent_switch = create_switch ();
        var delete_torrent_label = create_label (_("Delete imported .torrent files:"));
        
        var force_encryption_switch = create_switch ();
        var force_encryption_label = create_label (_("Force encryption:"));
        
        var randomise_port_switch = create_switch ();
        var randomise_port_label  = create_label (_("Randomise port on every launch:"));
        
        var desktop_label = create_heading (_("Desktop Integration"));
        
        var hide_on_close_switch = create_switch ();
        var hide_on_close_label = create_label (_("Continue download when closed:"));

        var close_button = new Gtk.Button.with_label (_("Close"));
        close_button.clicked.connect (() => { this.destroy (); });

        var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        button_box.set_layout (Gtk.ButtonBoxStyle.END);
        button_box.pack_end (close_button);

        Gtk.Grid main_grid = new Gtk.Grid ();
        main_grid.margin = 12;
        main_grid.hexpand = true;
        main_grid.column_spacing = 12;
        main_grid.row_spacing = 6;

        main_grid.attach (location_heading, 0, 0, 1, 1);
        main_grid.attach (location_chooser, 0, 1, 1, 1);

        main_grid.attach (download_heading, 0, 2, 1, 1);
        main_grid.attach (delete_torrent_label, 0, 3, 1, 1);
        main_grid.attach (delete_torrent_switch, 1, 3, 1, 1);
        main_grid.attach (force_encryption_label, 0, 4, 1, 1);
        main_grid.attach (force_encryption_switch, 1, 4, 1, 1);
        main_grid.attach (randomise_port_label, 0, 5, 1, 1);
        main_grid.attach (randomise_port_switch, 1, 5, 1, 1);

        main_grid.attach (desktop_label, 0, 6, 1, 1);
        main_grid.attach (hide_on_close_label, 0, 7, 1, 1);
        main_grid.attach (hide_on_close_switch, 1, 7, 1, 1);

        main_grid.attach (button_box, 0, 8, 2, 1);

        ((Gtk.Container) get_content_area ()).add (main_grid);

        saved_state.changed.connect (on_saved_settings_changed);
    }

    private void on_saved_settings_changed () {
        location_chooser.set_current_folder (saved_state.download_folder);
    }

    private Gtk.Label create_heading (string text) {
        var label = new Gtk.Label (text);
        label.get_style_context ().add_class ("h4");
        label.halign = Gtk.Align.START;

        return label;
    }

    private Gtk.Switch create_switch () {
        var toggle = new Gtk.Switch ();
        toggle.halign = Gtk.Align.START;
        toggle.hexpand = true;

        return toggle;
    }

    private Gtk.Label create_label (string text) {
        var label = new Gtk.Label (text);
        label.hexpand = true;
        label.halign = Gtk.Align.END;
        label.margin_start = 20;

        return label;
    }
}

