use gtk::glib::clone;
use gtk::glib::{self, Object};
use gtk::subclass::prelude::*;
use gtk_macros::spawn;
use transmission_gobject::TrClient;

mod imp {
    use super::*;

    pub struct TransmissionConnection {
        pub client: TrClient,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for TransmissionConnection {
        const NAME: &'static str = "TransmissionConnection";
        type Type = super::TransmissionConnection;

        fn new() -> Self {
            Self {
                client: TrClient::new(),
            }
        }
    }

    impl ObjectImpl for TransmissionConnection {
        fn constructed(&self) {
            self.parent_constructed();

            let obj = self.obj();

            let fut = clone!(@weak obj as this => async move {
                this.connect().await;
            });

            spawn!(fut);
        }
    }
}

glib::wrapper! {
    pub struct TransmissionConnection(ObjectSubclass<imp::TransmissionConnection>);
}

impl TransmissionConnection {
    pub fn new() -> Self {
        Object::builder().build()
    }

    async fn connect(&self) {
        let imp = self.imp();

        let res = imp
            .client
            .connect("http://127.0.0.1:9091/transmission/rpc".into(), 1500)
            .await;
        match res {
            Ok(_) => glib::g_debug!("transmission_connection", "Connected!"),
            Err(e) => glib::g_warning!("transmission_connection", "Error connecting: {}", e),
        }
    }
}

impl Default for TransmissionConnection {
    fn default() -> Self {
        TransmissionConnection::new()
    }
}
