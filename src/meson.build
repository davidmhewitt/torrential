sources = files(
    'Dialogs/FileSelectDialog.vala',
    'Widgets/FileSelectTreeView.vala',
    'Widgets/MultiInfoBar.vala',
    'Widgets/TorrentListBox.vala',
    'Widgets/TorrentListRow.vala',
    'Application.vala',
    'MainWindow.vala',
    'PreferencesWindow.vala',
    'Utils.vala',
    'Torrent.vala',
    'TorrentManager.vala',
)

config_data = configuration_data()
config_data.set_quoted('LOCALEDIR', get_option('prefix') / get_option('localedir'))
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())
config_file = configure_file(
    input: 'Config.vala.in',
    output: '@BASENAME@',
    configuration: config_data
)

executable(
    meson.project_name(),
    sources,
    config_file,
    icons_gresource,
    dependencies: dependencies,
    install: true
)

