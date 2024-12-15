use std::path::PathBuf;

use granite::prelude::PlaceholderExt;
use gtk::{gio::ThemedIcon, prelude::*, FileFilter};
use relm4::{
    actions::*,
    component::{AsyncComponent, AsyncController},
    factory::FactoryVecDeque,
    gtk,
    prelude::AsyncComponentController,
    Component, ComponentController, ComponentParts, ComponentSender, Controller, RelmApp,
    SimpleComponent,
};
use relm4_components::open_dialog::*;
use tr::tr;

mod header;
use header::{HeaderModel, HeaderOutput};

mod preferences_window;
use preferences_window::{PreferencesWindowInput, PreferencesWindowModel};

mod torrent;
use torrent::Torrent;

mod transmission;
use transmission::{Transmission, TransmissionInput, TransmissionOutput};

mod utils;

use transmission_client::TorrentFiles;

struct App {
    view: FactoryVecDeque<Torrent>,
    transmission: AsyncController<Transmission>,
    header: Controller<HeaderModel>,
    prefs_dialog: Controller<PreferencesWindowModel>,
    open_dialog: Controller<OpenDialog>,
}

#[derive(Debug)]
enum AppInput {
    TorrentsChanged(Vec<transmission_client::Torrent>),
    PauseTorrent(String),
    ResumeTorrent(String),
    GetTorrentFiles(i32),
    TorrentFileListChanged(TorrentFiles),

    ShowOpenDialog,
    OpenTorrent(PathBuf),

    OpenPrefsWindow,
    ClosePrefsWindow,
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
                    #[wrap(Some)]
                    set_placeholder = &gtk::Stack {
                        add_child = &granite::Placeholder {
                            set_title: &tr!("No torrents"),
                            set_description: &tr!("Add a torrent to begin downloading"),
                            append_button[&tr!("Open torrent"), &tr!("Open a torrent from a file on your computer")] = &ThemedIcon::new("folder") {} -> {
                                set_action_name: Some(&OpenAction::action_name()),
                            },
                            append_button[&tr!("Preferences"), &tr!("Set download folder and other preferences")] = &ThemedIcon::new("open-menu") {} -> {
                                set_action_name: Some(&PreferencesAction::action_name()),
                            },
                        },
                    },
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
                HeaderOutput::OpenTorrent => AppInput::ShowOpenDialog,
                HeaderOutput::OpenMagnet => {
                    println!("Open magnet");
                    AppInput::None
                }
            });

        let open_dialog = OpenDialog::builder()
            .transient_for_native(&root)
            .launch(OpenDialogSettings {
                filters: torrent_file_filters(),
                ..Default::default()
            })
            .forward(sender.input_sender(), |response| match response {
                OpenDialogResponse::Accept(path) => AppInput::OpenTorrent(path),
                OpenDialogResponse::Cancel => AppInput::None,
            });

        let prefs_dialog = PreferencesWindowModel::builder()
            .transient_for(&root)
            .launch(true)
            .forward(sender.input_sender(), |msg| match msg {
                preferences_window::PreferencesWindowOutput::Close => AppInput::ClosePrefsWindow,
            });

        let app = App {
            view,
            header,
            transmission,
            prefs_dialog,
            open_dialog,
        };

        let torrent_box = app.view.widget();

        let widgets = view_output!();

        let prefs_sender = sender.clone();
        let preferences_action: RelmAction<PreferencesAction> =
            RelmAction::new_stateless(move |_| {
                prefs_sender.input(AppInput::OpenPrefsWindow);
            });

        let open_action: RelmAction<OpenAction> = RelmAction::new_stateless(move |_| {
            sender.input(AppInput::ShowOpenDialog);
        });

        let mut group = RelmActionGroup::<WindowActionGroup>::new();
        group.add_action(preferences_action);
        group.add_action(open_action);
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
            AppInput::ShowOpenDialog => {
                self.open_dialog.emit(OpenDialogMsg::Open);
            }
            AppInput::OpenTorrent(path) => {
                self.transmission
                    .emit(TransmissionInput::AddTorrentFile(path));
            }
            AppInput::OpenPrefsWindow => {
                self.prefs_dialog.emit(PreferencesWindowInput::Open);
            }
            AppInput::ClosePrefsWindow => {
                self.transmission.emit(TransmissionInput::UpdateSettings);
            }
            AppInput::None => {}
        }
    }
}

fn torrent_file_filters() -> Vec<FileFilter> {
    let all_files_filter = FileFilter::new();
    all_files_filter.set_name(Some(&tr!("All files")));
    all_files_filter.add_pattern("*");

    let torrent_files_filter = FileFilter::new();
    torrent_files_filter.add_mime_type("application/x-bittorrent");
    torrent_files_filter.set_name(Some(&tr!("Torrent files")));

    vec![torrent_files_filter, all_files_filter]
}

relm4::new_action_group!(WindowActionGroup, "win");
relm4::new_stateless_action!(PreferencesAction, WindowActionGroup, "preferences");
relm4::new_stateless_action!(OpenAction, WindowActionGroup, "open");
relm4::new_stateless_action!(QuitAction, WindowActionGroup, "quit");

fn main() {
    env_logger::init();

    let app = RelmApp::new("com.github.davidmhewitt.torrential");
    app.run::<App>(());
}
