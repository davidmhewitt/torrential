use std::path::PathBuf;

use granite::prelude::PlaceholderExt;
use gtk::{gio::ThemedIcon, prelude::*, FileFilter};
use i18n_embed::{
    fluent::{fluent_language_loader, FluentLanguageLoader},
    DesktopLanguageRequester,
};
use relm4::{
    actions::*,
    component::{AsyncComponent, AsyncController},
    factory::FactoryVecDeque,
    gtk::{self, gio},
    prelude::AsyncComponentController,
    Component, ComponentController, ComponentParts, ComponentSender, Controller, RelmApp,
    SimpleComponent,
};
use relm4_components::open_dialog::*;
use rust_embed::RustEmbed;

mod header;
use header::{HeaderModel, HeaderOutput};

mod preferences_window;
use preferences_window::{PreferencesWindowInput, PreferencesWindowModel};

mod torrent;
use torrent::Torrent;

mod toast;
use toast::{Toast, ToastMsg};

mod transmission;
use transmission::{Transmission, TransmissionInput, TransmissionOutput};

mod utils;

use transmission_client::TorrentFiles;

#[derive(RustEmbed)]
#[folder = "i18n"]
struct Localizations;

lazy_static::lazy_static! {
    static ref STATIC_LANGUAGE_LOADER: FluentLanguageLoader = {
        fluent_language_loader!()
    };
}

#[macro_export]
macro_rules! fl {
    ($message_id:literal) => {{
        i18n_embed_fl::fl!($crate::STATIC_LANGUAGE_LOADER, $message_id)
    }};

    ($message_id:literal, $($args:expr),*) => {{
        i18n_embed_fl::fl!($crate::STATIC_LANGUAGE_LOADER, $message_id, $($args), *)
    }};
}

struct App {
    view: FactoryVecDeque<Torrent>,
    transmission: AsyncController<Transmission>,
    header: Controller<HeaderModel>,
    prefs_dialog: Controller<PreferencesWindowModel>,
    open_dialog: Controller<OpenDialog>,
    toast: Controller<Toast>,
    context_popover: gtk::PopoverMenu,
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

    RightClickTorrent(f64, f64),

    OpenPrefsWindow,
    ClosePrefsWindow,
    None,
    RemoveSelected,
    PauseSelectedTorrents,
    ResumeSelectedTorrents,
    CopySelectedMagnet,
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

