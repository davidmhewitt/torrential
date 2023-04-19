// TODO: Gtk.Dialog is deprecated, switch away from it
#![allow(deprecated)]

use crate::window::TorrentialWindow;
use gettextrs::gettext;
use granite::subclass::prelude::*;
use gtk::gio;
use gtk::gio::SettingsBindFlags;
use gtk::glib;
use gtk::glib::clone;
use gtk::glib::Properties;
use gtk::prelude::*;
use gtk::ResponseType;
use once_cell::sync::OnceCell;
use std::cell::RefCell;

mod imp {
    use super::*;

    #[derive(Properties, Debug, Default)]
    #[properties(wrapper_type = super::PreferencesDialog)]
    pub struct PreferencesDialog {
        #[property(get, set)]
        window: RefCell<gtk::Window>,
        pub settings: OnceCell<gio::Settings>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for PreferencesDialog {
        const NAME: &'static str = "PreferencesDialog";
        type Type = super::PreferencesDialog;
        type ParentType = granite::Dialog;
    }

    impl ObjectImpl for PreferencesDialog {
        fn properties() -> &'static [glib::ParamSpec] {
            Self::derived_properties()
        }

        fn set_property(&self, id: usize, value: &glib::Value, pspec: &glib::ParamSpec) {
            self.derived_set_property(id, value, pspec)
        }

        fn property(&self, id: usize, pspec: &glib::ParamSpec) -> glib::Value {
            self.derived_property(id, pspec)
        }

        fn constructed(&self) {
            self.parent_constructed();

            let obj = self.obj();

            obj.set_title(Some(&gettext("Preferences")));
            obj.set_resizable(false);
            obj.set_destroy_with_parent(true);
            obj.set_transient_for(Some(&obj.window()));

            let settings = gio::Settings::new("com.github.davidmhewitt.torrential.settings");
            obj.imp()
                .settings
                .set(settings)
                .expect("Settings should be assigned only once");

            let stack = gtk::Stack::new();
            stack.add_titled(
                &obj.create_general_settings_widgets(),
                Some("general"),
                &gettext("General"),
            );

            stack.add_titled(
                &obj.create_advanced_settings_widgets(),
                Some("advanced"),
                &gettext("Advanced"),
            );

            let switcher = gtk::StackSwitcher::builder()
                .halign(gtk::Align::Center)
                .stack(&stack)
                .build();

            let container = gtk::Box::builder()
                .orientation(gtk::Orientation::Vertical)
                .spacing(12)
                .margin_bottom(12)
                .margin_end(12)
                .margin_start(12)
                .build();

            container.append(&switcher);
            container.append(&stack);

            obj.content_area().append(&container);

            obj.add_button(&gettext("Close"), gtk::ResponseType::Close);
        }
    }
    impl WidgetImpl for PreferencesDialog {}
    impl WindowImpl for PreferencesDialog {}
    impl DialogImpl for PreferencesDialog {}
    impl GraniteDialogImpl for PreferencesDialog {}
}

glib::wrapper! {
    pub struct PreferencesDialog(ObjectSubclass<imp::PreferencesDialog>)
        @extends gtk::Widget, gtk::Window, gtk::Dialog, granite::Dialog;
}

impl PreferencesDialog {
    pub fn new(window: &TorrentialWindow) -> Self {
        glib::Object::builder().property("window", window).build()
    }

