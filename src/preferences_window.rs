use crate::fl;
use granite::prelude::HeaderLabelExt;
use gtk::prelude::{
    BoxExt, ButtonExt, DialogExt, GridExt, GtkWindowExt, OrientableExt, SettingsExtManual,
    WidgetExt,
};
use relm4::gtk;
use relm4::gtk::gio::SettingsBindFlags;
use relm4::ComponentSender;
use relm4::SimpleComponent;

pub struct PreferencesWindowModel {
    hidden: bool,
}

#[derive(Debug)]
pub enum PreferencesWindowOutput {
    Close,
}

#[derive(Debug)]
pub enum PreferencesWindowInput {
    Open,
    Close,
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
            set_title: Some(&fl!("preferences-title")),
            set_resizable: false,
            set_destroy_with_parent: true,

            connect_response[sender] => move |_, _| {
                sender.input(PreferencesWindowInput::Close);
            },

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
                            set_label: &fl!("heading-download-location"),
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
                            set_label: &fl!("heading-limits"),
                        },

                        attach[0, 3, 1, 1] = &gtk::Label {
                            set_label: &fl!("label-max-downloads"),
                            set_halign: gtk::Align::End,
                            set_margin_start: 12,
                        },

                        #[name = "max_downloads_spin"]
                        attach[1, 3, 1, 1] = &gtk::SpinButton {
                            set_numeric: true,
                            set_adjustment: &gtk::Adjustment::new(1.0, 1.0, 100.0, 1.0, 10.0, 0.0),
                            set_digits: 0,
                            set_hexpand: true,
                        },

                        attach[0, 4, 1, 1] = &gtk::Label {
                            set_label: &fl!("label-download-speed-limit"),
                            set_halign: gtk::Align::End,
                            set_margin_start: 12,
                        },

                        #[name = "download_speed_spin"]
                        attach[1, 4, 1, 1] = &gtk::SpinButton {
                            set_numeric: true,
                            set_adjustment: &gtk::Adjustment::new(0.0, 0.0, 1000000.0, 25.0, 250.0, 0.0),
                            set_digits: 0,
                            set_hexpand: true,
                            set_tooltip_text: Some(&fl!("tooltip-unlimited-hint")),
                        },

                        attach[0, 5, 1, 1] = &gtk::Label {
                            set_label: &fl!("label-upload-speed-limit"),
                            set_halign: gtk::Align::End,
                            set_margin_start: 12,
                        },

                        #[name = "upload_speed_spin"]
                        attach[1, 5, 1, 1] = &gtk::SpinButton {
                            set_numeric: true,
                            set_adjustment: &gtk::Adjustment::new(0.0, 0.0, 1000000.0, 25.0, 250.0, 0.0),
                            set_digits: 0,
                            set_hexpand: true,
                            set_tooltip_text: Some(&fl!("tooltip-unlimited-hint")),
                        },

                        attach[0, 6, 1, 1] = &granite::HeaderLabel {
                            set_label: &fl!("header-desktop-integration"),
                        },

                        attach[0, 7, 1, 1] = &gtk::Label {
                            set_label: &fl!("label-hide-on-close"),
                            set_halign: gtk::Align::End,
                            set_margin_start: 12,
                        },

                        #[name = "continue_downloads_switch"]
                        attach[1, 7, 1, 1] = &gtk::Switch {
                            set_active: true,
                            set_halign: gtk::Align::Start,
                            set_hexpand: true,
                        },
                    } -> {
                        set_title: &fl!("general-preferences-title")
                    },

                    add_child = &gtk::Grid {
                        set_column_spacing: 12,
                        set_row_spacing: 6,
                        set_hexpand: true,

                        attach[0, 0, 1, 1] = &granite::HeaderLabel {
                            set_label: &fl!("header-security"),
                        },

                        attach[0, 1, 1, 1] = &gtk::Label {
                            set_label: &fl!("label-only-encrypted-peers"),
                            set_halign: gtk::Align::End,
                            set_margin_start: 12,
                        },

                        #[name = "encrypted_peers_switch"]
                        attach[1, 1, 1, 1] = &gtk::Switch {
                            set_active: true,
                            set_halign: gtk::Align::Start,
                            set_hexpand: true,
                        },

                        attach[0, 2, 1, 1] = &gtk::Label {
                            set_label: &fl!("label-random-port"),
                            set_halign: gtk::Align::End,
                            set_margin_start: 12,
                        },

                        #[name = "randomise_port_switch"]
                        attach[1, 2, 1, 1] = &gtk::Switch {
                            set_active: true,
                            set_halign: gtk::Align::Start,
                            set_hexpand: true,
                        },

                        attach[0, 3, 1, 1] = &gtk::Label {
                            set_label: &fl!("label-port-number"),
                            set_halign: gtk::Align::End,
                            set_margin_start: 12,
                        },

                        #[name = "port_spin"]
                        attach[1, 3, 1, 1] = &gtk::SpinButton {
                            set_numeric: true,
                            set_adjustment: &gtk::Adjustment::new(51413.0, 49152.0, 65535.0, 1.0, 10.0, 0.0),
                            set_digits: 0,
                            set_hexpand: true,
                        },

                    } -> {
                        set_title: &fl!("advanced-preferences-title")
                    },
                },
            },

            add_button: (&fl!("action-close"), gtk::ResponseType::Close),
        }
    }

    fn init(
        init: Self::Init,
        _parent: Self::Root,
        sender: relm4::ComponentSender<Self>,
    ) -> relm4::ComponentParts<Self> {
        let model = Self { hidden: init };
        let widgets = view_output!();

        let settings = gtk::gio::Settings::new("com.github.davidmhewitt.torrential.settings");
        settings
            .bind("max-downloads", &widgets.max_downloads_spin, "value")
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        settings
            .bind(
                "download-speed-limit",
                &widgets.download_speed_spin,
                "value",
            )
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        settings
            .bind("upload-speed-limit", &widgets.upload_speed_spin, "value")
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        settings
            .bind(
                "hide-on-close",
                &widgets.continue_downloads_switch,
                "active",
            )
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        settings
            .bind("randomize-port", &widgets.randomise_port_switch, "active")
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        settings
            .bind("peer-port", &widgets.port_spin, "value")
            .flags(SettingsBindFlags::DEFAULT)
            .build();

        relm4::ComponentParts { model, widgets }
    }

    fn update(&mut self, event: PreferencesWindowInput, sender: ComponentSender<Self>) {
        match event {
            PreferencesWindowInput::Open => {
                self.hidden = false;
            }
            PreferencesWindowInput::Close => {
                self.hidden = true;
                sender.output(PreferencesWindowOutput::Close).unwrap();
            }
        }
    }
}
