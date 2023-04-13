use gettextrs::gettext;
use gtk::gio::ActionEntry;
use gtk::glib::{clone, g_warning, MainContext, VariantTy};
use gtk::subclass::prelude::*;
use gtk::{gio, gio::Settings, glib, prelude::*};
use int_enum::IntEnum;
use once_cell::sync::OnceCell;

use crate::application::TorrentialApplication;
use crate::widgets::TorrentListBox;

#[repr(u8)]
#[derive(Copy, Clone, IntEnum)]
pub enum FilterType {
    All = 0,
    Downloading = 1,
    Seeding = 2,
    Paused = 3,
    Search = 4,
}

impl ToVariant for FilterType {
    fn to_variant(&self) -> glib::Variant {
        (*self as u8).to_variant()
    }
}

mod imp {
    use super::*;

    #[derive(Debug, Default)]
    pub struct TorrentialWindow {
        pub settings: OnceCell<Settings>,
        pub listbox: OnceCell<TorrentListBox>,
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
            obj.setup_gactions();

            obj.set_titlebar(Some(&obj.build_headerbar()));

            let listbox = TorrentListBox::new();
            let listbox_scroll = gtk::ScrolledWindow::builder().child(&listbox).build();
            obj.imp()
                .listbox
                .set(listbox)
                .expect("Can only set listbox once");

            let container = gtk::Box::new(gtk::Orientation::Vertical, 0);
            // TODO: container.append(infobar);
            container.append(&listbox_scroll);

            // TODO: Toast overlay

            obj.set_child(Some(&container));
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
            .action_name("win.open")
            .tooltip_text(gettext("Open .torrent files"))
            .build();

        open_button.add_css_class(granite::STYLE_CLASS_LARGE_ICONS);
        headerbar.pack_start(&open_button);

        let magnet_button = gtk::MenuButton::builder()
            .icon_name("open-magnet")
            .popover(&self.build_magnet_popover())
            .tooltip_text(gettext("Open magnet link"))
            .build();

        magnet_button.add_css_class(granite::STYLE_CLASS_LARGE_ICONS);
        headerbar.pack_start(&magnet_button);

        let search_entry = gtk::SearchEntry::builder()
            .hexpand(true)
            .placeholder_text(gettext("Search Torrents"))
            .sensitive(false)
            .valign(gtk::Align::Center)
            .build();

        search_entry.connect_changed(clone!(@weak self as win => move |entry| {
            let text = if entry.text().is_empty() {
                None
            } else {
                Some(entry.text())
            };

            win.listbox().filter_torrents(&FilterType::Search.to_variant(), text)
        }));

        let view_mode_model = gio::Menu::new();
        view_mode_model.append(
            Some(&gettext("All")),
            Some(&gio::Action::print_detailed_name(
                "win.filter",
                Some(&FilterType::All.to_variant()),
            )),
        );

        view_mode_model.append(
            Some(&gettext("Downloading")),
            Some(&gio::Action::print_detailed_name(
                "win.filter",
                Some(&FilterType::Downloading.to_variant()),
            )),
        );

        view_mode_model.append(
            Some(&gettext("Seeding")),
            Some(&gio::Action::print_detailed_name(
                "win.filter",
                Some(&FilterType::Seeding.to_variant()),
            )),
        );

        view_mode_model.append(
            Some(&gettext("Paused")),
            Some(&gio::Action::print_detailed_name(
                "win.filter",
                Some(&FilterType::Paused.to_variant()),
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

        headerbar.into()
    }

    fn setup_gactions(&self) {
        let filter_action: ActionEntry<TorrentialWindow> = gio::ActionEntry::builder("filter")
            .parameter_type(Some(VariantTy::BYTE))
            .state(FilterType::All.to_variant())
            .activate(move |win: &Self, action, param| {
                let param = param.expect("No parameter sent to filter action");
                win.listbox().filter_torrents(param, None);
                action.set_state(param.clone());
            })
            .build();

        let open_action = gio::ActionEntry::builder("open")
            .activate(move |win: &Self, _, _| {
                let all_files_filter = gtk::FileFilter::new();
                all_files_filter.set_name(Some(&gettext("All files")));
                all_files_filter.add_pattern("*");

                let torrent_files_filter = gtk::FileFilter::new();
                torrent_files_filter.set_name(Some(&gettext("Torrent files")));
                torrent_files_filter.add_mime_type("application/x-bittorrent");

                let filters = gio::ListStore::new(all_files_filter.type_());
                filters.append(&all_files_filter);
                filters.append(&torrent_files_filter);

                let file_dialog = gtk::FileDialog::builder()
                    .filters(&filters)
                    .title(gettext("Open some torrents"))
                    .build();

                let main_context = MainContext::default();
                main_context.spawn_local(clone!(@weak win, @strong file_dialog => async move {
                    let file_model = file_dialog.open_multiple_future(Some(&win)).await;
                    match file_model {
                        Ok(files) => win.add_files(files),
                        Err(e) => g_warning!("window", "Error getting files from file dialog: {}", e),
                    }
                }));
            })
            .build();

        self.add_action_entries([filter_action, open_action]);
    }

    fn add_files(&self, files: gio::ListModel) {
        // TODO: add the files
        println!("{}", files.n_items());
    }

    fn build_magnet_popover(&self) -> gtk::Popover {
        let entry = gtk::Entry::new();

        let label = gtk::Label::builder()
            .label(gettext("Magnet URL:"))
            .halign(gtk::Align::Start)
            .build();

        let add_button = gtk::Button::builder()
            .label(gettext("Add Magnet Link"))
            .sensitive(entry.text().trim() != "")
            .build();

        let content_box = gtk::Box::builder()
            .margin_bottom(6)
            .margin_end(6)
            .margin_start(6)
            .margin_top(6)
            .build();

        content_box.append(&label);
        content_box.append(&entry);
        content_box.append(&add_button);

        let popover = gtk::Popover::builder().child(&content_box).build();
        popover.connect_visible_notify(clone!(@weak entry => move |popover| {
            if !popover.is_visible() {
                return;
            }

            let clipboard = gtk::gdk::Display::default()
                .expect("Unable to get display")
                .clipboard();

            let main_context = MainContext::default();
            main_context.spawn_local(clone!(@weak entry => async move {
                if let Ok(Some(text)) = clipboard.read_text_future().await {
                    if text.starts_with("magnet:") {
                        entry.set_text(&text);
                    }
                }
            }));
        }));

        entry.connect_changed(clone!(@weak add_button => move |entry| {
            add_button.set_sensitive(entry.text().trim() != "");
        }));

        entry.connect_activate(clone!(@weak add_button => move |_| {
            add_button.activate();
        }));

        add_button.connect_clicked(clone!(@weak popover => move |_| {
            // TODO: Add the torrent
            popover.popdown();
        }));

        popover
    }

    fn listbox(&self) -> &TorrentListBox {
        self.imp()
            .listbox
            .get()
            .expect("`listbox` fetched before init")
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

impl Default for TorrentialWindow {
    fn default() -> Self {
        TorrentialApplication::default()
            .active_window()
            .unwrap()
            .downcast()
            .unwrap()
    }
}
