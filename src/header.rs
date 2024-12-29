use crate::fl;
use gtk::prelude::{ButtonExt, WidgetExt};
use relm4::gtk;
use relm4::ComponentParts;
use relm4::SimpleComponent;
use relm4_macros::menu;

pub struct HeaderModel;

#[derive(Debug)]
pub enum HeaderOutput {
    OpenTorrent,
    OpenMagnet,
}

#[relm4::component(pub)]
impl SimpleComponent for HeaderModel {
    type Init = ();
    type Input = ();
    type Output = HeaderOutput;

    view! {
        #[root]
        gtk::HeaderBar {
            set_show_title_buttons: true,
            #[wrap(Some)]
            set_title_widget = &gtk::SearchEntry {
                set_hexpand: true,
                set_placeholder_text: Some("Search Torrents"),
                set_valign: gtk::Align::Center,
            },

            pack_start = &gtk::Button {
                set_icon_name: "document-open",
                set_tooltip_text: Some("Open .torrent file"),
                connect_clicked[sender] => move |_| sender.output(HeaderOutput::OpenTorrent).unwrap(),
            },

            pack_start = &gtk::Button {
                set_icon_name: "open-magnet",
                set_tooltip_text: Some("Open magnet link"),
                connect_clicked[sender] => move |_| sender.output(HeaderOutput::OpenMagnet).unwrap(),
            },

            pack_end = &gtk::MenuButton {
                set_icon_name: "open-menu",
                set_tooltip_text: Some(&fl!("appmenu-tooltip")),
                set_menu_model: Some(&main_menu),
                set_primary: true,
            },
        }
    }

    fn init(
        _init: Self::Init,
        root: Self::Root,
        sender: relm4::ComponentSender<Self>,
    ) -> relm4::ComponentParts<Self> {
        menu! {
            main_menu: {
                &fl!("action-prefs") => crate::PreferencesAction,
                &fl!("action-quit") => crate::QuitAction,
            }
        }

        let model = Self;
        let widgets = view_output!();

        ComponentParts { model, widgets }
    }
}
