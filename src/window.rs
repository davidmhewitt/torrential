use gettextrs::gettext;
use gtk::subclass::prelude::*;
use gtk::{gio, gio::Settings, glib, prelude::*};
use once_cell::sync::OnceCell;

#[derive(Copy, Clone)]
enum FilterType {
    ALL = 0,
    DOWNLOADING = 1,
    SEEDING = 2,
    PAUSED = 3,
    _SEARCH = 4,
}

impl ToVariant for FilterType {
    fn to_variant(&self) -> glib::Variant {
        return (*self as u8).to_variant();
    }
}

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

            obj.set_titlebar(Some(&obj.build_headerbar()));
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
        @extends gtk::Widget, gtk::Window, gtk::ApplicationWindow,
        @implements gio::ActionGroup, gio::ActionMap;
}

impl TorrentialWindow {
    pub fn new<P: glib::IsA<gtk::Application>>(application: &P) -> Self {
        glib::Object::builder()
            .property("application", application)
            .property("title", "Torrential")
            .build()
    }

    fn build_headerbar(&self) -> gtk::Widget {
        let headerbar = gtk::HeaderBar::builder().show_title_buttons(true).build();

        let menu = gio::Menu::new();
        menu.append(Some(&gettext("_Preferences")), Some("app.preferences"));
        menu.append(Some(&gettext("_Quit")), Some("app.quit"));

        let menu_button = gtk::MenuButton::builder()
            .icon_name("open-menu")
            .menu_model(&menu)
            .primary(true)
            .tooltip_text(gettext("Application menu"))
            .build();

        menu_button.add_css_class(granite::STYLE_CLASS_LARGE_ICONS);
        headerbar.pack_end(&menu_button);

        let open_button = gtk::Button::builder()
            .icon_name("document-open")
            .action_name("app.open")
            .tooltip_text(gettext("Open .torrent file"))
            .build();

        open_button.add_css_class(granite::STYLE_CLASS_LARGE_ICONS);
        headerbar.pack_start(&open_button);

        let magnet_button = gtk::Button::builder()
            .icon_name("open-magnet")
            .action_name("app.open-magnet")
            .tooltip_text(gettext("Open magnet link"))
            .build();

        open_button.add_css_class(granite::STYLE_CLASS_LARGE_ICONS);
        headerbar.pack_start(&magnet_button);

        let search_entry = gtk::SearchEntry::builder()
            .hexpand(true)
            .placeholder_text(gettext("Search Torrents"))
            .sensitive(false)
            .valign(gtk::Align::Center)
            .build();

        search_entry.connect_changed(move |_| {
            // TODO: this
        });

        let view_mode_model = gio::Menu::new();
        view_mode_model.append(
            Some(&gettext("All")),
            Some(&gio::Action::print_detailed_name(
                "app.filter",
                Some(&FilterType::ALL.to_variant()),
            )),
        );

        view_mode_model.append(
            Some(&gettext("Downloading")),
            Some(&gio::Action::print_detailed_name(
                "app.filter",
                Some(&FilterType::DOWNLOADING.to_variant()),
            )),
        );

        view_mode_model.append(
            Some(&gettext("Seeding")),
            Some(&gio::Action::print_detailed_name(
                "app.filter",
                Some(&FilterType::SEEDING.to_variant()),
            )),
        );

        view_mode_model.append(
            Some(&gettext("Paused")),
            Some(&gio::Action::print_detailed_name(
                "app.filter",
                Some(&FilterType::PAUSED.to_variant()),
            )),
        );

        let view_mode_button = gtk::MenuButton::builder()
            .icon_name("filter")
            .menu_model(&view_mode_model)
            .tooltip_text(gettext("Filter"))
            .build();
        view_mode_button.add_css_class(granite::STYLE_CLASS_LARGE_ICONS);

        headerbar.pack_end(&view_mode_button);
        headerbar.set_title_widget(Some(&search_entry));

        return headerbar.into();
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