            gtk::Overlay {
                #[name="toplevel_box"]
                add_overlay = &gtk::Box {
                    set_orientation: gtk::Orientation::Vertical,

                    #[local_ref]
                    torrent_box -> gtk::ListBox {
                        set_selection_mode: gtk::SelectionMode::Multiple,
                        set_activate_on_single_click: false,
                        add_css_class: granite::STYLE_CLASS_RICH_LIST,
                        #[wrap(Some)]
                        set_placeholder = &gtk::Stack {
                            add_child = &granite::Placeholder {
                                set_title: &fl!("no-torrents-title"),
                                set_description: &fl!("no-torrents-subtitle"),
                                append_button[&fl!("action-open"), &fl!("action-open-description")] = &ThemedIcon::new("folder") {} -> {
                                    set_action_name: Some(&OpenAction::action_name()),
                                },
                                append_button[&fl!("action-prefs"), &fl!("action-prefs-description")] = &ThemedIcon::new("open-menu") {} -> {
                                    set_action_name: Some(&PreferencesAction::action_name()),
                                },
                            },
                        },

                        add_controller = gtk::GestureClick {
                            set_button: gtk::gdk::BUTTON_SECONDARY,
                            connect_released[sender] => move |_, _, x, y| {
                                sender.input(AppInput::RightClickTorrent(x, y));
                            }
                        }
                    }
                },

                add_overlay = app.toast.widget(),
            }
        }
    }

    fn init(
        _init: Self::Init,
        root: Self::Root,
        sender: ComponentSender<Self>,
    ) -> ComponentParts<Self> {
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

        let toast = Toast::builder()
            .launch(())
            .forward(sender.input_sender(), |response| match response {});

        let context_popover = gtk::PopoverMenu::builder()
            .halign(gtk::Align::Start)
            .has_arrow(false)
            .position(gtk::PositionType::Bottom)
            .build();

        let app = App {
            view,
            header,
            transmission,
            prefs_dialog,
            open_dialog,
            context_popover,
            toast,
        };

        let torrent_box = app.view.widget();

        let widgets = view_output!();
        app.context_popover.set_parent(&widgets.toplevel_box);

        let prefs_sender = sender.clone();
        let preferences_action: RelmAction<PreferencesAction> =
            RelmAction::new_stateless(move |_| {
                prefs_sender.input(AppInput::OpenPrefsWindow);
            });

        let open_sender = sender.clone();
        let open_action: RelmAction<OpenAction> = RelmAction::new_stateless(move |_| {
            open_sender.input(AppInput::ShowOpenDialog);
        });

        let remove_sender = sender.clone();
        let remove_selected_action: RelmAction<RemoveSelectedAction> =
            RelmAction::new_stateless(move |_| {
                remove_sender.input(AppInput::RemoveSelected);
            });

        let pause_sender = sender.clone();
        let pause_selected_action: RelmAction<PauseSelectedAction> =
            RelmAction::new_stateless(move |_| {
                pause_sender.input(AppInput::PauseSelectedTorrents);
            });

        let resume_sender = sender.clone();
        let resume_selected_action: RelmAction<ResumeSelectedAction> =
            RelmAction::new_stateless(move |_| {
                resume_sender.input(AppInput::ResumeSelectedTorrents);
            });

        let copy_magnet_sender = sender.clone();
        let copy_magnet_action: RelmAction<CopySelectedMagnetAction> =
            RelmAction::new_stateless(move |_| {
                copy_magnet_sender.input(AppInput::CopySelectedMagnet);
            });

        let mut group = RelmActionGroup::<WindowActionGroup>::new();
        group.add_action(preferences_action);
        group.add_action(open_action);
        group.add_action(pause_selected_action);
        group.add_action(resume_selected_action);
        group.add_action(remove_selected_action);
        group.add_action(copy_magnet_action);
        group.register_for_widget(&widgets.main_window);

        widgets.load_window_size();

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
                .emit(TransmissionInput::PauseTorrents(vec![hash])),
            AppInput::PauseSelectedTorrents => {
                let mut hashes = vec![];
                let items = self.view.guard().widget().selected_rows();
                for item in items {
                    if let Some(torrent) = self.view.guard().get(item.index() as usize) {
                        hashes.push(torrent.hash.clone());
                    }
                }

                self.transmission
                    .emit(TransmissionInput::PauseTorrents(hashes));
            }
            AppInput::ResumeTorrent(hash) => self
                .transmission
                .emit(TransmissionInput::ResumeTorrents(vec![hash])),
            AppInput::ResumeSelectedTorrents => {
                let mut hashes = vec![];
                let items = self.view.guard().widget().selected_rows();
                for item in items {
                    if let Some(torrent) = self.view.guard().get(item.index() as usize) {
                        hashes.push(torrent.hash.clone());
                    }
                }

                self.transmission
                    .emit(TransmissionInput::ResumeTorrents(hashes));
            }
            AppInput::RemoveSelected => {
                let mut hashes = vec![];
                let items = self.view.guard().widget().selected_rows();
                for item in items {
                    if let Some(torrent) = self.view.guard().get(item.index() as usize) {
                        hashes.push(torrent.hash.clone());
                    }
                }

                self.transmission
                    .emit(TransmissionInput::RemoveTorrents(hashes));
            }
            AppInput::CopySelectedMagnet => {
                let items = self.view.guard().widget().selected_rows();
                if items.len() == 1 {
                    if let Some(torrent) = self.view.guard().get(items[0].index() as usize) {
                        let clipboard = gtk::gdk::Display::default().unwrap().clipboard();
                        clipboard.set_text(&torrent.magnet_link);
                        self.toast
                            .emit(ToastMsg::Show(fl!("magnet-copied-notification")));
                    }
                }
            }
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
            AppInput::RightClickTorrent(x, y) => {
                let guarded_view = self.view.guard();
                let torrent_box = guarded_view.widget();

                let clicked_row = match torrent_box.row_at_y(y as i32) {
                    Some(row) => row,
                    None => return,
                };

                let mut found = false;
                for row in torrent_box.selected_rows() {
                    if row.eq(&clicked_row) {
                        found = true;
                        break;
                    }
                }

                if !found {
                    torrent_box.unselect_all();
                    torrent_box.select_row(Some(&clicked_row));
                }

                let items = torrent_box.selected_rows();
                let mut all_paused = true;
                for item in &items {
                    let torrent = guarded_view.get(item.index() as usize).unwrap();
                    if torrent.state != torrent::TorrentState::Stopped {
                        all_paused = false;
                        break;
                    }
                }

                let menu = gtk::gio::Menu::new();
                menu.append(
                    Some(&fl!("action-remove")),
                    Some(&RemoveSelectedAction::action_name()),
                );

                if all_paused {
                    menu.append(
                        Some(&fl!("action-resume")),
                        Some(&ResumeSelectedAction::action_name()),
                    );
                } else {
                    menu.append(
                        Some(&fl!("action-pause")),
                        Some(&PauseSelectedAction::action_name()),
                    );
                }

                if items.len() < 2 {
                    if let Some(selected_torrent) = guarded_view.get(items[0].index() as usize) {
                        if selected_torrent.files.file_count > 1 {
                            menu.append(Some(&fl!("action-select-files")), None);
                        }
                    }

                    menu.append(
                        Some(&fl!("action-copy-magnet")),
                        Some(&CopySelectedMagnetAction::action_name()),
                    );
                    menu.append(Some(&fl!("action-show-in-filemanager")), None);
                }

                let rect = gtk::gdk::Rectangle::new(x as i32, y as i32, 0, 0);
                self.context_popover.set_pointing_to(Some(&rect));
                self.context_popover.set_menu_model(Some(&menu));
                self.context_popover.popup();
            }
            AppInput::None => {}
        }
    }

    fn shutdown(&mut self, widgets: &mut Self::Widgets, _output: relm4::Sender<Self::Output>) {
        widgets.save_window_size().unwrap();
    }
}

