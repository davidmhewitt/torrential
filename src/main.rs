use gtk::prelude::{GtkWindowExt, OrientableExt, WidgetExt};
use relm4::{
    component::{AsyncComponent, AsyncController},
    factory::FactoryVecDeque,
    gtk::{self},
    prelude::AsyncComponentController,
    Component, ComponentController, ComponentParts, ComponentSender, Controller, RelmApp,
    SimpleComponent,
};

mod transmission;
use transmission::{Transmission, TransmissionInput, TransmissionOutput};

mod torrent;
use torrent::Torrent;

mod header;
use header::{HeaderModel, HeaderOutput};

struct App {
    view: FactoryVecDeque<Torrent>,
    transmission: AsyncController<Transmission>,
    header: Controller<HeaderModel>,
}

#[derive(Debug)]
enum AppInput {
    TorrentsChanged(Vec<transmission_client::Torrent>),
    PauseTorrent(String),
    ResumeTorrent(String),
    None,
}

#[relm4::component]
impl SimpleComponent for App {
    type Init = ();
    type Input = AppInput;
    type Output = ();

    view! {
        main_window = gtk::Window {
            set_default_size: (400, 100),
            set_titlebar: Some(app.header.widget()),

            gtk::Box {
                set_orientation: gtk::Orientation::Vertical,

                #[local_ref]
                torrent_box -> gtk::ListBox {
                    set_selection_mode: gtk::SelectionMode::Multiple,
                    set_activate_on_single_click: false,
                    add_css_class: granite_rs::STYLE_CLASS_RICH_LIST,
                }
            },
        }
    }

    fn init(
        _init: Self::Init,
        root: Self::Root,
        sender: ComponentSender<Self>,
    ) -> ComponentParts<Self> {
        granite_rs::init();

        let view =
            FactoryVecDeque::builder()
                .launch_default()
                .forward(sender.input_sender(), |msg| match msg {
                    torrent::TorrentOutput::Pause(hash) => AppInput::PauseTorrent(hash),
                    torrent::TorrentOutput::Resume(hash) => AppInput::ResumeTorrent(hash),
                });

        let transmission =
            Transmission::builder()
                .launch(())
                .forward(sender.input_sender(), |msg| match msg {
                    TransmissionOutput::TorrentsChanged(torrents) => {
                        AppInput::TorrentsChanged(torrents)
                    }
                    TransmissionOutput::ConnectionError(err) => {
                        println!("Connection error: {}", err);
                        AppInput::None
                    }
                });

        let header = HeaderModel::builder()
            .launch(())
            .forward(sender.input_sender(), |msg| match msg {
                HeaderOutput::OpenTorrent => {
                    println!("Open torrent");
                    AppInput::None
                }
                HeaderOutput::OpenMagnet => {
                    println!("Open magnet");
                    AppInput::None
                }
            });

        let app = App {
            view,
            header,
            transmission,
        };

        let torrent_box = app.view.widget();

        let widgets = view_output!();

        ComponentParts {
            model: app,
            widgets,
        }
    }

    fn update(&mut self, message: Self::Input, _sender: ComponentSender<Self>) {
        match message {
            AppInput::TorrentsChanged(new_torrents) => {
                let mut guarded_view = self.view.guard();
                let new_torrents_len = new_torrents.len();

                for (index, torrent) in new_torrents.into_iter().enumerate() {
                    if index >= guarded_view.len() {
                        guarded_view.push_back(torrent);
                        continue;
                    }

                    if let Some(torrent_container) = guarded_view.get_mut(index) {
                        torrent_container.update(&torrent);
                    }
                }

                if guarded_view.len() > new_torrents_len {
                    for _ in 0..(guarded_view.len() - new_torrents_len) {
                        guarded_view.pop_back();
                    }
                }
            }
            AppInput::PauseTorrent(hash) => self
                .transmission
                .emit(TransmissionInput::PauseTorrent(hash)),
            AppInput::ResumeTorrent(hash) => self
                .transmission
                .emit(TransmissionInput::ResumeTorrent(hash)),
            AppInput::None => {}
        }
    }
}

fn main() {
    env_logger::init();

    let app = RelmApp::new("relm4.test.simple");
    app.run::<App>(());
}
