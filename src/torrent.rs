use gtk::gio::functions::content_type_get_icon;
use gtk::prelude::{ButtonExt, GridExt, WidgetExt};
use relm4::factory::FactoryComponent;
use relm4::gtk::gio::Icon;
use relm4::{gtk, RelmWidgetExt};
use tr::tr;
use transmission_client::TorrentFiles;

fn get_icon_type_for_files(files: &[transmission_client::File]) -> Icon {
    if files.len() > 1 {
        content_type_get_icon("inode/directory")
    // TODO: Implement this once content_type_guess supports passing NULL data
    // } else if files.len() == 1 {
    //     let content_type = content_type_guess(Some(&files[0].name), 0).0;
    //     content_type_get_icon(&content_type)
    } else {
        content_type_get_icon("application/x-bittorrent")
    }
}

#[derive(Debug)]
#[tracker::track]
pub(crate) struct Torrent {
    pub hash: String,
    pub id: i32,
    pub name: String,
    pub percent_done: f32,
    pub state: TorrentState,
    pub files: TorrentFiles,
    pub rate_download: i32,
    pub rate_upload: i32,
    pub eta: i64,
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
    GetFiles(i32),
}

fn get_pause_resume_text(state: &TorrentState) -> String {
    match state {
        TorrentState::Stopped => tr!("Resume"),
        _ => tr!("Pause"),
    }
}

fn generate_status_text(
    state: &TorrentState,
    rate_download: i32,
    rate_upload: i32,
    eta: i64,
) -> String {
    match state {
        TorrentState::Downloading | TorrentState::Seeding => {
            format!(
                "\u{2b07}{}/s \u{2b06}{}/s — {} remaining",
                gtk::glib::format_size(rate_download as u64),
                gtk::glib::format_size(rate_upload as u64),
                time_to_string(eta)
            )
        }
        TorrentState::Stopped => tr!("Paused"),
        TorrentState::CheckWaiting | TorrentState::DownloadWaiting | TorrentState::SeedWaiting => {
            tr!("Waiting in queue")
        }
        TorrentState::Checking => tr!("Checking"),
    }
}

fn time_to_string(total_seconds: i64) -> String {
    if total_seconds < 0 {
        return "...".to_string();
    }

    let seconds = (total_seconds % 60) as u64;
    let minutes = (total_seconds % 3600) / 60;
    let hours = (total_seconds % 86400) / 3600;
    let days = (total_seconds % (86400 * 30)) / 86400;

    let seconds_str = tr!("{} second" | "{} seconds" % seconds, seconds);
    let minutes_str = tr!("{} minute" | "{} minutes" % minutes, minutes);
    let hours_str = tr!("{} hour" | "{} hours" % hours, hours);
    let days_str = tr!("{} day" | "{} days" % days, days);

    if days > 0 {
        format!(
            "{}, {}, {}, {}",
            days_str, hours_str, minutes_str, seconds_str
        )
    } else if hours > 0 {
        format!("{}, {}, {}", hours_str, minutes_str, seconds_str)
    } else if minutes > 0 {
        format!("{}, {}", minutes_str, seconds_str)
    } else {
        seconds_str
    }
}

impl TorrentState {
    fn is_stopped(&self) -> bool {
        matches!(self, TorrentState::Stopped)
    }
}

#[derive(Debug, PartialEq)]
pub(crate) enum TorrentState {
    Stopped = 0,
    CheckWaiting = 1,
    Checking = 2,
    DownloadWaiting = 3,
    Downloading = 4,
    SeedWaiting = 5,
    Seeding = 6,
}

impl TryFrom<i32> for TorrentState {
    type Error = ();

    fn try_from(value: i32) -> Result<Self, Self::Error> {
        match value {
            0 => Ok(TorrentState::Stopped),
            1 => Ok(TorrentState::CheckWaiting),
            2 => Ok(TorrentState::Checking),
            3 => Ok(TorrentState::DownloadWaiting),
            4 => Ok(TorrentState::Downloading),
            5 => Ok(TorrentState::SeedWaiting),
            6 => Ok(TorrentState::Seeding),
            _ => Err(()),
        }
    }
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

            attach[0, 0, 1, 4] = &gtk::Image {
                #[track = "self.changed(Torrent::files())"]
                set_from_gicon: &get_icon_type_for_files(&self.files.files),
                set_pixel_size: 48,
            },

            attach[1, 0, 1, 1] = &gtk::Label {
                #[track = "self.changed(Torrent::name())"]
                set_text: &self.name,
                set_ellipsize: gtk::pango::EllipsizeMode::End,
                set_halign: gtk::Align::Start,
                add_css_class: granite::STYLE_CLASS_H3_LABEL,
            },

            attach[1, 1, 1, 1] = &gtk::Label {
                #[track = "self.changed(Torrent::state() | Torrent::rate_download() | Torrent::rate_upload() | Torrent::eta())"]
                set_text: &generate_status_text(&self.state, self.rate_download, self.rate_upload, self.eta),
                set_halign: gtk::Align::Start,
                add_css_class: granite::STYLE_CLASS_SMALL_LABEL,
            },

            attach[1, 2, 1, 1] = &gtk::ProgressBar {
                #[track = "self.changed(Torrent::percent_done())"]
                set_fraction: self.percent_done.into(),
                #[track = "self.changed(Torrent::state())"]
                set_class_active: ("seeding", self.state == TorrentState::Seeding),
                set_hexpand: true,
            },

            attach[2, 1, 1, 4] = if self.state.is_stopped() {
                &gtk::Button {
                    set_icon_name: "media-playback-start-symbolic",
                    set_tooltip_text: Some(&get_pause_resume_text(&self.state)),
                    add_css_class: granite::STYLE_CLASS_ROUNDED,
                    connect_clicked => TorrentMsg::Resume,
                }
            } else {
                &gtk::Button {
                    set_icon_name: "media-playback-pause-symbolic",
                    set_tooltip_text: Some(&get_pause_resume_text(&self.state)),
                    add_css_class: granite::STYLE_CLASS_ROUNDED,
                    connect_clicked => TorrentMsg::Pause,
                }
            }
        }
    }

    fn init_model(
        init: Self::Init,
        _index: &Self::Index,
        sender: relm4::prelude::FactorySender<Self>,
    ) -> Self {
        sender.output(TorrentOutput::GetFiles(init.id)).unwrap();

        Self {
            hash: init.hash_string,
            id: init.id,
            name: init.name,
            percent_done: init.percent_done,
            state: TorrentState::Stopped,
            tracker: Default::default(),
            files: Default::default(),
            rate_download: init.rate_download,
            rate_upload: init.rate_upload,
            eta: init.eta,
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
        self.reset();

        if self.hash != torrent.hash_string {
            self.hash.clone_from(&torrent.hash_string);
        }

        if self.id != torrent.id {
            self.id = torrent.id;
        }

        if self.name != torrent.name {
            self.set_name(torrent.name.clone());
        }

        self.set_state(torrent.status.try_into().unwrap_or(TorrentState::Stopped));
        self.set_percent_done(torrent.percent_done);

        self.set_rate_download(torrent.rate_download);
        self.set_rate_upload(torrent.rate_upload);
        self.set_eta(torrent.eta);
    }
}
