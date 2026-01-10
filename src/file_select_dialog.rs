use crate::fl;
use gtk::prelude::*;
use gtk::subclass::prelude::*;
use gtk::{gio, glib};
use relm4::{gtk, ComponentParts, ComponentSender, SimpleComponent};
use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::rc::Rc;
use transmission_client::TorrentFiles;

struct ItemBindings {
    handler_id: glib::SignalHandlerId,
    wanted_binding: glib::Binding,
    inconsistent_binding: glib::Binding,
}

mod imp {
    use super::*;

    #[derive(Debug, Default)]
    pub struct FileNode {
        pub name: RefCell<String>,
        pub path: RefCell<String>,
        pub index: Cell<i32>, // -1 for folders
        pub wanted: Cell<bool>,
        pub inconsistent: Cell<bool>,
        pub children: RefCell<Vec<super::FileNode>>,
    }

    #[glib::object_subclass]
    impl ObjectSubclass for FileNode {
        const NAME: &'static str = "TorrentialFileNode";
        type Type = super::FileNode;
        type ParentType = glib::Object;
    }

    impl ObjectImpl for FileNode {
        fn properties() -> &'static [glib::ParamSpec] {
            use std::sync::OnceLock;
            static PROPERTIES: OnceLock<Vec<glib::ParamSpec>> = OnceLock::new();
            PROPERTIES.get_or_init(|| {
                vec![
                    glib::ParamSpecString::builder("name").read_only().build(),
                    glib::ParamSpecString::builder("icon-name")
                        .read_only()
                        .build(),
                    glib::ParamSpecBoolean::builder("wanted")
                        .readwrite()
                        .build(),
                    glib::ParamSpecBoolean::builder("inconsistent")
                        .read_only()
                        .build(),
                ]
            })
        }

        fn property(&self, _id: usize, pspec: &glib::ParamSpec) -> glib::Value {
            let obj = self.obj();
            match pspec.name() {
                "name" => obj.name().to_value(),
                "icon-name" => obj.icon_name().to_value(),
                "wanted" => obj.wanted().to_value(),
                "inconsistent" => obj.inconsistent().to_value(),
                _ => unimplemented!(),
            }
        }

        fn set_property(&self, _id: usize, value: &glib::Value, pspec: &glib::ParamSpec) {
            match pspec.name() {
                "wanted" => {
                    let wanted = value.get().expect("Expected bool");
                    self.wanted.set(wanted);
                }
                _ => unimplemented!(),
            }
        }
    }
}

glib::wrapper! {
    pub struct FileNode(ObjectSubclass<imp::FileNode>);
}

impl FileNode {
    pub fn new_file(name: &str, path: &str, index: usize, wanted: bool) -> Self {
        let obj: Self = glib::Object::new();
        let imp = obj.imp();
        imp.name.replace(name.to_string());
        imp.path.replace(path.to_string());
        imp.index.set(index as i32);
        imp.wanted.set(wanted);
        imp.inconsistent.set(false);
        obj
    }

    pub fn new_folder(name: &str, path: &str) -> Self {
        let obj: Self = glib::Object::new();
        let imp = obj.imp();
        imp.name.replace(name.to_string());
        imp.path.replace(path.to_string());
        imp.index.set(-1);
        imp.wanted.set(true);
        imp.inconsistent.set(false);
        obj
    }

    pub fn name(&self) -> String {
        self.imp().name.borrow().clone()
    }

    pub fn path(&self) -> String {
        self.imp().path.borrow().clone()
    }

    pub fn index(&self) -> i32 {
        self.imp().index.get()
    }

    pub fn is_folder(&self) -> bool {
        self.index() < 0
    }

    pub fn wanted(&self) -> bool {
        self.imp().wanted.get()
    }

    pub fn set_wanted(&self, wanted: bool) {
        self.imp().wanted.set(wanted);
        self.notify("wanted");
    }

    pub fn inconsistent(&self) -> bool {
        self.imp().inconsistent.get()
    }

    pub fn set_inconsistent(&self, inconsistent: bool) {
        self.imp().inconsistent.set(inconsistent);
        self.notify("inconsistent");
    }

    pub fn icon_name(&self) -> String {
        if self.is_folder() {
            gio::content_type_get_generic_icon_name("inode/directory")
                .map(|s| s.to_string())
                .unwrap_or_else(|| "folder".to_string())
        } else {
            let name = self.name();
            let (content_type, _) = gio::content_type_guess(Some(name.as_str()), None::<&[u8]>);
            gio::content_type_get_generic_icon_name(&content_type)
                .map(|s| s.to_string())
                .unwrap_or_else(|| "text-x-generic".to_string())
        }
    }

    pub fn children(&self) -> Vec<FileNode> {
        self.imp().children.borrow().clone()
    }

