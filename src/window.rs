use gettextrs::gettext;
use gtk::subclass::prelude::*;
use gtk::{gio, gio::Settings, glib, prelude::*};
use once_cell::sync::OnceCell;

mod imp {
    use crate::welcome::WelcomeView;

    use super::*;

    #[derive(Debug, Default)]
    pub struct TorrentialWindow {
        pub settings: OnceCell<Settings>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for TorrentialWindow {
        const NAME: &'static str = "TorrentialWindow";
        type Type = super::TorrentialWindow;
        type ParentType = gtk::ApplicationWindow;
    }

    impl ObjectImpl for TorrentialWindow {
        fn constructed(&self) {
            self.parent_constructed();

            let obj = self.obj();

            obj.setup_settings();
            obj.load_window_size();

            let mode_switch = granite::ModeSwitch::builder()
                .primary_icon_name("display-brightness-symbolic")
                .secondary_icon_name("weather-clear-night-symbolic")
                .primary_icon_tooltip_text(gettext("Light Background"))
                .secondary_icon_tooltip_text(gettext("Dark Background"))
                .valign(gtk::Align::Center)
                .build();

            let gtk_settings = gtk::Settings::default().expect("Unable to get GtkSettings object");
            mode_switch
                .bind_property("active", &gtk_settings, "gtk-application-prefer-dark-theme")
                .bidirectional()
                .build();

            let headerbar = gtk::HeaderBar::builder().show_title_buttons(true).build();

            headerbar.style_context().add_class("default-decoration");
            headerbar.pack_end(&mode_switch);

            obj.set_titlebar(Some(&headerbar));
            obj.set_child(Some(&WelcomeView::new()));
        }
    }
    impl WidgetImpl for TorrentialWindow {}
    impl WindowImpl for TorrentialWindow {
        fn close_request(&self) -> glib::signal::Inhibit {
            self.obj()
                .save_window_size()
                .expect("Failed to save window state");

            self.parent_close_request()
        }
    }
    impl ApplicationWindowImpl for TorrentialWindow {}
}

glib::wrapper! {
    pub struct TorrentialWindow(ObjectSubclass<imp::TorrentialWindow>)
        @extends gtk::Widget, gtk::Window, gtk::ApplicationWindow,        @implements gio::ActionGroup, gio::ActionMap;
}

impl TorrentialWindow {
    pub fn new<P: glib::IsA<gtk::Application>>(application: &P) -> Self {
        glib::Object::builder()
            .property("application", application)
            .property("title", "Elementary Rust Sample")
            .build()
    }

    fn setup_settings(&self) {
        let settings = Settings::new("com.github.davidmhewitt.torrential.settings");
        self.imp()
            .settings
            .set(settings)
            .expect("`settings` should not be set before calling `setup_settings`.");
    }

    fn settings(&self) -> &Settings {
        self.imp()
            .settings
            .get()
            .expect("`settings` should be set in `setup_settings`.")
    }

    pub fn save_window_size(&self) -> Result<(), glib::BoolError> {
        let size = self.default_size();

        self.settings().set_int("window-width", size.0)?;
        self.settings().set_int("window-height", size.1)?;
        self.settings()
            .set_boolean("is-maximized", self.is_maximized())?;

        Ok(())
    }

    fn load_window_size(&self) {
        let width = self.settings().int("window-width");
        let height = self.settings().int("window-height");
        let is_maximized = self.settings().boolean("is-maximized");

        self.set_default_size(width, height);

        if is_maximized {
            self.maximize();
        }
    }
}
