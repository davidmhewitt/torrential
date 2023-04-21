pkgdatadir = join_paths(get_option('prefix'), get_option('datadir'), meson.project_name())
gnome = import('gnome')

gnome.compile_resources('torrential',
  'torrential.gresource.xml',
  gresource_bundle: true,
  install: true,
  install_dir: pkgdatadir,
)

conf = configuration_data()
conf.set_quoted('APP_ID', 'com.github.davidmhewitt.torrential')
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('GETTEXT_PACKAGE', 'torrential')
conf.set_quoted('LOCALEDIR', join_paths(get_option('prefix'), get_option('localedir')))
conf.set_quoted('PKGDATADIR', pkgdatadir)

configure_file(
    input: 'config.rs.in',
    output: 'config.rs',
    configuration: conf
)

# Copy the config.rs output to the source directory.
run_command(
  'cp',
  join_paths(meson.project_build_root(), 'src', 'config.rs'),
  join_paths(meson.project_source_root(), 'src', 'config.rs'),
  check: true
)

gtk4_10_dep = dependency('gtk4', version: '>=4.10', required: false)
if gtk4_10_dep.found()
  gtk_dep = gtk4_10_dep
else
  gtk_dep = dependency('gtk4', version: '>=4.6')
endif

cargo_bin  = find_program('cargo')
cargo_opt  = [ '--manifest-path', meson.project_source_root() / 'Cargo.toml' ]
cargo_opt += [ '--target-dir', meson.project_build_root()  / 'src' ]
if get_option('offline')
  cargo_opt += [ '--offline' ]
  cargo_env  = [ 'CARGO_HOME=' + meson.project_source_root()  / 'cargo' ]
else
  cargo_env  = [ 'CARGO_HOME=' + meson.project_build_root()  / 'cargo-home' ]
endif

if get_option('buildtype') == 'release'
  cargo_opt += [ '--release' ]
  rust_target = 'release'
else
  rust_target = 'debug'
endif

if gtk_dep.version().version_compare('>=4.10')
  cargo_opt += [ '--features', 'gtk4_10' ]
endif

cargo_build = custom_target(
  'cargo-build',
  build_by_default: true,
  build_always_stale: true,
  output: 'torrential',
  console: true,
  install: true,
  install_dir: get_option('bindir'),
  command: [
    'env', cargo_env,
    cargo_bin, 'build',
    cargo_opt, '&&', 'cp', 'src' / rust_target / 'torrential', '@OUTPUT@',
  ]
)
