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

public class Torrential.PreferencesWindow : Granite.Dialog {

    public signal void on_close ();

    private const int MIN_WIDTH = 420;
    private const int MIN_HEIGHT = 300;

    private Settings saved_state = Settings.get_default ();

    private Gtk.Label location_chooser_label;

    public weak MainWindow parent_window { private get; construct; }

    public PreferencesWindow (Torrential.MainWindow parent) {
        Object (parent_window: parent);
    }

    construct {
        // Window properties
        title = _("Preferences");
        set_size_request (MIN_WIDTH, MIN_HEIGHT);
        resizable = false;
        deletable = false;
        destroy_with_parent = true;
        window_position = Gtk.WindowPosition.CENTER;
        set_transient_for (parent_window);

        var stack = new Gtk.Stack ();
        stack.add_titled (create_general_settings_widgets (), "general", _("General"));
        stack.add_titled (create_advanced_settings_widgets (), "advanced", _("Advanced"));

        var switcher = new Gtk.StackSwitcher ();
        switcher.hexpand = true;
        switcher.halign = Gtk.Align.CENTER;
        switcher.margin_start = 20;
        switcher.margin_end = 20;
        switcher.set_stack (stack);

        var close_button = new Gtk.Button.with_label (_("Close"));
        close_button.clicked.connect (() => {
            on_close ();
            this.destroy ();
        });

        var button_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
        button_box.margin_end = 10;
        button_box.set_layout (Gtk.ButtonBoxStyle.END);
        button_box.pack_end (close_button);

        var content_grid = new Gtk.Grid ();
        content_grid.attach (switcher, 0, 0, 1, 1);
        content_grid.attach (stack, 0, 1, 1, 1);
        content_grid.attach (button_box, 0, 2, 1, 1);

        ((Gtk.Container) get_content_area ()).add (content_grid);

        saved_state.changed.connect (on_saved_settings_changed);
    }

    private void on_saved_settings_changed () {
        location_chooser_label.label = saved_state.download_folder;
    }

    private Gtk.Grid create_advanced_settings_widgets () {
        var force_encryption_switch = create_switch ();
        saved_state.bind_property ("force_encryption", force_encryption_switch, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        var force_encryption_label = create_label (_("Only connect to encrypted peers:"));

        var randomise_port_switch = create_switch ();
        saved_state.bind_property ("randomize_port", randomise_port_switch, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        var randomise_port_label  = create_label (_("Randomise BitTorrent port on launch:"));

        var port_entry = create_spinbutton (49152, 65535, 1);
        saved_state.bind_property ("peer_port", port_entry, "value", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        randomise_port_switch.bind_property ("active", port_entry, "sensitive", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
        var port_label = create_label (_("Port number:"));

        Gtk.Grid advanced_grid = new Gtk.Grid ();
        advanced_grid.margin = 12;
        advanced_grid.hexpand = true;
        advanced_grid.column_spacing = 12;
        advanced_grid.row_spacing = 6;

        advanced_grid.attach (create_heading (_("Security")), 0, 2, 1, 1);
        advanced_grid.attach (force_encryption_label, 0, 3, 1, 1);
        advanced_grid.attach (force_encryption_switch, 1, 3, 1, 1);
        advanced_grid.attach (randomise_port_label, 0, 4, 1, 1);
        advanced_grid.attach (randomise_port_switch, 1, 4, 1, 1);
        advanced_grid.attach (port_label, 0, 5, 1, 1);
        advanced_grid.attach (port_entry, 1, 5, 1, 1);

        return advanced_grid;
    }

    private Gtk.Grid create_general_settings_widgets () {
        var location_heading = create_heading (_("Download Location"));

        var location_chooser = new Gtk.Button () {
            hexpand = true,
            halign = Gtk.Align.FILL,
            margin_start = 20,
            margin_end = 20
        };

        location_chooser.clicked.connect (() => {
            var chooser = new Gtk.FileChooserDialog (
                _("Select Download Folder…"),
                this,
                Gtk.FileChooserAction.SELECT_FOLDER,
                _("Cancel"), Gtk.ResponseType.CANCEL,
                _("Select"), Gtk.ResponseType.ACCEPT
            );

            var res = chooser.run ();

            if (res == Gtk.ResponseType.ACCEPT) {
                saved_state.download_folder = chooser.get_file ().get_path ();
            }

            chooser.destroy ();
        });

        location_chooser_label = new Gtk.Label (saved_state.download_folder);

        var location_grid = new Gtk.Grid () {
            column_spacing = 3
        };

        location_grid.add (new Gtk.Image.from_icon_name ("folder", Gtk.IconSize.BUTTON));
        location_grid.add (location_chooser_label);

        location_chooser.add (location_grid);

        var download_heading = create_heading (_("Limits"));

        var max_downloads_entry = create_spinbutton (1, 100, 1);
        saved_state.bind_property ("max_downloads", max_downloads_entry, "value", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        var max_downloads_label = create_label (_("Max simultaneous downloads:"));

        var download_speed_limit_entry = create_spinbutton (0, 1000000, 25);
        download_speed_limit_entry.tooltip_text = _("0 means unlimited");
        saved_state.bind_property ("download_speed_limit", download_speed_limit_entry, "value", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        var download_speed_limit_label = create_label (_("Download speed limit (KBps):"));

        var upload_speed_limit_entry = create_spinbutton (0, 1000000, 25);
        upload_speed_limit_entry.tooltip_text = _("0 means unlimited");
        saved_state.bind_property ("upload_speed_limit", upload_speed_limit_entry, "value", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        var upload_speed_limit_label = create_label (_("Upload speed limit (KBps):"));

        var desktop_label = create_heading (_("Desktop Integration"));

        var hide_on_close_switch = create_switch ();
        saved_state.bind_property ("hide_on_close", hide_on_close_switch, "active", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
        var hide_on_close_label = create_label (_("Continue downloads when closed:"));

        Gtk.Grid general_grid = new Gtk.Grid ();
        general_grid.margin = 12;
        general_grid.hexpand = true;
        general_grid.column_spacing = 12;
        general_grid.row_spacing = 6;

        general_grid.attach (location_heading, 0, 0, 1, 1);
        general_grid.attach (location_chooser, 0, 1, 2, 1);

        general_grid.attach (download_heading, 0, 2, 1, 1);
        general_grid.attach (max_downloads_label, 0, 3, 1, 1);
        general_grid.attach (max_downloads_entry, 1, 3, 1, 1);
        general_grid.attach (download_speed_limit_label, 0, 4, 1, 1);
        general_grid.attach (download_speed_limit_entry, 1, 4, 1, 1);
        general_grid.attach (upload_speed_limit_label, 0, 5, 1, 1);
        general_grid.attach (upload_speed_limit_entry, 1, 5, 1, 1);

        general_grid.attach (desktop_label, 0, 7, 1, 1);
        general_grid.attach (hide_on_close_label, 0, 8, 1, 1);
        general_grid.attach (hide_on_close_switch, 1, 8, 1, 1);

        return general_grid;
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

    private Gtk.SpinButton create_spinbutton (double min, double max, double step) {
        var button = new Gtk.SpinButton.with_range (min, max, step);
        button.halign = Gtk.Align.START;
        button.hexpand = true;

        return button;
    }
}