    pub fn add_child(&self, child: FileNode) {
        self.imp().children.borrow_mut().push(child);
    }

    pub fn find_or_create_folder(&self, name: &str, path: &str) -> FileNode {
        let children = self.imp().children.borrow();
        for child in children.iter() {
            if child.is_folder() && child.name() == name {
                return child.clone();
            }
        }
        drop(children);

        let folder = FileNode::new_folder(name, path);
        self.add_child(folder.clone());
        folder
    }

    /// Recursively update the wanted state based on children
    pub fn update_state_from_children(&self) {
        if !self.is_folder() {
            return;
        }

        let children = self.children();
        if children.is_empty() {
            return;
        }

        // First, recursively update all child folders
        for child in &children {
            child.update_state_from_children();
        }

        // Now calculate this folder's state
        let mut all_wanted = true;
        let mut any_wanted = false;

        for child in &children {
            if child.wanted() {
                any_wanted = true;
            } else {
                all_wanted = false;
            }
            // If a child is inconsistent, we're also inconsistent
            if child.inconsistent() {
                all_wanted = false;
                any_wanted = true;
            }
        }

        let inconsistent = !all_wanted && any_wanted;
        self.set_inconsistent(inconsistent);
        self.set_wanted(any_wanted);
    }

    /// Set wanted state for this node and all descendants
    pub fn set_wanted_recursive(&self, wanted: bool) {
        self.set_wanted(wanted);
        self.set_inconsistent(false);

        for child in self.children() {
            child.set_wanted_recursive(wanted);
        }
    }
}

pub struct FileSelectDialogModel {
    torrent_hash: String,
    torrent_id: i32,
    torrent_name: String,
    files: TorrentFiles,
    root_store: gio::ListStore,
    tree_model: Option<gtk::TreeListModel>,
    list_view: Option<gtk::ListView>,
    visible: bool,
}

#[derive(Debug)]
pub enum FileSelectDialogInput {
    Open(String, i32, String, TorrentFiles),
    Close,
    ToggleFile(FileNode, gtk::TreeListRow, bool),
}

#[derive(Debug)]
pub enum FileSelectDialogOutput {
    UpdateFiles(String, i32, Vec<i32>, Vec<i32>), // torrent_hash, torrent_id, wanted, unwanted
}

#[relm4::component(pub)]
impl SimpleComponent for FileSelectDialogModel {
    type Init = ();
    type Input = FileSelectDialogInput;
    type Output = FileSelectDialogOutput;

    view! {
        #[root]
        dialog = granite::Dialog {
            set_title: Some("Select Files to Download"),
            set_modal: true,
            set_default_size: (550, 400),
            set_hide_on_close: true,

            #[watch]
            set_visible: model.visible,

            connect_close_request[sender] => move |_| {
                sender.input(FileSelectDialogInput::Close);
                glib::Propagation::Stop
            },

            #[wrap(Some)]
            set_child = &gtk::Box {
                set_orientation: gtk::Orientation::Vertical,
                set_margin_top: 12,
                set_margin_bottom: 12,
                set_margin_start: 12,
                set_margin_end: 12,
                set_spacing: 6,

                gtk::ScrolledWindow {
                    set_vexpand: true,
                    set_hexpand: true,
                    add_css_class: granite::STYLE_CLASS_FRAME,

                    #[name(list_view)]
                    gtk::ListView {
                        set_vexpand: true,
                    }
                },

                gtk::Box {
                    set_orientation: gtk::Orientation::Horizontal,
                    set_halign: gtk::Align::End,
                    set_spacing: 6,

                    gtk::Button {
                        set_label: &fl!("action-close"),
                        connect_clicked => FileSelectDialogInput::Close,
                    }
                }
            }
        }
    }

