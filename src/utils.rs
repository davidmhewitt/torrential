use gtk::{
    gio::{self, Cancellable},
    glib::{self, GString},
    prelude::*,
};

pub fn get_downloads_folder() -> GString {
    let settings = gio::Settings::new("com.github.davidmhewitt.torrential.settings");
    let mut download_folder = settings.string("download-folder");

    if download_folder == "" {
        download_folder = glib::user_special_dir(glib::UserDirectory::Downloads)
            .expect("Couldn't get user download folder")
            .to_str()
            .expect("Download folder conversion failed")
            .into();
    } else {
        let download_folder_file = gio::File::for_path(&download_folder);
        if !download_folder_file.query_exists(Cancellable::NONE) {
            download_folder = glib::user_special_dir(glib::UserDirectory::Downloads)
                .expect("Couldn't get user download folder")
                .to_str()
                .expect("Download folder conversion failed")
                .into();
        }
    }

    download_folder
}