    fn create_general_settings_widgets(&self) -> gtk::Grid {
        let settings = self.imp().settings.get().expect("Couldn't get settings");
        let location_heading = granite::HeaderLabel::new(&gettext("Download Location"));

        let location_chooser_label = gtk::Label::new(Some(&crate::utils::get_downloads_folder()));

        let location_box = gtk::Box::new(gtk::Orientation::Horizontal, 3);
        location_box.append(&gtk::Image::from_icon_name("folder"));
        location_box.append(&location_chooser_label);

        let location_chooser = gtk::Button::builder()
            .child(&location_box)
            .hexpand(true)
            .margin_start(12)
            .build();

        location_chooser.connect_clicked(clone!(@weak self as this, @weak settings => move |_| {
            let chooser = gtk::FileChooserDialog::new(
                Some(gettext("Select Download Folder")),
                Some(&this),
                gtk::FileChooserAction::SelectFolder,
                &[
                    (&gettext("Cancel"), ResponseType::Cancel),
                    (&gettext("Select"), ResponseType::Accept)
                ]
            );

            chooser.connect_response(clone!(@weak settings => move |dialog, response| {
                if response == ResponseType::Accept {
                    match settings
                        .set_string(
                            "download-folder",
                            dialog
                                .file()
                                .expect("No file selected")
                                .path()
                                .expect("No path for file")
                                .to_str()
                                .expect("Couldn't convert path to string")
                        ) {
                            Ok(_) => {},
                            Err(e) => glib::g_warning!("preferences_dialog", "Unable to set download folder: {}", e),
                        }
                }

                dialog.destroy();
            }));

            chooser.present();
        }));

        let download_heading = granite::HeaderLabel::new(&gettext("Limits"));

        let max_downloads_label = gtk::Label::builder()
            .halign(gtk::Align::End)
            .margin_start(12)
            .label(gettext("Max simultaneous downloads:"))
            .build();
        let max_downloads_entry = gtk::SpinButton::with_range(1., 100., 1.);
        max_downloads_entry.set_hexpand(true);
        settings
            .bind("max-downloads", &max_downloads_entry, "value")
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        let download_speed_limit_label = gtk::Label::builder()
            .halign(gtk::Align::End)
            .margin_start(12)
            .label(gettext("Download speed limit (KBps):"))
            .build();
        let download_speed_limit_entry = gtk::SpinButton::with_range(0., 1000000., 25.);
        download_speed_limit_entry.set_hexpand(true);
        download_speed_limit_entry.set_tooltip_text(Some(&gettext("0 means unlimited")));
        settings
            .bind("download-speed-limit", &download_speed_limit_entry, "value")
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        let upload_speed_limit_label = gtk::Label::builder()
            .halign(gtk::Align::End)
            .margin_start(12)
            .label(gettext("Upload speed limit (KBps):"))
            .build();
        let upload_speed_limit_entry = gtk::SpinButton::with_range(0., 1000000., 25.);
        upload_speed_limit_entry.set_hexpand(true);
        upload_speed_limit_entry.set_tooltip_text(Some(&gettext("0 means unlimited")));
        settings
            .bind("upload-speed-limit", &upload_speed_limit_entry, "value")
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        let desktop_heading = granite::HeaderLabel::new(&gettext("Desktop Integration"));

        let hide_on_close_label = gtk::Label::builder()
            .halign(gtk::Align::End)
            .margin_start(12)
            .label(gettext("Continue downloads while closed:"))
            .build();
        let hide_on_close_switch = gtk::Switch::builder()
            .halign(gtk::Align::Start)
            .hexpand(true)
            .build();

        settings
            .bind("hide-on-close", &hide_on_close_switch, "active")
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        let general_grid = gtk::Grid::builder()
            .column_spacing(12)
            .row_spacing(6)
            .hexpand(true)
            .build();

        general_grid.attach(&location_heading, 0, 0, 1, 1);
        general_grid.attach(&location_chooser, 0, 1, 2, 1);

        general_grid.attach(&download_heading, 0, 2, 1, 1);
        general_grid.attach(&max_downloads_label, 0, 3, 1, 1);
        general_grid.attach(&max_downloads_entry, 1, 3, 1, 1);
        general_grid.attach(&download_speed_limit_label, 0, 4, 1, 1);
        general_grid.attach(&download_speed_limit_entry, 1, 4, 1, 1);
        general_grid.attach(&upload_speed_limit_label, 0, 5, 1, 1);
        general_grid.attach(&upload_speed_limit_entry, 1, 5, 1, 1);

        general_grid.attach(&desktop_heading, 0, 7, 1, 1);
        general_grid.attach(&hide_on_close_label, 0, 8, 1, 1);
        general_grid.attach(&hide_on_close_switch, 1, 8, 1, 1);

        general_grid
    }

    fn create_advanced_settings_widgets(&self) -> gtk::Grid {
        gtk::Grid::builder()
            .column_spacing(12)
            .row_spacing(6)
            .hexpand(true)
            .build()
    }
}
