use relm4::factory::FactoryComponent;
use relm4::gtk;

#[derive(Debug)]
#[tracker::track]
pub(crate) struct Torrent {
    pub name: String,
    pub percent_done: f32,
}

#[relm4::factory(pub)]
impl FactoryComponent for Torrent {
    type Init = transmission_client::Torrent;
    type Input = ();
    type Output = ();
    type ParentWidget = gtk::ListBox;
    type CommandOutput = ();

    view! {
        gtk::Box {
            gtk::Label {
                #[track = "self.changed(Torrent::name())"]
                set_text: &self.name,
            },
            gtk::Label {
                #[track = "self.changed(Torrent::percent_done())"]
                set_text: &self.percent_done.to_string(),
            }
        }
    }

    fn init_model(
        init: Self::Init,
        _index: &Self::Index,
        _sender: relm4::prelude::FactorySender<Self>,
    ) -> Self {
        Self {
            name: init.name,
            percent_done: init.percent_done,
            tracker: Default::default(),
        }
    }

    fn update(
        &mut self,
        _msg: Self::Input,
        _sender: relm4::prelude::FactorySender<Self>,
    ) -> Self::Output {
        self.reset();
    }
}

impl Torrent {
    pub fn update(&mut self, torrent: &transmission_client::Torrent) {
        if self.name != torrent.name {
            self.set_name(torrent.name.clone());
        }

        self.set_percent_done(torrent.percent_done);
    }
}
