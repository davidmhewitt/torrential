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

    private GLib.Settings settings;

    private Gtk.Label location_chooser_label;

    public weak MainWindow parent_window { private get; construct; }

    public PreferencesWindow (Torrential.MainWindow parent) {
        Object (parent_window: parent);
    }

    construct {
        // Window properties
        title = _("Preferences");
        set_default_size (MIN_WIDTH, MIN_HEIGHT);
        resizable = false;
        destroy_with_parent = true;
        set_transient_for (parent_window);

        settings = new GLib.Settings ("com.github.davidmhewitt.torrential.settings");

        var stack = new Gtk.Stack ();
        stack.add_titled (create_general_settings_widgets (), "general", _("General"));
        stack.add_titled (create_advanced_settings_widgets (), "advanced", _("Advanced"));

        var switcher = new Gtk.StackSwitcher () {
            halign = Gtk.Align.CENTER,
            stack = stack
        };

        var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        box.add (switcher);
        box.add (stack);

        get_content_area ().add (box);

        var close_button = (Gtk.Button) add_button (_("Close"), Gtk.ResponseType.CLOSE);
        close_button.clicked.connect (() => {
            on_close ();
            destroy ();
        });

        settings.changed.connect (on_saved_settings_changed);
    }

    private void on_saved_settings_changed () {
        location_chooser_label.label = Utils.get_downloads_folder ();
    }

    private Gtk.Grid create_advanced_settings_widgets () {
        var force_encryption_switch = create_switch ();
        settings.bind ("force-encryption", force_encryption_switch, "active", SettingsBindFlags.DEFAULT);
        var force_encryption_label = create_label (_("Only connect to encrypted peers:"));

        var randomise_port_switch = create_switch ();
        settings.bind ("randomize-port", randomise_port_switch, "active", SettingsBindFlags.DEFAULT);
        var randomise_port_label  = create_label (_("Randomise BitTorrent port on launch:"));

        var port_entry = create_spinbutton (49152, 65535, 1);
        settings.bind ("peer-port", port_entry, "value", SettingsBindFlags.DEFAULT);
        randomise_port_switch.bind_property ("active", port_entry, "sensitive", BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE | BindingFlags.INVERT_BOOLEAN);
        var port_label = create_label (_("Port number:"));

        Gtk.Grid advanced_grid = new Gtk.Grid ();
        advanced_grid.margin = 12;
        advanced_grid.hexpand = true;
        advanced_grid.column_spacing = 12;
        advanced_grid.row_spacing = 6;

        advanced_grid.attach (new Granite.HeaderLabel (_("Security")), 0, 2, 1, 1);
        advanced_grid.attach (force_encryption_label, 0, 3, 1, 1);
        advanced_grid.attach (force_encryption_switch, 1, 3, 1, 1);
        advanced_grid.attach (randomise_port_label, 0, 4, 1, 1);
        advanced_grid.attach (randomise_port_switch, 1, 4, 1, 1);
        advanced_grid.attach (port_label, 0, 5, 1, 1);
        advanced_grid.attach (port_entry, 1, 5, 1, 1);

        return advanced_grid;
    }

    private Gtk.Grid create_general_settings_widgets () {
        var location_heading = new Granite.HeaderLabel (_("Download Location"));

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
                settings.set_string ("download-folder", chooser.get_file ().get_path ());
            }

            chooser.destroy ();
        });

        location_chooser_label = new Gtk.Label (Utils.get_downloads_folder ());

        var location_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3);
        location_box.add (new Gtk.Image.from_icon_name ("folder", Gtk.IconSize.BUTTON));
        location_box.add (location_chooser_label);

        location_chooser.add (location_box);

        var download_heading = new Granite.HeaderLabel (_("Limits"));

        var max_downloads_entry = create_spinbutton (1, 100, 1);
        settings.bind ("max-downloads", max_downloads_entry, "value", SettingsBindFlags.DEFAULT);
        var max_downloads_label = create_label (_("Max simultaneous downloads:"));

        var download_speed_limit_entry = create_spinbutton (0, 1000000, 25);
        download_speed_limit_entry.tooltip_text = _("0 means unlimited");
        settings.bind ("download-speed-limit", download_speed_limit_entry, "value", SettingsBindFlags.DEFAULT);
        var download_speed_limit_label = create_label (_("Download speed limit (KBps):"));

        var upload_speed_limit_entry = create_spinbutton (0, 1000000, 25);
        upload_speed_limit_entry.tooltip_text = _("0 means unlimited");
        settings.bind ("upload-speed-limit", upload_speed_limit_entry, "value", SettingsBindFlags.DEFAULT);
        var upload_speed_limit_label = create_label (_("Upload speed limit (KBps):"));

        var desktop_label = new Granite.HeaderLabel (_("Desktop Integration"));

        var hide_on_close_switch = create_switch ();
        settings.bind ("hide-on-close", hide_on_close_switch, "active", SettingsBindFlags.DEFAULT);
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

