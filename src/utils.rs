use std::path::PathBuf;

pub fn open_torrent_location(download_dir: &str, torrent_name: &str) {
    let full_path = PathBuf::from(download_dir).join(torrent_name);

    // Check if path exists, if not try to open the parent directory
    let path_to_open = if full_path.exists() {
        full_path
    } else {
        // File might not be complete yet (.part files), try parent directory
        PathBuf::from(download_dir)
    };

    let file = relm4::gtk::gio::File::for_path(&path_to_open);
    gtk4::FileLauncher::new(Some(&file)).open_containing_folder(
        None::<&gtk4::Window>,
        None::<&gtk4::gio::Cancellable>,
        |_result| {},
    );
}
