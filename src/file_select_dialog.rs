use crate::fl;
use gtk::prelude::*;
use gtk::{gio, glib};
use relm4::{gtk, ComponentParts, ComponentSender, SimpleComponent};
use transmission_client::TorrentFiles;

#[derive(Debug, Clone)]
struct FileNode {
    name: String,
    _path: String,
    index: Option<usize>, // None for folders, Some(index) for files
    _length: u64,
    wanted: bool,
    children: Vec<FileNode>,
}

pub struct FileSelectDialogModel {
    torrent_hash: String,
    torrent_id: i32,
    torrent_name: String,
    files: TorrentFiles,
    tree_store: gtk::TreeStore,
    tree_view: gtk::TreeView,
    visible: bool,
}

#[derive(Debug)]
pub enum FileSelectDialogInput {
    Open(String, i32, String, TorrentFiles),
    Close,
    ToggleFile(gtk::TreePath),
}

#[derive(Debug)]
pub enum FileSelectDialogOutput {
    UpdateFiles(String, i32, Vec<i32>, Vec<i32>), // torrent_hash, wanted, unwanted
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

                    #[local_ref]
                    tree_view -> gtk::TreeView {
                        set_headers_visible: false,
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
        // Create tree store with columns: index (int), active (bool), name (string), icon (Icon)
        let tree_store = gtk::TreeStore::new(&[
            glib::Type::I32,          // file index (-1 for folders)
            glib::Type::BOOL,         // is wanted
            glib::Type::STRING,       // display name
            gio::Icon::static_type(), // icon
        ]);

        let tree_view = gtk::TreeView::with_model(&tree_store);

        // Add checkbox column
        let cell_toggle = gtk::CellRendererToggle::new();
        let sender_clone = sender.clone();
        cell_toggle.connect_toggled(move |_, tree_path| {
            sender_clone.input(FileSelectDialogInput::ToggleFile(tree_path.clone()));
        });

        let column_toggle = gtk::TreeViewColumn::new();
        column_toggle.pack_start(&cell_toggle, false);
        column_toggle.add_attribute(&cell_toggle, "active", 1);
        tree_view.append_column(&column_toggle);

        // Add icon column
        let cell_pixbuf = gtk::CellRendererPixbuf::new();
        let column_icon = gtk::TreeViewColumn::new();
        column_icon.pack_start(&cell_pixbuf, false);
        column_icon.add_attribute(&cell_pixbuf, "gicon", 3);
        tree_view.append_column(&column_icon);

        // Add name column
        let cell_text = gtk::CellRendererText::new();
        let column_name = gtk::TreeViewColumn::new();
        column_name.pack_start(&cell_text, true);
        column_name.add_attribute(&cell_text, "markup", 2);
        tree_view.append_column(&column_name);

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
            tree_store: tree_store.clone(),
            tree_view: tree_view.clone(),
            visible: false,
        };

        let widgets = view_output!();

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
            FileSelectDialogInput::ToggleFile(tree_path) => {
                self.toggle_file(&tree_path);
            }
        }
    }
}

impl FileSelectDialogModel {
    fn populate_tree(&mut self) {
        self.tree_store.clear();

        // Build file tree structure
        let mut root_node = FileNode {
            name: self.torrent_name.clone(),
            _path: String::new(),
            index: None,
            _length: 0,
            wanted: true,
            children: vec![],
        };

        for (index, file) in self.files.files.iter().enumerate() {
            let path_parts: Vec<&str> = file.name.split('/').collect();
            let wanted = self
                .files
                .wanted
                .get(index)
                .map(|w| *w != 0)
                .unwrap_or(true);
            self.insert_into_tree(
                &mut root_node,
                &path_parts,
                index,
                file.length as u64,
                wanted,
            );
        }

        // Populate tree view from the tree structure
        for child in &root_node.children {
            self.add_node_to_tree(child, None);
        }

        // Update folder checkbox states based on their children
        self.update_all_folder_states();

        self.tree_view.expand_all();
    }

    fn insert_into_tree(
        &self,
        parent: &mut FileNode,
        path_parts: &[&str],
        index: usize,
        length: u64,
        wanted: bool,
    ) {
        if path_parts.is_empty() {
            return;
        }

        let current_name = path_parts[0];
        let is_leaf = path_parts.len() == 1;

        // Find or create child node
        let child = parent.children.iter_mut().find(|c| c.name == current_name);

        if let Some(child_node) = child {
            if !is_leaf {
                self.insert_into_tree(child_node, &path_parts[1..], index, length, wanted);
            }
        } else {
            if is_leaf {
                // Add file node
                parent.children.push(FileNode {
                    name: current_name.to_string(),
                    _path: path_parts.join("/"),
                    index: Some(index),
                    _length: length,
                    wanted,
                    children: vec![],
                });
            } else {
                // Add folder node
                let mut folder_node = FileNode {
                    name: current_name.to_string(),
                    _path: current_name.to_string(),
                    index: None,
                    _length: 0,
                    wanted: true,
                    children: vec![],
                };
                self.insert_into_tree(&mut folder_node, &path_parts[1..], index, length, wanted);
                parent.children.push(folder_node);
            }
        }
    }

