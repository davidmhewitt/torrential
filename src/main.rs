use gtk::prelude::{GtkWindowExt, OrientableExt, WidgetExt};
use relm4::{
    actions::{RelmAction, RelmActionGroup},
    component::{AsyncComponent, AsyncController},
    factory::FactoryVecDeque,
    gtk::{self},
    prelude::AsyncComponentController,
    Component, ComponentController, ComponentParts, ComponentSender, Controller, RelmApp,
    SimpleComponent,
};

mod header;
use header::{HeaderModel, HeaderOutput};

mod preferences_window;
use preferences_window::{PreferencesWindowInput, PreferencesWindowModel};

mod torrent;
use torrent::Torrent;

mod transmission;
use transmission::{Transmission, TransmissionInput, TransmissionOutput};

use transmission_client::TorrentFiles;

struct App {
    view: FactoryVecDeque<Torrent>,
    transmission: AsyncController<Transmission>,
    header: Controller<HeaderModel>,
    prefs_dialog: Controller<PreferencesWindowModel>,
}

#[derive(Debug)]
enum AppInput {
    TorrentsChanged(Vec<transmission_client::Torrent>),
    PauseTorrent(String),
    ResumeTorrent(String),
    GetTorrentFiles(i32),
    TorrentFileListChanged(TorrentFiles),
    OpenPrefsWindow,
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
                    add_css_class: granite::STYLE_CLASS_RICH_LIST,
                }
            },
        }
    }

    fn init(
        _init: Self::Init,
        root: Self::Root,
        sender: ComponentSender<Self>,
    ) -> ComponentParts<Self> {
        tr::tr_init!("/usr/share/locale");

        granite::init();

        let seeding_css = gtk::CssProvider::new();
        seeding_css.load_from_data("progressbar.seeding progress { background-color: @LIME_300; }");

        gtk::style_context_add_provider_for_display(
            &gtk::gdk::Display::default().unwrap(),
            &seeding_css,
            gtk::STYLE_PROVIDER_PRIORITY_USER,
        );

        let view =
            FactoryVecDeque::builder()
                .launch_default()
                .forward(sender.input_sender(), |msg| match msg {
                    torrent::TorrentOutput::Pause(hash) => AppInput::PauseTorrent(hash),
                    torrent::TorrentOutput::Resume(hash) => AppInput::ResumeTorrent(hash),
                    torrent::TorrentOutput::GetFiles(id) => AppInput::GetTorrentFiles(id),
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
                    TransmissionOutput::FileListChanged(files) => {
                        AppInput::TorrentFileListChanged(files)
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

        let prefs_dialog = PreferencesWindowModel::builder()
            .transient_for(&root)
            .launch(true)
            .forward(sender.input_sender(), |msg| match msg {});

        let app = App {
            view,
            header,
            transmission,
            prefs_dialog,
        };

        let torrent_box = app.view.widget();

        let widgets = view_output!();

        let preferences_action: RelmAction<PreferencesAction> =
            RelmAction::new_stateless(move |_| {
                (&sender).input(AppInput::OpenPrefsWindow);
            });

        let mut group = RelmActionGroup::<WindowActionGroup>::new();
        group.add_action(preferences_action);
        group.register_for_widget(&widgets.main_window);

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
            AppInput::GetTorrentFiles(id) => {
                self.transmission.emit(TransmissionInput::GetFiles(id))
            }
            AppInput::TorrentFileListChanged(files) => {
                let mut guarded_view = self.view.guard();
                for torrent in guarded_view.iter_mut() {
                    if torrent.id == files.id {
                        torrent.set_files(files);
                        break;
                    }
                }
            }
            AppInput::OpenPrefsWindow => {
                self.prefs_dialog.emit(PreferencesWindowInput::Open);
            }
            AppInput::None => {}
        }
    }
}

relm4::new_action_group!(WindowActionGroup, "win");
relm4::new_stateless_action!(PreferencesAction, WindowActionGroup, "preferences");
relm4::new_stateless_action!(QuitAction, WindowActionGroup, "quit");

fn main() {
    env_logger::init();

    let app = RelmApp::new("relm4.test.simple");
    app.run::<App>(());
}