    fn init(
        _init: Self::Init,
        root: Self::Root,
        sender: ComponentSender<Self>,
    ) -> ComponentParts<Self> {
        let root_store = gio::ListStore::new::<FileNode>();

        let model = FileSelectDialogModel {
            torrent_hash: String::new(),
            torrent_id: 0,
            torrent_name: String::new(),
            files: TorrentFiles {
                id: 0,
                file_count: 0,
                files: vec![],
                file_stats: vec![],
                wanted: vec![],
                priorities: vec![],
            },
            root_store: root_store.clone(),
            tree_model: None,
            list_view: None,
            visible: false,
        };

        let widgets = view_output!();

        let factory = gtk::SignalListItemFactory::new();

        // Shared storage for bindings, keyed by ListItem pointer address (stable identity)
        let bindings_storage: Rc<RefCell<HashMap<usize, ItemBindings>>> =
            Rc::new(RefCell::new(HashMap::new()));

        factory.connect_setup(|_, list_item| {
            let list_item = list_item
                .downcast_ref::<gtk::ListItem>()
                .expect("Needs to be ListItem");

            let expander = gtk::TreeExpander::new();
            let content_box = gtk::Box::new(gtk::Orientation::Horizontal, 6);

            let check_button = gtk::CheckButton::new();
            content_box.append(&check_button);

            let icon = gtk::Image::new();
            content_box.append(&icon);

            let label = gtk::Label::new(None);
            label.set_halign(gtk::Align::Start);
            content_box.append(&label);

            expander.set_child(Some(&content_box));
            list_item.set_child(Some(&expander));
        });

        let sender_clone = sender.clone();
        let bindings_for_bind = bindings_storage.clone();
        factory.connect_bind(move |_, list_item| {
            let list_item = list_item
                .downcast_ref::<gtk::ListItem>()
                .expect("Needs to be ListItem");

            // Use pointer address as stable key for this ListItem instance
            let key = list_item.as_ptr() as usize;

            let tree_list_row = list_item
                .item()
                .and_downcast::<gtk::TreeListRow>()
                .expect("Needs to be TreeListRow");

            let file_node = tree_list_row
                .item()
                .and_downcast::<FileNode>()
                .expect("Needs to be FileNode");

            let expander = list_item
                .child()
                .and_downcast::<gtk::TreeExpander>()
                .expect("Needs to be TreeExpander");

            expander.set_list_row(Some(&tree_list_row));

            let content_box = expander
                .child()
                .and_downcast::<gtk::Box>()
                .expect("Needs to be Box");

            let check_button = content_box
                .first_child()
                .and_downcast::<gtk::CheckButton>()
                .expect("Needs to be CheckButton");

            let icon = check_button
                .next_sibling()
                .and_downcast::<gtk::Image>()
                .expect("Needs to be Image");

            let label = icon
                .next_sibling()
                .and_downcast::<gtk::Label>()
                .expect("Needs to be Label");

            // Bind properties
            label.set_text(&file_node.name());
            icon.set_icon_name(Some(&file_node.icon_name()));

            // Use property bindings so the checkbox updates when the FileNode changes
            let wanted_binding = file_node
                .bind_property("wanted", &check_button, "active")
                .sync_create()
                .build();

            let inconsistent_binding = file_node
                .bind_property("inconsistent", &check_button, "inconsistent")
                .sync_create()
                .build();

            // Connect checkbox signal
            let sender = sender_clone.clone();
            let node_clone = file_node.clone();
            let row_clone = tree_list_row.clone();
            let handler_id = check_button.connect_toggled(move |btn| {
                sender.input(FileSelectDialogInput::ToggleFile(
                    node_clone.clone(),
                    row_clone.clone(),
                    btn.is_active(),
                ));
            });

            // Store bindings and handler for later cleanup
            bindings_for_bind.borrow_mut().insert(
                key,
                ItemBindings {
                    handler_id,
                    wanted_binding,
                    inconsistent_binding,
                },
            );
        });

        let bindings_for_unbind = bindings_storage.clone();
        factory.connect_unbind(move |_, list_item| {
            let list_item = list_item
                .downcast_ref::<gtk::ListItem>()
                .expect("Needs to be ListItem");

            // Use same pointer address key
            let key = list_item.as_ptr() as usize;

            // Remove and cleanup bindings for this ListItem
            if let Some(bindings) = bindings_for_unbind.borrow_mut().remove(&key) {
                if let Some(expander) = list_item.child().and_downcast::<gtk::TreeExpander>() {
                    if let Some(content_box) = expander.child().and_downcast::<gtk::Box>() {
                        if let Some(check_button) =
                            content_box.first_child().and_downcast::<gtk::CheckButton>()
                        {
                            check_button.disconnect(bindings.handler_id);
                        }
                    }
                }
                bindings.wanted_binding.unbind();
                bindings.inconsistent_binding.unbind();
            }
        });

        // Store factory in list view
        widgets.list_view.set_factory(Some(&factory));

        // Store the list view reference in the model
        let mut model = model;
        model.list_view = Some(widgets.list_view.clone());

        ComponentParts { model, widgets }
    }

