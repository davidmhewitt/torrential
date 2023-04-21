project(
    'com.github.davidmhewitt.torrential',
    'vala', 'c',
    version: '3.0.0',
    meson_version: '>= 0.59.0',
)

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()),
    language:'c'
)

vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

dependencies = [
    dependency('gtk4'),
    dependency('gee-0.8'),
    dependency('granite-7'),
    dependency('threads'),
    meson.get_compiler('vala').find_library('posix'),
    meson.get_compiler('vala').find_library('transmission-2.0', dirs: vapi_dir),
    meson.get_compiler('c').find_library('transmission'),
    meson.get_compiler('c').find_library('b64'),
    meson.get_compiler('c').find_library('dht'),
    meson.get_compiler('c').find_library('miniupnpc'),
    meson.get_compiler('c').find_library('natpmp'),
    meson.get_compiler('c').find_library('utp'),
    meson.get_compiler('c').find_library('event'),
    meson.get_compiler('c').find_library('curl'),
    meson.get_compiler('c').find_library('ssl'),
    meson.get_compiler('c').find_library('crypto'),
    meson.get_compiler('c').find_library('z'),
]

subdir('data')
subdir('src')
subdir('po')

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)
