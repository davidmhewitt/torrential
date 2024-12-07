use granite::prelude::HeaderLabelExt;
use gtk::prelude::{BoxExt, ButtonExt, DialogExt, GridExt, GtkWindowExt, OrientableExt, WidgetExt};
use relm4::gtk;
use relm4::ComponentSender;
use relm4::SimpleComponent;
use tr::tr;

pub struct PreferencesWindowModel {
    hidden: bool,
}

#[derive(Debug)]
pub enum PreferencesWindowOutput {}

#[derive(Debug)]
pub enum PreferencesWindowInput {
    Open,
}

#[relm4::component(pub)]
impl SimpleComponent for PreferencesWindowModel {
    type Init = bool;
    type Input = PreferencesWindowInput;
    type Output = PreferencesWindowOutput;

    view! {
        #[root]
        granite::Dialog {
            #[watch]
            set_visible: !model.hidden,
            set_title: Some(&tr!("Preferences")),
            set_resizable: false,
            set_destroy_with_parent: true,

            gtk::Box {
                set_orientation: gtk::Orientation::Vertical,
                set_margin_bottom: 12,
                set_margin_start: 12,
                set_margin_end: 12,
                set_vexpand: true,

                gtk::StackSwitcher {
                    set_halign: gtk::Align::Center,
                    set_stack: Some(&prefs_stack)
                },

                #[name = "prefs_stack"]
                gtk::Stack {
                    add_child = &gtk::Grid {
                        set_column_spacing: 12,
                        set_row_spacing: 6,
                        set_hexpand: true,

                        attach[0, 0, 1, 1] = &granite::HeaderLabel {
                            set_label: &tr!("Download Location"),
                        },

                        attach[0, 1, 2, 1] = &gtk::Button {
                            set_margin_start: 12,
                            set_hexpand: true,
                            #[wrap(Some)]
                            set_child = &gtk::Box {
                                set_orientation: gtk::Orientation::Horizontal,
                                set_spacing: 3,

                                gtk::Image {
                                    set_icon_name: Some("folder"),
                                },

                                gtk::Label {
                                    set_label: "/home/user/Downloads",
                                },
                            }
                        },

                        attach[0, 2, 1, 1] = &granite::HeaderLabel {
                            set_label: &tr!("Limits"),
                        },
                    } -> {
                        set_title: &tr!("General")
                    },

                    add_child = &gtk::Grid {
                        set_column_spacing: 12,
                        set_row_spacing: 6,
                        set_hexpand: true,

                        attach[0, 2, 1, 1] = &granite::HeaderLabel {
                            set_label: &tr!("Security"),
                        },
                    } -> {
                        set_title: &tr!("Advanced")
                    },
                },
            },

            add_button: (&tr!("Close"), gtk::ResponseType::Close),
        }
    }

    fn init(
        init: Self::Init,
        _parent: Self::Root,
        _sender: relm4::ComponentSender<Self>,
    ) -> relm4::ComponentParts<Self> {
        let model = Self { hidden: init };
        let widgets = view_output!();

        relm4::ComponentParts { model, widgets }
    }

    fn update(&mut self, event: PreferencesWindowInput, _sender: ComponentSender<Self>) {
        match event {
            PreferencesWindowInput::Open => {
                self.hidden = false;
            }
        }
    }
}
