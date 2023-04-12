use gtk::glib::VariantTy;
use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::{gio, glib};

use crate::TorrentialWindow;

mod imp {
    use granite::traits::SettingsExt;
    use gtk::glib::clone;

    use super::*;

    #[derive(Debug, Default)]
    pub struct TorrentialApplication {}

    #[glib::object_subclass]
    impl ObjectSubclass for TorrentialApplication {
        const NAME: &'static str = "TorrentialApplication";
        type Type = super::TorrentialApplication;
        type ParentType = gtk::Application;
    }

    impl ObjectImpl for TorrentialApplication {
        fn constructed(&self) {
            self.parent_constructed();
            let obj = self.obj();
            obj.setup_gactions();
            obj.set_accels_for_action("app.quit", &["<primary>q"]);
            obj.set_accels_for_action("app.preferences", &["<primary>comma"])
        }
    }

    impl ApplicationImpl for TorrentialApplication {
        fn activate(&self) {
            let application = self.obj();
            // Get the current window or create one if necessary
            let window = if let Some(window) = application.active_window() {
                window
            } else {
                let window = TorrentialWindow::new(&*application);
                window.upcast()
            };

            window.present();
        }

        fn startup(&self) {
            self.parent_startup();

            let gtk_settings =
                gtk::Settings::default().expect("Unable to get the GtkSettings object");
            let granite_settings =
                granite::Settings::default().expect("Unable to get the Granite settings object");
            gtk_settings.set_gtk_application_prefer_dark_theme(
                granite_settings.prefers_color_scheme() == granite::SettingsColorScheme::Dark,
            );

            granite_settings.connect_prefers_color_scheme_notify(
                clone!(@weak gtk_settings => move |granite_settings| {
                    gtk_settings.set_gtk_application_prefer_dark_theme(
                        granite_settings.prefers_color_scheme() == granite::SettingsColorScheme::Dark,
                    );
                }),
            );
        }
    }

    impl GtkApplicationImpl for TorrentialApplication {}
}

glib::wrapper! {
    pub struct TorrentialApplication(ObjectSubclass<imp::TorrentialApplication>)
        @extends gio::Application, gtk::Application,
        @implements gio::ActionGroup, gio::ActionMap;
}

impl TorrentialApplication {
    pub fn new(application_id: &str, flags: &gio::ApplicationFlags) -> Self {
        glib::Object::builder()
            .property("application-id", &application_id)
            .property("flags", flags)
            .build()
    }

    fn setup_gactions(&self) {
        let quit_action = gio::ActionEntry::builder("quit")
            .activate(move |app: &Self, _, _| app.quit())
            .build();

        let open_torrent_action = gio::ActionEntry::builder("show-torrent")
            .parameter_type(Some(VariantTy::INT32))
            .activate(move |_, _, param| {
                if param.is_some() {
                    // TODO: Open it!
                }
            })
            .build();

        let show_window_action = gio::ActionEntry::builder("show-window")
            .activate(move |app: &Self, _, _| {
                if let Some(window) = app.active_window() {
                    window.present();
                    window.present_with_time(0);
                }
            })
            .build();

        let preferences_action = gio::ActionEntry::builder("preferences")
            .activate(move |_, _, _| {
                // TODO: this
            })
            .build();

        self.add_action_entries([
            quit_action,
            open_torrent_action,
            show_window_action,
            preferences_action,
        ]);
    }
}