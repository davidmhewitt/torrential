project('com.github.davidmhewitt.torrential', 'vala', 'c', version: '2.0.1')

gnome = import('gnome')
i18n = import('i18n')

add_global_arguments(
    '-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()),
    language:'c'
)

vapi_dir = join_paths(meson.current_source_dir(), 'vapi')
add_project_arguments(['--vapidir', vapi_dir], language: 'vala')

dependencies = [
    dependency('gtk+-3.0'),
    dependency('gee-0.8'),
    dependency('granite'),
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
]

subdir('data')
subdir('src')
subdir('po')

meson.add_install_script('meson/post_install.py')
