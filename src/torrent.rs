use gtk::prelude::{ButtonExt, GridExt, WidgetExt};
use relm4::factory::FactoryComponent;
use relm4::gtk;

#[derive(Debug)]
#[tracker::track]
pub(crate) struct Torrent {
    pub hash: String,
    pub name: String,
    pub percent_done: f32,
    pub paused: bool,
}

#[derive(Debug)]
pub enum TorrentMsg {
    Pause,
    Resume,
}

#[derive(Debug)]
pub enum TorrentOutput {
    Pause(String),
    Resume(String),
}

#[relm4::factory(pub)]
impl FactoryComponent for Torrent {
    type Init = transmission_client::Torrent;
    type Input = TorrentMsg;
    type Output = TorrentOutput;
    type ParentWidget = gtk::ListBox;
    type CommandOutput = ();

    view! {
        gtk::Grid {
            set_column_spacing: 12,
            set_row_spacing: 3,

            attach[1, 0, 1, 1] = &gtk::Label {
                #[track = "self.changed(Torrent::name())"]
                set_text: &self.name,
                set_ellipsize: gtk::pango::EllipsizeMode::End,
                set_halign: gtk::Align::Start,
                add_css_class: granite_rs::STYLE_CLASS_H3_LABEL,
            },
            attach[1, 2, 1, 1] = &gtk::ProgressBar {
                #[track = "self.changed(Torrent::percent_done())"]
                set_fraction: self.percent_done.into(),
                set_hexpand: true,
            },
            attach[2, 1, 1, 4] = if self.paused {
                &gtk::Button {
                    set_icon_name: "media-playback-start-symbolic",
                    set_tooltip_text: Some(&gettextrs::gettext("Resume")),
                    add_css_class: granite_rs::STYLE_CLASS_ROUNDED,
                    connect_clicked => TorrentMsg::Resume,
                }
            } else {
                &gtk::Button {
                    set_icon_name: "media-playback-pause-symbolic",
                    set_tooltip_text: Some(&gettextrs::gettext("Pause")),
                    add_css_class: granite_rs::STYLE_CLASS_ROUNDED,
                    connect_clicked => TorrentMsg::Pause,
                }
            }
        }
    }

    fn init_model(
        init: Self::Init,
        _index: &Self::Index,
        _sender: relm4::prelude::FactorySender<Self>,
    ) -> Self {
        Self {
            hash: init.hash_string,
            name: init.name,
            percent_done: init.percent_done,
            paused: init.status == 0,
            tracker: Default::default(),
        }
    }

    fn update(&mut self, msg: Self::Input, sender: relm4::prelude::FactorySender<Self>) {
        self.reset();
        match msg {
            TorrentMsg::Pause => sender
                .output(TorrentOutput::Pause(self.hash.clone()))
                .unwrap(),
            TorrentMsg::Resume => sender
                .output(TorrentOutput::Resume(self.hash.clone()))
                .unwrap(),
        }
    }
}

impl Torrent {
    pub fn update(&mut self, torrent: &transmission_client::Torrent) {
        if self.hash != torrent.hash_string {
            self.hash.clone_from(&torrent.hash_string);
        }

        if self.name != torrent.name {
            self.set_name(torrent.name.clone());
        }

        if self.paused != (torrent.status == 0) {
            self.set_paused(torrent.status == 0);
        }

        self.set_percent_done(torrent.percent_done);
    }
}
