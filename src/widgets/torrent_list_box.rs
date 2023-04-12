use gettextrs::gettext;
use gtk::glib::Object;
use gtk::subclass::prelude::*;
use gtk::{glib, prelude::*};
use once_cell::sync::OnceCell;

mod imp {
    use granite::traits::PlaceholderExt;
    use gtk::{gdk::Key, gio::ThemedIcon, glib::clone};

    use super::*;

    #[derive(Debug, Default)]
    pub struct TorrentListBox {
        pub listbox: OnceCell<gtk::ListBox>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for TorrentListBox {
        const NAME: &'static str = "TorrentListBox";
        type Type = super::TorrentListBox;
        type ParentType = gtk::Box;
    }

    impl ObjectImpl for TorrentListBox {
        fn constructed(&self) {
            self.parent_constructed();

            let obj = self.obj();

            let welcome_placeholder = granite::Placeholder::builder()
                .title(gettext("No Torrents Added"))
                .description(gettext("Add a torrent file to begin downloading."))
                .build();

            let open_button = welcome_placeholder
                .append_button(
                    &ThemedIcon::new("folder"),
                    &gettext("Open Torrent"),
                    &gettext("Open a torrent file from your computer."),
                )
                .expect("Unable to create placeholder button");
            open_button.set_action_name(Some("app.open"));

            let preferences_button = welcome_placeholder
                .append_button(
                    &ThemedIcon::new("open-menu"),
                    &gettext("Preferences"),
                    &gettext("Set download folder and other preferences."),
                )
                .expect("Unable to create placeholder button");
            preferences_button.set_action_name(Some("app.preferences"));

            let search_placeholder = granite::Placeholder::builder()
                .icon(&ThemedIcon::new("edit-find-symbolic"))
                .build();

            let stack = gtk::Stack::new();
            stack.add_child(&welcome_placeholder);
            stack.add_child(&search_placeholder);
            stack.set_visible_child(&welcome_placeholder);

            let secondary_click_gesture = gtk::GestureClick::builder()
                .button(gtk::gdk::BUTTON_SECONDARY)
                .build();
            secondary_click_gesture.connect_released(
                clone!(@weak obj => move |_, n_press, x, y| obj.popup_menu(n_press, x, y)),
            );

            let key_controller = gtk::EventControllerKey::new();
            key_controller.connect_key_released(clone!(@weak obj => move |_, keyval, _, _| {
                match keyval {
                    Key::Delete | Key::BackSpace => {
                        // TODO: activate the action
                    },
                    _ => {}
                }
            }));

            let listbox = gtk::ListBox::builder()
                .activate_on_single_click(false)
                .hexpand(true)
                .vexpand(true)
                .selection_mode(gtk::SelectionMode::Multiple)
                .build();

            // TODO: Make sure we get this style class
            // listbox.add_css_class(granite::STYLE_CLASS_RICH_LIST);
            listbox.add_controller(key_controller);
            listbox.add_controller(secondary_click_gesture);
            listbox.set_placeholder(Some(&stack));

            obj.append(&listbox);

            obj.imp()
                .listbox
                .set(listbox)
                .expect("listbox should only be set once");
        }
    }
    impl WidgetImpl for TorrentListBox {}
    impl BoxImpl for TorrentListBox {}
}

glib::wrapper! {
    pub struct TorrentListBox(ObjectSubclass<imp::TorrentListBox>)
        @extends gtk::Widget, gtk::Box,
        @implements gtk::Orientable;
}

impl TorrentListBox {
    pub fn new() -> Self {
        Object::builder().build()
    }

    fn popup_menu(&self, _n_press: i32, _x: f64, _y: f64) {
        // TODO: stuff and things
    }
}

impl Default for TorrentListBox {
    fn default() -> Self {
        Self::new()
    }
}
