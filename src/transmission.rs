use std::{process::Stdio, time::Duration};

use nix::{sys::signal, unistd::Pid};
use relm4::{
    component::{AsyncComponent, AsyncComponentParts},
    gtk::{gio, prelude::SettingsExt},
};
use transmission_client::{
    Client, Encryption, SessionMutator, Torrent, TorrentFiles, TorrentMutator,
};

pub(crate) struct Transmission {
    tr_client: Option<Client>,
    transmission_process: Option<std::process::Child>,
    timer_handle: Option<tokio::task::JoinHandle<()>>,
}

#[derive(Debug)]
pub(crate) enum TransmissionOutput {
    ConnectionError(String),
    TorrentsChanged(Vec<Torrent>),
    FileListChanged(TorrentFiles),
}

#[derive(Debug)]
pub(crate) enum TransmissionInput {
    AddTorrentFile(String),
    UpdateTorrents,
    PauseTorrents(Vec<String>),
    ResumeTorrents(Vec<String>),
    GetFiles(i32),
    SetFilesWanted(String, i32, Vec<i32>, Vec<i32>),
    UpdateSettings,
    RemoveTorrents(Vec<String>),
}

impl Drop for Transmission {
    fn drop(&mut self) {
        // Send SIGINT to the transmission-daemon process
        if let Some(transmission_process) = self.transmission_process.as_mut() {
            signal::kill(
                Pid::from_raw(transmission_process.id() as i32),
                signal::SIGTERM,
            )
            .unwrap();

            transmission_process.wait().unwrap();
        }
    }
}

impl AsyncComponent for Transmission {
    type Widgets = ();
    type Root = ();

    type Init = ();
    type Input = TransmissionInput;
    type Output = TransmissionOutput;
    type CommandOutput = ();

    async fn init(
        _init: Self::Init,
        _root: Self::Root,
        sender: relm4::prelude::AsyncComponentSender<Self>,
    ) -> AsyncComponentParts<Self> {
        let tr_client = Client::default();

        let transmission_daemon = match std::process::Command::new("transmission-daemon")
            .stdout(Stdio::piped())
            .arg("--foreground")
            .spawn()
        {
            Ok(process) => Some(process),
            Err(e) => {
                sender
                    .output(TransmissionOutput::ConnectionError(format!(
                        "Error starting transmission-daemon: {}",
                        e
                    )))
                    .unwrap();
                return AsyncComponentParts {
                    model: Self {
                        tr_client: Some(tr_client),
                        transmission_process: None,
                        timer_handle: None,
                    },
                    widgets: (),
                };
            }
        };

        if let Ok(session) = tr_client.session().await {
            let settings = gio::Settings::new("com.github.davidmhewitt.torrential.settings");

            match settings.set_int("max-downloads", session.download_queue_size) {
                Ok(_) => {}
                Err(err) => {
                    log::error!("Error setting max downloads: {}", err);
                }
            }

            match settings.set_int(
                "download-speed-limit",
                if session.speed_limit_down_enabled {
                    session.speed_limit_down
                } else {
                    0
                },
            ) {
                Ok(_) => {}
                Err(err) => {
                    log::error!("Error setting download speed limit: {}", err);
                }
            }

            match settings.set_int(
                "upload-speed-limit",
                if session.speed_limit_up_enabled {
                    session.speed_limit_up
                } else {
                    0
                },
            ) {
                Ok(_) => {}
                Err(err) => {
                    log::error!("Error setting upload speed limit: {}", err);
                }
            }

            match settings.set_int("peer-port", session.peer_port) {
                Ok(_) => {}
                Err(err) => {
                    log::error!("Error setting peer port: {}", err);
                }
            }

            match settings.set_boolean("randomize-port", session.peer_port_random_on_start) {
                Ok(_) => {}
                Err(err) => {
                    log::error!("Error setting randomize port: {}", err);
                }
            }

            match settings.set_boolean(
                "force-encryption",
                matches!(session.encryption, Encryption::Required),
            ) {
                Ok(_) => {}
                Err(err) => {
                    log::error!("Error setting force encryption: {}", err);
                }
            }
        }

        let timer_handle = tokio::spawn(async move {
            loop {
                sender.input(TransmissionInput::UpdateTorrents);

                tokio::time::sleep(Duration::from_secs(3)).await;
            }
        });

        AsyncComponentParts {
            model: Self {
                tr_client: Some(tr_client),
                transmission_process: transmission_daemon,
                timer_handle: Some(timer_handle),
            },
            widgets: (),
        }
    }

