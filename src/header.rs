use gtk::prelude::{ButtonExt, WidgetExt};
use relm4::gtk;
use relm4::ComponentParts;
use relm4::SimpleComponent;

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
        }
    }

    fn init(
        _init: Self::Init,
        root: Self::Root,
        sender: relm4::ComponentSender<Self>,
    ) -> relm4::ComponentParts<Self> {
        let model = Self;
        let widgets = view_output!();

        ComponentParts { model, widgets }
    }
}
