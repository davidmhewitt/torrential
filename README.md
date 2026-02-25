# Torrential

**Note:** The `main` branch contains a currently-unreleased rewrite. For the old, currently-released version of Torrential, see the `3.x` branch.

## Rewrite (Help Wanted)

The old `3.x` release of Torrential depends on Transmission 3.x, which was the last release to have C language binding. Torrential used these C bindings with a .vapi file to consume the library from Vala.

As the 3.x release of Transmission is now old, depends on an old version of OpenSSL, and is probably insecure; a rethink is needed for how we consume the Transmission backend.

A decision was made to rewrite it in Rust as there is a [`transmission-client`](https://crates.io/crates/transmission-client) crate to easily bind the Transmission 4.x RPCs.

This branch contains the up to date progress of that largely-working rewrite. I'm slowly working on it, but don't have a lot of time to focus on it these days. I would appreciate contributions if anyone was willing!

The following features are missing compared to the last release. In no real order of importance and may decide to drop some:

- GitHub Actions (CI/CD)
- Notifications
- Auto-monitoring Downloads folder for new .torrent files
- Setting and functionality to auto-trash added .torrent files
- Auto-populating magnet link from clipboard
- Custom download folder setting and functionality
- Hide on close behaviour (background portal implementation?)
- Window state saving (partially implemented, but are we still supposed to do that?)
- Granite toast when magnet link is copied
- Infobar to show warnings/info
- Progress bar/badge in dock
- Keyboard shortcuts
- Dark mode (does Granite do that for us now?)
- Migrating translations where still relevant
- Refinement of status text line (different states: waiting, metadata, queue, seeding, etc...)
- Command line options (file args, magnet link args)
- Testing Flatpak upgrade (do users' settings migrate? do they populate to new transmission backend)
- Testing Flatpak subprocess (can we run the transmission server subprocess)

## Building

```
flatpak-builder build com.github.davidmhewitt.torrential.json --user --force-clean --install
```