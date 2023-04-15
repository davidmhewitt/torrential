// TODO: Gtk.Dialog is deprecated, switch away from it
#![allow(deprecated)]

use gettextrs::gettext;
use granite::subclass::prelude::*;
use gtk::gio;
use gtk::glib;
use gtk::glib::Properties;
use gtk::prelude::*;
use std::cell::RefCell;

use crate::window::TorrentialWindow;

mod imp {
    use super::*;

    #[derive(Properties, Debug, Default)]
    #[properties(wrapper_type = super::PreferencesDialog)]
    pub struct PreferencesDialog {
        #[property(get, set)]
        window: RefCell<gtk::Window>,
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

            let _settings = gio::Settings::new("com.github.davidmhewitt.torrential.settings");

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

        let general_grid = gtk::Grid::builder()
            .column_spacing(12)
            .row_spacing(6)
            .hexpand(true)
            .build();

        general_grid.attach(&location_heading, 0, 0, 1, 1);
        general_grid.attach(&location_chooser, 0, 1, 2, 1);

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
