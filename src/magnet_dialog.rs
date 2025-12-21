use gtk::prelude::{
    BoxExt, DialogExt, EditableExt, EntryExt, GtkWindowExt, OrientableExt, WidgetExt,
};
use relm4::gtk;
use relm4::ComponentSender;
use relm4::SimpleComponent;

pub struct MagnetDialogModel {
    magnet_link: String,
    visible: bool,
}

#[derive(Debug)]
pub enum MagnetDialogInput {
    Open,
    Close,
    UpdateMagnetLink(String),
    Submit,
}

#[derive(Debug)]
pub enum MagnetDialogOutput {
    AddMagnet(String),
    Close,
}

#[relm4::component(pub)]
impl SimpleComponent for MagnetDialogModel {
    type Init = ();
    type Input = MagnetDialogInput;
    type Output = MagnetDialogOutput;

    view! {
        #[root]
        granite::Dialog {
            #[watch]
            set_visible: model.visible,
            set_title: Some("Add Magnet Link"),
            set_modal: true,
            set_default_width: 400,
            set_default_height: 150,

            connect_response[sender] => move |_, response_type| {
                if response_type == gtk::ResponseType::Ok {
                    sender.input(MagnetDialogInput::Submit);
                } else {
                    sender.input(MagnetDialogInput::Close);
                }
            },

            gtk::Box {
                set_orientation: gtk::Orientation::Vertical,
                set_margin_bottom: 12,
                set_margin_start: 12,
                set_margin_end: 12,
                set_margin_top: 12,
                set_spacing: 10,

                gtk::Label {
                    set_text: "Enter magnet link:",
                    set_halign: gtk::Align::Start,
                },

                gtk::Entry {
                    set_placeholder_text: Some("magnet:?xt=urn:btih:..."),
                    connect_text_notify[sender] => move |entry| {
                        sender.input(MagnetDialogInput::UpdateMagnetLink(entry.text().to_string()));
                    },
                    connect_activate[sender] => move |_| {
                        sender.input(MagnetDialogInput::Submit);
                    },
                },
            }
        }
    }

    fn init(
        _init: Self::Init,
        root: Self::Root,
        sender: ComponentSender<Self>,
    ) -> relm4::ComponentParts<Self> {
        let model = MagnetDialogModel {
            magnet_link: String::new(),
            visible: false,
        };

        let widgets = view_output!();

        // Add buttons to the root dialog
        root.add_button("Cancel", gtk::ResponseType::Cancel.into());
        root.add_button("Add", gtk::ResponseType::Ok.into());

        relm4::ComponentParts { model, widgets }
    }

    fn update(&mut self, message: Self::Input, sender: ComponentSender<Self>) {
        match message {
            MagnetDialogInput::Open => {
                self.visible = true;
                self.magnet_link.clear();
            }
            MagnetDialogInput::Close => {
                self.visible = false;
                sender.output(MagnetDialogOutput::Close).unwrap();
            }
            MagnetDialogInput::UpdateMagnetLink(link) => {
                self.magnet_link = link;
            }
            MagnetDialogInput::Submit => {
                if !self.magnet_link.is_empty() {
                    sender
                        .output(MagnetDialogOutput::AddMagnet(self.magnet_link.clone()))
                        .unwrap();
                }
                self.visible = false;
            }
        }
    }
}