    fn add_node_to_tree(&self, node: &FileNode, parent: Option<&gtk::TreeIter>) {
        let icon = if node.index.is_some() {
            // File icon based on content type
            let content_type = gio::content_type_guess(Some(node.name.as_str()), None::<&[u8]>).0;
            gio::content_type_get_icon(&content_type)
        } else {
            // Folder icon
            gio::content_type_get_icon("inode/directory")
        };

        let iter = self.tree_store.insert_with_values(
            parent,
            None,
            &[
                (0, &node.index.map(|i| i as i32).unwrap_or(-1)),
                (1, &node.wanted),
                (2, &glib::markup_escape_text(&node.name)),
                (3, &icon),
            ],
        );

        // Add children recursively
        for child in &node.children {
            self.add_node_to_tree(child, Some(&iter));
        }
    }

    fn toggle_file(&mut self, tree_path: &gtk::TreePath) {
        if let Some(iter) = self.tree_store.iter(tree_path) {
            let index: i32 = self.tree_store.get(&iter, 0);
            let current_state: bool = self.tree_store.get(&iter, 1);
            let new_state = !current_state;

            if index >= 0 {
                // This is a file
                self.tree_store.set_value(&iter, 1, &new_state.to_value());
                self.update_parent_states(&iter);
            } else {
                // This is a folder - toggle all children recursively
                self.set_children_state(&iter, new_state);
                self.tree_store.set_value(&iter, 1, &new_state.to_value());
            }
        }
    }

    fn set_children_state(&self, parent_iter: &gtk::TreeIter, state: bool) {
        if let Some(child_iter) = self.tree_store.iter_children(Some(parent_iter)) {
            loop {
                self.tree_store.set_value(&child_iter, 1, &state.to_value());

                // Recursively set children if this is a folder
                let index: i32 = self.tree_store.get(&child_iter, 0);
                if index < 0 {
                    self.set_children_state(&child_iter, state);
                }

                if !self.tree_store.iter_next(&child_iter) {
                    break;
                }
            }
        }
    }

    fn update_parent_states(&self, child_iter: &gtk::TreeIter) {
        if let Some(parent_iter) = self.tree_store.iter_parent(child_iter) {
            // Check all children to determine parent state
            let mut all_true = true;

            if let Some(sibling_iter) = self.tree_store.iter_children(Some(&parent_iter)) {
                loop {
                    let state: bool = self.tree_store.get(&sibling_iter, 1);
                    if !state {
                        all_true = false;
                        break;
                    }

                    if !self.tree_store.iter_next(&sibling_iter) {
                        break;
                    }
                }
            }

            // Set parent state based on children
            if all_true {
                self.tree_store.set_value(&parent_iter, 1, &true.to_value());
            } else {
                self.tree_store
                    .set_value(&parent_iter, 1, &false.to_value());
            }

            // Recursively update grandparents
            self.update_parent_states(&parent_iter);
        }
    }

    fn update_all_folder_states(&self) {
        // Update all folder states by doing a post-order traversal
        self.update_folder_states_recursive(None);
    }

    fn update_folder_states_recursive(&self, parent: Option<&gtk::TreeIter>) {
        if let Some(iter) = self.tree_store.iter_children(parent) {
            loop {
                // First, recursively process children
                let index: i32 = self.tree_store.get(&iter, 0);
                if index < 0 {
                    // This is a folder, process its children first
                    self.update_folder_states_recursive(Some(&iter));

                    // Now update this folder's state based on its children
                    let mut all_true = true;

                    if let Some(child_iter) = self.tree_store.iter_children(Some(&iter)) {
                        loop {
                            let state: bool = self.tree_store.get(&child_iter, 1);
                            if !state {
                                all_true = false;
                                break;
                            }

                            if !self.tree_store.iter_next(&child_iter) {
                                break;
                            }
                        }
                    }

                    // Set folder state
                    if all_true {
                        self.tree_store.set_value(&iter, 1, &true.to_value());
                    } else {
                        self.tree_store.set_value(&iter, 1, &false.to_value());
                    }
                }

                if !self.tree_store.iter_next(&iter) {
                    break;
                }
            }
        }
    }

    fn collect_file_states(&self) -> (Vec<i32>, Vec<i32>) {
        let mut wanted = Vec::new();
        let mut unwanted = Vec::new();

        self.collect_file_states_recursive(None, &mut wanted, &mut unwanted);

        (wanted, unwanted)
    }

    fn collect_file_states_recursive(
        &self,
        parent: Option<&gtk::TreeIter>,
        wanted: &mut Vec<i32>,
        unwanted: &mut Vec<i32>,
    ) {
        if let Some(iter) = self.tree_store.iter_children(parent) {
            loop {
                let index: i32 = self.tree_store.get(&iter, 0);
                let state: bool = self.tree_store.get(&iter, 1);

                if index >= 0 {
                    // This is a file
                    if state {
                        wanted.push(index);
                    } else {
                        unwanted.push(index);
                    }
                } else {
                    // This is a folder - recurse
                    self.collect_file_states_recursive(Some(&iter), wanted, unwanted);
                }

                if !self.tree_store.iter_next(&iter) {
                    break;
                }
            }
        }
    }
}
