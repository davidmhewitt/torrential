# Torrential
Download torrents in style with this speedy, minimalist torrent client for elementary OS.

[![Get it on AppCenter](https://appcenter.elementary.io/badge.svg)](https://appcenter.elementary.io/com.github.davidmhewitt.torrential)

![Torrential Screenshot](https://github.com/davidmhewitt/torrential/raw/master/data/com.github.davidmhewitt.torrential.screenshot.png)

## Building, Testing, and Installation

You'll need the following dependencies to build:
* cmake
* libgtk-3-dev
* valac
* libgranite-dev
* libarchive-dev
* libunity-dev
* libcurl4-openssl-dev
* libssl-dev
* automake
* libtool

## How To Build

    git clone --recurse-submodules https://github.com/davidmhewitt/torrential
    cd torrential
    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX=/usr ..
    make
    sudo make install