    fn update(&mut self, message: Self::Input, sender: ComponentSender<Self>) {
        match message {
            FileSelectDialogInput::Open(torrent_hash, torrent_id, torrent_name, files) => {
                self.torrent_hash = torrent_hash;
                self.torrent_id = torrent_id;
                self.torrent_name = torrent_name.clone();
                self.files = files;
                self.populate_tree();
                // Update the list view with the new model
                if let (Some(ref tree_model), Some(ref list_view)) =
                    (&self.tree_model, &self.list_view)
                {
                    let selection_model = gtk::NoSelection::new(Some(tree_model.clone()));
                    list_view.set_model(Some(&selection_model));
                }
                self.visible = true;
            }
            FileSelectDialogInput::Close => {
                self.visible = false;
                // Collect wanted and unwanted files
                let (wanted, unwanted) = self.collect_file_states();
                sender
                    .output(FileSelectDialogOutput::UpdateFiles(
                        self.torrent_hash.clone(),
                        self.torrent_id,
                        wanted,
                        unwanted,
                    ))
                    .ok();
            }
            FileSelectDialogInput::ToggleFile(file_node, tree_row, new_state) => {
                self.toggle_file(&file_node, &tree_row, new_state);
            }
        }
    }
}

impl FileSelectDialogModel {
    fn populate_tree(&mut self) {
        self.root_store.remove_all();

        let root_node = FileNode::new_folder(&self.torrent_name, "");

        // Build file tree structure
        for (index, file) in self.files.files.iter().enumerate() {
            let path_parts: Vec<&str> = file.name.split('/').collect();
            let wanted = self
                .files
                .wanted
                .get(index)
                .map(|w| *w != 0)
                .unwrap_or(true);

            Self::insert_into_tree(&root_node, &path_parts, index, wanted);
        }

        root_node.update_state_from_children();

        self.root_store.append(&root_node);

        let tree_model = gtk::TreeListModel::new(
            self.root_store.clone(),
            false, // not passthrough - we want TreeListRow items
            false, // not autoexpand
            |item| -> Option<gio::ListModel> {
                let file_node = item.downcast_ref::<FileNode>()?;
                let children = file_node.children();
                if children.is_empty() {
                    return None;
                }

                // Sort children: folders first, then files, both alphabetically
                let mut sorted_children = children;
                sorted_children.sort_by(|a, b| match (a.is_folder(), b.is_folder()) {
                    (true, false) => std::cmp::Ordering::Less,
                    (false, true) => std::cmp::Ordering::Greater,
                    _ => a.name().to_lowercase().cmp(&b.name().to_lowercase()),
                });

                let store = gio::ListStore::new::<FileNode>();
                for child in sorted_children {
                    store.append(&child);
                }
                Some(store.upcast())
            },
        );

        // Expand the root node
        if let Some(row) = tree_model.row(0) {
            row.set_expanded(true);
        }

        self.tree_model = Some(tree_model);
    }

    fn insert_into_tree(parent: &FileNode, path_parts: &[&str], index: usize, wanted: bool) {
        if path_parts.is_empty() {
            return;
        }

        let current_name = path_parts[0];
        let is_leaf = path_parts.len() == 1;

        if is_leaf {
            let file_node = FileNode::new_file(current_name, &path_parts.join("/"), index, wanted);
            parent.add_child(file_node);
        } else {
            // Find or create folder
            let current_path = if parent.path().is_empty() {
                current_name.to_string()
            } else {
                format!("{}/{}", parent.path(), current_name)
            };
            let folder = parent.find_or_create_folder(current_name, &current_path);
            Self::insert_into_tree(&folder, &path_parts[1..], index, wanted);
        }
    }

    fn toggle_file(&mut self, file_node: &FileNode, tree_row: &gtk::TreeListRow, new_state: bool) {
        if file_node.is_folder() {
            file_node.set_wanted_recursive(new_state);
        } else {
            file_node.set_wanted(new_state);
        }

        self.update_parent_states(tree_row);
    }

    fn update_parent_states(&self, tree_row: &gtk::TreeListRow) {
        // Walk up the tree and update each parent's state
        let mut current_row = tree_row.parent();
        while let Some(parent_row) = current_row {
            if let Some(parent_node) = parent_row.item().and_downcast::<FileNode>() {
                parent_node.update_state_from_children();
            }
            current_row = parent_row.parent();
        }
    }

    fn collect_file_states(&self) -> (Vec<i32>, Vec<i32>) {
        let mut wanted = Vec::new();
        let mut unwanted = Vec::new();

        for i in 0..self.root_store.n_items() {
            if let Some(root_node) = self.root_store.item(i).and_downcast::<FileNode>() {
                Self::collect_file_states_recursive(&root_node, &mut wanted, &mut unwanted);
            }
        }

        (wanted, unwanted)
    }

    fn collect_file_states_recursive(
        node: &FileNode,
        wanted: &mut Vec<i32>,
        unwanted: &mut Vec<i32>,
    ) {
        if node.is_folder() {
            for child in node.children() {
                Self::collect_file_states_recursive(&child, wanted, unwanted);
            }
        } else {
            // Set the wanted/unwanted lists based on this file's state
            let index = node.index();
            if node.wanted() {
                wanted.push(index);
            } else {
                unwanted.push(index);
            }
        }
    }
}
