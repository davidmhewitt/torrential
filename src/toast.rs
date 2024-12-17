use granite::prelude::ToastExt;
use relm4::prelude::*;

#[derive(Default)]
pub struct Toast {
    toast: granite::Toast,
}

#[derive(Debug)]
pub enum ToastMsg {
    Show(String),
}

#[derive(Debug)]
pub enum ToastOutput {}

#[relm4::component(pub)]
impl SimpleComponent for Toast {
    type Init = ();
    type Input = ToastMsg;
    type Output = ToastOutput;

    view! {
        granite::Toast {}
    }

    fn init(
        _init: Self::Init,
        root: Self::Root,
        _sender: relm4::ComponentSender<Self>,
    ) -> relm4::ComponentParts<Self> {
        let widgets = view_output!();
        let model = Self { toast: root };

        ComponentParts { model, widgets }
    }

    fn update(&mut self, message: Self::Input, _sender: ComponentSender<Self>) {
        match message {
            ToastMsg::Show(title) => {
                self.toast.set_title(&title);
                self.toast.send_notification();
            }
        }
    }
}
