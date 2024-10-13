use std::time::Duration;

use relm4::component::{AsyncComponent, AsyncComponentParts};
use transmission_client::{Client, Torrent};
use url::Url;

pub(crate) struct Transmission {
    tr_client: Option<Client>,
}

#[derive(Debug)]
pub(crate) enum TransmissionOutput {
    ConnectionError(String),
    TorrentsChanged(Vec<Torrent>),
}

#[derive(Debug)]
pub(crate) enum TransmissionInput {
    UpdateTorrents,
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
        let Ok(url) = Url::parse("http://localhost:9091/transmission/rpc") else {
            sender
                .output(TransmissionOutput::ConnectionError(
                    "Invalid URL".to_string(),
                ))
                .unwrap();
            return AsyncComponentParts {
                model: Self { tr_client: None },
                widgets: (),
            };
        };

        let tr_client = Client::new(url);

        tokio::spawn(async move {
            loop {
                sender.input(TransmissionInput::UpdateTorrents);

                tokio::time::sleep(Duration::from_secs(5)).await;
            }
        });

        AsyncComponentParts {
            model: Self {
                tr_client: Some(tr_client),
            },
            widgets: (),
        }
    }

    async fn update(
        &mut self,
        message: Self::Input,
        _sender: relm4::prelude::AsyncComponentSender<Self>,
        _root: &Self::Root,
    ) {
        match message {
            TransmissionInput::UpdateTorrents => {
                let tr_client = self.tr_client.as_ref().unwrap();

                match tr_client.torrents(None).await {
                    Ok(torrents) => {
                        _sender
                            .output(TransmissionOutput::TorrentsChanged(torrents))
                            .unwrap();
                    }
                    Err(err) => {
                        _sender
                            .output(TransmissionOutput::ConnectionError(err.to_string()))
                            .unwrap();
                    }
                }
            }
        }
    }

    fn init_root() -> Self::Root {
        ()
    }
}