    fn shutdown(&mut self, _widgets: &mut Self::Widgets, _output: relm4::Sender<Self::Output>) {
        // Prevent trying to update the model after shutdown
        if self.timer_handle.is_some() {
            self.timer_handle.take().unwrap().abort();
        }
    }

    async fn update(
        &mut self,
        message: Self::Input,
        sender: relm4::prelude::AsyncComponentSender<Self>,
        _root: &Self::Root,
    ) {
        match message {
            TransmissionInput::AddTorrentFile(path) => {
                let tr_client = self.tr_client.as_ref().unwrap();
                match tr_client.torrent_add_filename(&path).await {
                    Ok(_) => {}
                    Err(err) => {
                        sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
                sender.input(TransmissionInput::UpdateTorrents);
            }
            TransmissionInput::UpdateTorrents => {
                let tr_client = self.tr_client.as_ref().unwrap();

                match tr_client.torrents(None).await {
                    Ok(torrents) => {
                        sender
                            .output(TransmissionOutput::TorrentsChanged(torrents))
                            .unwrap();
                    }
                    Err(err) => {
                        sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
            }
            TransmissionInput::PauseTorrents(hashes) => {
                let tr_client = self.tr_client.as_ref().unwrap();
                match tr_client.torrent_stop(Some(hashes)).await {
                    Ok(_) => {}
                    Err(err) => {
                        sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
                sender.input(TransmissionInput::UpdateTorrents);
            }
            TransmissionInput::ResumeTorrents(hashes) => {
                let tr_client = self.tr_client.as_ref().unwrap();
                match tr_client.torrent_start(Some(hashes), false).await {
                    Ok(_) => {}
                    Err(err) => {
                        sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
                sender.input(TransmissionInput::UpdateTorrents);
            }
            TransmissionInput::RemoveTorrents(hashes) => {
                let tr_client = self.tr_client.as_ref().unwrap();
                match tr_client.torrent_remove(Some(hashes), false).await {
                    Ok(_) => {}
                    Err(err) => {
                        sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
                sender.input(TransmissionInput::UpdateTorrents);
            }
            TransmissionInput::GetFiles(id) => {
                let tr_client = self.tr_client.as_ref().unwrap();
                match tr_client.torrents_files(Some(vec![id])).await {
                    Ok(files) => {
                        sender
                            .output(TransmissionOutput::FileListChanged(files[0].to_owned()))
                            .unwrap();
                    }
                    Err(err) => {
                        sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
            }
            TransmissionInput::SetFilesWanted(hash, torrent_id, wanted, unwanted) => {
                let tr_client = self.tr_client.as_ref().unwrap();

                let mutator = TorrentMutator {
                    files_wanted: if !wanted.is_empty() {
                        Some(wanted)
                    } else {
                        None
                    },
                    files_unwanted: if !unwanted.is_empty() {
                        Some(unwanted)
                    } else {
                        None
                    },
                    ..Default::default()
                };

                match tr_client
                    .torrent_set(Some(vec![hash.clone()]), mutator)
                    .await
                {
                    Ok(_) => {
                        // Refresh torrents to get updated info
                        sender.input(TransmissionInput::UpdateTorrents);
                        sender.input(TransmissionInput::GetFiles(torrent_id));
                    }
                    Err(err) => {
                        sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
            }
            TransmissionInput::UpdateSettings => {
                let tr_client = self.tr_client.as_ref().unwrap();
                let settings = gio::Settings::new("com.github.davidmhewitt.torrential.settings");

                let mutator = SessionMutator {
                    download_queue_enabled: Some(settings.int("max-downloads") != 0),
                    download_queue_size: Some(settings.int("max-downloads")),
                    speed_limit_down: Some(settings.int("download-speed-limit")),
                    speed_limit_down_enabled: Some(settings.int("download-speed-limit") != 0),
                    speed_limit_up: Some(settings.int("upload-speed-limit")),
                    speed_limit_up_enabled: Some(settings.int("upload-speed-limit") != 0),
                    peer_port_random_on_start: Some(settings.boolean("randomize-port")),
                    peer_port: Some(settings.int("peer-port")),
                    encryption: if settings.boolean("force-encryption") {
                        Some(Encryption::Required)
                    } else {
                        Some(Encryption::Preferred)
                    },
                    ..Default::default()
                };

                match tr_client.session_set(mutator).await {
                    Ok(_) => {}
                    Err(err) => {
                        sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
            }
        }
    }

    fn init_root() -> Self::Root {}
}