impl AppWidgets {
    fn save_window_size(&self) -> Result<(), gtk::glib::BoolError> {
        let settings = gio::Settings::new("com.github.davidmhewitt.torrential.settings");
        let (width, height) = self.main_window.default_size();

        settings
            .set_int("window-width", width)
            .expect("Failed to save window width");
        settings
            .set_int("window-height", height)
            .expect("Failed to save window height");

        settings.set_boolean("window-maximized", self.main_window.is_maximized())?;

        Ok(())
    }

    fn load_window_size(&self) {
        let settings = gio::Settings::new("com.github.davidmhewitt.torrential.settings");
        let width = settings.int("window-width");
        let height = settings.int("window-height");

        self.main_window.set_default_size(width, height);

        if settings.boolean("window-maximized") {
            self.main_window.maximize();
        }
    }
}

fn torrent_file_filters() -> Vec<FileFilter> {
    let all_files_filter = FileFilter::new();
    all_files_filter.set_name(Some(&fl!("all-files-filter-description")));
    all_files_filter.add_pattern("*");

    let torrent_files_filter = FileFilter::new();
    torrent_files_filter.add_mime_type("application/x-bittorrent");
    torrent_files_filter.set_name(Some(&fl!("torrent-files-filter-description")));

    vec![torrent_files_filter, all_files_filter]
}

relm4::new_action_group!(WindowActionGroup, "win");
relm4::new_stateless_action!(PreferencesAction, WindowActionGroup, "preferences");
relm4::new_stateless_action!(PauseSelectedAction, WindowActionGroup, "pause-selected");
relm4::new_stateless_action!(ResumeSelectedAction, WindowActionGroup, "resume-selected");
relm4::new_stateless_action!(RemoveSelectedAction, WindowActionGroup, "remove-selected");
relm4::new_stateless_action!(CopySelectedMagnetAction, WindowActionGroup, "copy-magnet");
relm4::new_stateless_action!(OpenAction, WindowActionGroup, "open");
relm4::new_stateless_action!(QuitAction, WindowActionGroup, "quit");

fn main() {
    let requested_languages = DesktopLanguageRequester::requested_languages();

    let _result = i18n_embed::select(
        &*STATIC_LANGUAGE_LOADER,
        &Localizations,
        &requested_languages,
    );

    let app = RelmApp::new("com.github.davidmhewitt.torrential");
    app.run::<App>(());
}
