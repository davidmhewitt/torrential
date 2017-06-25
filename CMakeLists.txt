# the oldest stable cmake version we support
cmake_minimum_required (VERSION 2.6)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake)

# where we install data directory (if we have any)
set (DATADIR "${CMAKE_INSTALL_PREFIX}/share")

# what to call that directory where we install data too
set (PKGDATADIR "${DATADIR}/com.github.davidmhewitt.torrential")

set (EXEC_NAME "com.github.davidmhewitt.torrential")

# we're about to use pkgconfig to make sure dependencies are installed so let's find pkgconfig first
find_package(PkgConfig)

add_subdirectory (libtransmission)

# project name
project (com.github.davidmhewitt.torrential)

# Translation files
set (GETTEXT_PACKAGE "${CMAKE_PROJECT_NAME}")
add_definitions (-DGETTEXT_PACKAGE=\"${GETTEXT_PACKAGE}\")
add_subdirectory (po)

# now let's actually check for the required dependencies
pkg_check_modules(DEPS REQUIRED granite)

pkg_check_modules (UNITY REQUIRED unity>=4.0.0)
if (UNITY_FOUND)
    add_definitions(${UNITY_CFLAGS})
    link_directories(${UNITY_LIBRARY_DIRS})
endif ()

pkg_check_modules (ARCHIVE REQUIRED libarchive)
if (ARCHIVE_FOUND)
    add_definitions(${ARCHIVE_CFLAGS})
    link_directories(${ARCHIVE_LIBRARY_DIRS})
endif ()

add_definitions(${DEPS_CFLAGS})
link_directories(${DEPS_LIBRARY_DIRS})
include_directories(${CMAKE_SOURCE_DIR})

# make sure we have vala
find_package(Vala REQUIRED)
# make sure we use vala
include(ValaVersion)
# make sure it's the desired version of vala
ensure_vala_version("0.16" MINIMUM)

# files we want to compile
include(ValaPrecompile)
vala_precompile(VALA_C ${EXEC_NAME}
    src/Application.vala
    src/MainWindow.vala
    src/PreferencesWindow.vala
    src/TorrentManager.vala
    src/Torrent.vala
    src/Settings.vala
    src/Widgets/MultiInfoBar.vala
    src/Widgets/TorrentListBox.vala
    src/Widgets/TorrentListRow.vala
CUSTOM_VAPIS
    vapi/transmission-2.0.vapi

# tell what libraries to use when compiling
PACKAGES
    granite
    libarchive
    unity
OPTIONS
    --fatal-warnings
    --enable-deprecated
)

include (GSettings)
add_schema (data/com.github.davidmhewitt.torrential.gschema.xml)

# tell cmake what to call the executable we just made
add_executable(${EXEC_NAME} ${VALA_C})
target_link_libraries(${EXEC_NAME} ${DEPS_LIBRARIES} ${UNITY_LIBRARIES} ${ARCHIVE_LIBRARIES} libtr)

# install the binaries we just made
install (TARGETS ${EXEC_NAME} RUNTIME DESTINATION bin)

install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/16/com.github.davidmhewitt.torrential.svg DESTINATION share/icons/hicolor/16x16/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/24/com.github.davidmhewitt.torrential.svg DESTINATION share/icons/hicolor/24x24/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/32/com.github.davidmhewitt.torrential.svg DESTINATION share/icons/hicolor/32x32/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/48/com.github.davidmhewitt.torrential.svg DESTINATION share/icons/hicolor/48x48/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/64/com.github.davidmhewitt.torrential.svg DESTINATION share/icons/hicolor/64x64/apps)
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/128/com.github.davidmhewitt.torrential.svg DESTINATION share/icons/hicolor/128x128/apps)

# install our .desktop file so the Applications menu will see it
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.davidmhewitt.torrential.desktop DESTINATION ${DATADIR}/applications/)

# install our .appdata.xml file so AppCenter will see it
install (FILES ${CMAKE_CURRENT_SOURCE_DIR}/data/com.github.davidmhewitt.torrential.appdata.xml DESTINATION ${DATADIR}/metainfo/)
