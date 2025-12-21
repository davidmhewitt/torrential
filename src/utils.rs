use relm4::gtk::{
    gio::ffi,
    glib::{
        self,
        translate::{from_glib, from_glib_full, ToGlibPtr},
    },
};
use std::path::PathBuf;

// Workaround to https://github.com/gtk-rs/gtk-rs-core/issues/1257
pub fn content_type_guess(
    filename: &Option<impl AsRef<std::path::Path>>,
    data: Option<&[u8]>,
) -> (glib::GString, bool) {
    let data_size = data.map_or(0, <[u8]>::len);
    unsafe {
        let mut result_uncertain = std::mem::MaybeUninit::uninit();
        let ret = from_glib_full(ffi::g_content_type_guess(
            filename
                .as_ref()
                .map(std::convert::AsRef::as_ref)
                .to_glib_none()
                .0,
            data.to_glib_none().0,
            data_size as _,
            result_uncertain.as_mut_ptr(),
        ));
        (ret, from_glib(result_uncertain.assume_init()))
    }
}

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
