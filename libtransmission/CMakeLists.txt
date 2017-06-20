project(libtr)

cmake_minimum_required(VERSION 2.8.12 FATAL_ERROR)

include(CheckIncludeFile)
include(CheckIncludeFiles)
include(CheckFunctionExists)
include(CheckLibraryExists)
include(ExternalProject)
include(GNUInstallDirs)
include(TrMacros)

        option(ENABLE_UTP           "Build µTP support" ON)
        option(ENABLE_NLS           "Enable native language support" ON)
        option(INSTALL_DOC          "Build/install documentation" ON)
        option(INSTALL_LIB          "Install the library" OFF)
tr_auto_option(USE_SYSTEM_EVENT2    "Use system event2 library" AUTO)
tr_auto_option(USE_SYSTEM_DHT       "Use system dht library" AUTO)
tr_auto_option(USE_SYSTEM_MINIUPNPC "Use system miniupnpc library" AUTO)
tr_auto_option(USE_SYSTEM_NATPMP    "Use system natpmp library" AUTO)
tr_auto_option(USE_SYSTEM_UTP       "Use system utp library" AUTO)
tr_auto_option(USE_SYSTEM_B64       "Use system b64 library" AUTO)
tr_list_option(WITH_CRYPTO          "Use specified crypto library" AUTO openssl cyassl polarssl)
tr_auto_option(WITH_INOTIFY         "Enable inotify support (on systems that support it)" AUTO)
tr_auto_option(WITH_KQUEUE          "Enable kqueue support (on systems that support it)" AUTO)
tr_auto_option(WITH_LIBAPPINDICATOR "Use libappindicator in GTK+ client" AUTO)
tr_auto_option(WITH_SYSTEMD         "Add support for systemd startup notification (on systems that support it)" AUTO)

set(TR_NAME ${PROJECT_NAME})

# convention: -TR MAJOR MINOR MAINT STATUS - (each a single char)
# STATUS: "X" for prerelease beta builds,
#         "Z" for unsupported trunk builds,
#         "0" for stable, supported releases
# these should be the only two lines you need to change
set(TR_USER_AGENT_PREFIX "2.92+")
set(TR_PEER_ID_PREFIX "-TR292Z-")

string(REGEX MATCH "^([0-9]+)\\.([0-9]+).*" TR_VERSION "${TR_USER_AGENT_PREFIX}")
set(TR_VERSION_MAJOR "${CMAKE_MATCH_1}")
set(TR_VERSION_MINOR "${CMAKE_MATCH_2}")

if(TR_PEER_ID_PREFIX MATCHES "X-$")
    set(TR_BETA_RELEASE 1)
elseif(TR_PEER_ID_PREFIX MATCHES "Z-$")
    set(TR_NIGHTLY_RELEASE 1)
else()
    set(TR_STABLE_RELEASE 1)
endif()

set(TR_VCS_REVISION_FILE "${CMAKE_SOURCE_DIR}/REVISION")

if("${TR_VCS_REVISION}" STREQUAL "" AND EXISTS "${TR_VCS_REVISION_FILE}")
    file(READ "${TR_VCS_REVISION_FILE}" TR_VCS_REVISION)
endif()

string(STRIP "${TR_VCS_REVISION}" TR_VCS_REVISION)

if(NOT "${TR_VCS_REVISION}" STREQUAL "")
    file(WRITE "${TR_VCS_REVISION_FILE}" "${TR_VCS_REVISION}\n")
else()
    set(TR_VCS_REVISION 0)
    file(REMOVE "${TR_VCS_REVISION_FILE}")
endif()

string(SUBSTRING "${TR_VCS_REVISION}" 0 10 TR_VCS_REVISION)

set_property(GLOBAL PROPERTY USE_FOLDERS ON)

set(CURL_MINIMUM            7.15.4)
set(EVENT2_MINIMUM          2.0.10)
set(OPENSSL_MINIMUM         0.9.7)
set(CYASSL_MINIMUM          3.0)
set(POLARSSL_MINIMUM        1.2)
set(ZLIB_MINIMUM            1.2.3)
set(GLIB_MINIMUM            2.32.0)
set(GIO_MINIMUM             2.26.0)
set(LIBAPPINDICATOR_MINIMUM 0.4.90)

find_package(Threads)
find_package(PkgConfig QUIET)

find_package(CURL ${CURL_MINIMUM} REQUIRED)

find_package(ICONV)

set(CRYPTO_PKG "")
if(WITH_CRYPTO STREQUAL "AUTO" OR WITH_CRYPTO STREQUAL "openssl")
    tr_get_required_flag(WITH_CRYPTO OPENSSL_IS_REQUIRED)
    find_package(OpenSSL ${OPENSSL_MINIMUM} ${OPENSSL_IS_REQUIRED})
    tr_fixup_list_option(WITH_CRYPTO "openssl" OPENSSL_FOUND "AUTO" OPENSSL_IS_REQUIRED)
    if(WITH_CRYPTO STREQUAL "openssl")
        set(CRYPTO_PKG "openssl")
        set(CRYPTO_INCLUDE_DIRS ${OPENSSL_INCLUDE_DIR})
        set(CRYPTO_LIBRARIES ${OPENSSL_LIBRARIES})
    endif()
endif()
if(WITH_CRYPTO STREQUAL "AUTO" OR WITH_CRYPTO STREQUAL "cyassl")
    tr_get_required_flag(WITH_CRYPTO CYASSL_IS_REQUIRED)
    find_package(CyaSSL ${CYASSL_MINIMUM} ${CYASSL_IS_REQUIRED})
    tr_fixup_list_option(WITH_CRYPTO "cyassl" CYASSL_FOUND "AUTO" CYASSL_IS_REQUIRED)
    if(WITH_CRYPTO STREQUAL "cyassl")
        set(CRYPTO_PKG "cyassl")
        set(CRYPTO_INCLUDE_DIRS ${CYASSL_INCLUDE_DIRS})
        set(CRYPTO_LIBRARIES ${CYASSL_LIBRARIES})
    endif()
endif()
if(WITH_CRYPTO STREQUAL "AUTO" OR WITH_CRYPTO STREQUAL "polarssl")
    tr_get_required_flag(WITH_CRYPTO POLARSSL_IS_REQUIRED)
    find_package(PolarSSL ${POLARSSL_MINIMUM} ${POLARSSL_IS_REQUIRED})
    tr_fixup_list_option(WITH_CRYPTO "polarssl" POLARSSL_FOUND "AUTO" POLARSSL_IS_REQUIRED)
    if(WITH_CRYPTO STREQUAL "polarssl")
        set(CRYPTO_PKG "polarssl")
        set(CRYPTO_INCLUDE_DIRS ${POLARSSL_INCLUDE_DIRS})
        set(CRYPTO_LIBRARIES ${POLARSSL_LIBRARIES})
    endif()
endif()
# We should have found the library by now
if(CRYPTO_PKG STREQUAL "")
    if(WITH_CRYPTO STREQUAL "AUTO")
        message(FATAL_ERROR "Unable to find any supported crypto library.")
    else()
        message(FATAL_ERROR "Requested crypto library '${WITH_CRYPTO}' is not supported.")
    endif()
endif()

find_package(ZLIB ${ZLIB_MINIMUM})
if(ZLIB_FOUND)
    add_definitions(-DHAVE_ZLIB)
endif()

set(EVENT2_CONFIGURE_FLAGS)
tr_add_external_auto_library(EVENT2 libevent event
    BUILD_IN_SOURCE 1
    CONFIGURE_COMMAND "<SOURCE_DIR>/autogen.sh"
              COMMAND "<SOURCE_DIR>/configure" "--prefix=<INSTALL_DIR>" "--disable-shared" ${EVENT2_CONFIGURE_FLAGS})

set(THIRD_PARTY_DIR ${CMAKE_SOURCE_DIR}/third-party)

tr_add_external_auto_library(NATPMP libnatpmp natpmp)
if(NOT USE_SYSTEM_NATPMP)
    set(NATPMP_DEFINITIONS -DNATPMP_STATICLIB)
endif()

tr_add_external_auto_library(MINIUPNPC miniupnpc miniupnpc
    CMAKE_ARGS
        -DUPNPC_BUILD_STATIC=ON
        -DUPNPC_BUILD_SHARED=OFF
        -DUPNPC_BUILD_TESTS=OFF)
set(MINIUPNPC_DEFINITIONS -DSYSTEM_MINIUPNP)
if(NOT USE_SYSTEM_MINIUPNPC)
    list(APPEND MINIUPNPC_DEFINITIONS -DMINIUPNP_STATICLIB)
    set(MINIUPNPC_VERSION 1.9)
    set(MINIUPNPC_API_VERSION 12)
endif()

tr_add_external_auto_library(DHT dht dht)

if(ENABLE_UTP)
    tr_add_external_auto_library(UTP libutp utp)

    if(UTP_UPSTREAM_TARGET)
        # Use C++ linker for anything that depends on static libutp
        # TODO: switch to imported targets for all the dependencies
        add_library(UTP::UTP STATIC IMPORTED)
        set_property(TARGET UTP::UTP PROPERTY IMPORTED_LOCATION "${UTP_LIBRARIES}")
        set_property(TARGET UTP::UTP PROPERTY IMPORTED_LINK_INTERFACE_LANGUAGES "CXX")
        set(UTP_LIBRARIES UTP::UTP)
    endif()
endif()

tr_add_external_auto_library(B64 libb64 b64)

if(WITH_INOTIFY)
    tr_get_required_flag(WITH_INOTIFY INOTIFY_IS_REQUIRED)

    set(INOTIFY_FOUND OFF)
    check_include_file(sys/inotify.h HAVE_SYS_INOTIFY_H)
    check_function_exists(inotify_init HAVE_INOTIFY_INIT)
    if(HAVE_SYS_INOTIFY_H AND HAVE_INOTIFY_INIT)
        set(INOTIFY_FOUND ON)
    endif()

    tr_fixup_auto_option(WITH_INOTIFY INOTIFY_FOUND INOTIFY_IS_REQUIRED)
endif()

if(WITH_KQUEUE)
    tr_get_required_flag(WITH_KQUEUE KQUEUE_IS_REQUIRED)

    set(KQUEUE_FOUND OFF)
    check_include_files("sys/types.h;sys/event.h" HAVE_SYS_EVENT_H)
    check_function_exists(kqueue HAVE_KQUEUE)
    if(HAVE_SYS_EVENT_H AND HAVE_KQUEUE)
        set(KQUEUE_FOUND ON)
    endif()

    tr_fixup_auto_option(WITH_KQUEUE KQUEUE_FOUND KQUEUE_IS_REQUIRED)
endif()

if(WITH_SYSTEMD)
    tr_get_required_flag(WITH_SYSTEMD SYSTEMD_IS_REQUIRED)
    find_package(SYSTEMD)
    tr_fixup_auto_option(WITH_SYSTEMD SYSTEMD_FOUND SYSTEMD_IS_REQUIRED)
endif()

include_directories(${CMAKE_BINARY_DIR})

if(CMAKE_VERSION VERSION_LESS "3.1")
    if(CMAKE_C_COMPILER_ID STREQUAL "GNU" OR CMAKE_C_COMPILER_ID STREQUAL "Clang")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=gnu99")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++11")
    endif()
else()
    set(CMAKE_C_STANDARD 99)
    set(CMAKE_C_STANDARD_REQUIRED ON)
    set(CMAKE_CXX_STANDARD 11)
    set(CMAKE_CXX_STANDARD_REQUIRED ON)
endif()

if(CMAKE_C_COMPILER_ID STREQUAL "GNU" OR CMAKE_C_COMPILER_ID STREQUAL "Clang")
    set(NEEDED_COMPILER_FLAGS
        -Wall
        -W
        -Wcast-align
        -Wfloat-equal
        -Wmissing-format-attribute
        -Wpointer-arith
        -Wredundant-decls
        -Wundef
        -Wunused-parameter
        -Wwrite-strings)

    if(NOT CMAKE_C_COMPILER_ID STREQUAL "GNU" OR CMAKE_C_COMPILER_VERSION VERSION_GREATER "3.3")
        list(APPEND NEEDED_COMPILER_FLAGS
            -Wextra
            -Winit-self)
    endif()

    if(MINGW)
        # Disable excessive warnings since we're using __USE_MINGW_ANSI_STDIO
        # Hopefully, any potential issues will be spotted on other platforms
        list(APPEND NEEDED_COMPILER_FLAGS -Wno-format)
    else()
        list(APPEND NEEDED_COMPILER_FLAGS -Wformat-security)
    endif()

    set(NEEDED_C_COMPILER_FLAGS
        ${NEEDED_COMPILER_FLAGS}
        -Winline
        -Wmissing-declarations
        -Wnested-externs
        -Wstrict-prototypes)
    string(REPLACE ";" " " NEEDED_C_COMPILER_FLAGS_STRING "${NEEDED_C_COMPILER_FLAGS}")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${NEEDED_C_COMPILER_FLAGS_STRING}")

    set(NEEDED_CXX_COMPILER_FLAGS
        ${NEEDED_COMPILER_FLAGS})
    string(REPLACE ";" " " NEEDED_CXX_COMPILER_FLAGS_STRING "${NEEDED_CXX_COMPILER_FLAGS}")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${NEEDED_CXX_COMPILER_FLAGS_STRING}")
endif()

include(LargeFileSupport)

set(NEEDED_HEADERS
    sys/statvfs.h
    xfs/xfs.h
    xlocale.h)

if(ENABLE_NLS)
    list(APPEND NEEDED_HEADERS libintl.h)
endif()

foreach(H ${NEEDED_HEADERS})
    tr_make_id("${H}" H_ID)
    check_include_file(${H} HAVE_${H_ID})
    if(HAVE_${H_ID})
        add_definitions(-DHAVE_${H_ID})
    endif()
endforeach()

set(NEEDED_FUNCTIONS
    _configthreadlocale
    canonicalize_file_name
    daemon
    fallocate64
    getmntent
    getpagesize
    htonll
    localtime_r
    memmem
    mkdtemp
    ntohll
    posix_fadvise
    posix_fallocate
    posix_memalign
    pread
    pwrite
    statvfs
    strlcpy
    strsep
    syslog
    uselocale
    valloc)

foreach(F ${NEEDED_FUNCTIONS})
    tr_make_id("${F}" F_ID)
    check_function_exists(${F} HAVE_${F_ID})
    if(HAVE_${F_ID})
        add_definitions(-DHAVE_${F_ID})
    endif()
endforeach()

if(ICONV_FOUND)
    add_definitions(-DHAVE_ICONV)
    if(ICONV_SECOND_ARGUMENT_IS_CONST)
        add_definitions(-DICONV_SECOND_ARGUMENT_IS_CONST)
    endif()
endif()

if(ENABLE_NLS)
    check_library_exists(intl libintl_gettext "" HAVE_LIBINTL)
    if(HAVE_LIBINTL)
        set(LIBINTL_LIBRARY intl)
    endif()
endif()

check_library_exists(m sqrt "" HAVE_LIBM)
if(HAVE_LIBM)
    set(LIBM_LIBRARY m)
endif()

set(TR_NETWORK_LIBRARIES)

if(ENABLE_TESTS)
    enable_testing()
endif()

configure_file(version.h.in version.h)

set(${PROJECT_NAME}_SOURCES
    announcer.c
    announcer-http.c
    announcer-udp.c
    bandwidth.c
    bitfield.c
    blocklist.c
    cache.c
    clients.c
    completion.c
    ConvertUTF.c
    crypto.c
    crypto-utils.c
    crypto-utils-cyassl.c
    crypto-utils-fallback.c
    crypto-utils-openssl.c
    crypto-utils-polarssl.c
    error.c
    fdlimit.c
    file.c
    file-posix.c
    file-win32.c
    handshake.c
    history.c
    inout.c
    list.c
    log.c
    magnet.c
    makemeta.c
    metainfo.c
    natpmp.c
    net.c
    peer-io.c
    peer-mgr.c
    peer-msgs.c
    platform.c
    platform-quota.c
    port-forwarding.c
    ptrarray.c
    quark.c
    resume.c
    rpcimpl.c
    rpc-server.c
    session.c
    session-id.c
    stats.c
    torrent.c
    torrent-ctor.c
    torrent-magnet.c
    tr-dht.c
    trevent.c
    tr-assert.c
    tr-getopt.c
    tr-lpd.c
    tr-udp.c
    tr-utp.c
    upnp.c
    utils.c
    variant-benc.c
    variant.c
    variant-json.c
    verify.c
    watchdir.c
    watchdir-generic.c
    watchdir-inotify.c
    watchdir-kqueue.c
    watchdir-win32.c
    web.c
    webseed.c
    wildmat.c
)

set_source_files_properties(crypto-utils-fallback.c PROPERTIES HEADER_FILE_ONLY ON)
foreach(CP cyassl openssl polarssl)
    if(NOT CP STREQUAL CRYPTO_PKG)
        set_source_files_properties(crypto-utils-${CP}.c PROPERTIES HEADER_FILE_ONLY ON)
    endif()
endforeach()

if(WITH_INOTIFY)
    add_definitions(-DWITH_INOTIFY)
else()
    set_source_files_properties(watchdir-inotify.c PROPERTIES HEADER_FILE_ONLY ON)
endif()

if(WITH_KQUEUE)
    add_definitions(-DWITH_KQUEUE)
else()
    set_source_files_properties(watchdir-kqueue.c PROPERTIES HEADER_FILE_ONLY ON)
endif()

if(WIN32)
    set_source_files_properties(file-posix.c PROPERTIES HEADER_FILE_ONLY ON)
else()
    set_source_files_properties(file-win32.c watchdir-win32.c PROPERTIES HEADER_FILE_ONLY ON)
endif()

set(${PROJECT_NAME}_PUBLIC_HEADERS
    error.h
    error-types.h
    file.h
    log.h
    makemeta.h
    quark.h
    rpcimpl.h
    session-id.h
    tr-assert.h
    tr-getopt.h
    transmission.h
    utils.h
    variant.h
    watchdir.h
    web.h
    ${PROJECT_BINARY_DIR}/version.h
)

set(${PROJECT_NAME}_PRIVATE_HEADERS
    announcer-common.h
    announcer.h
    bandwidth.h
    bitfield.h
    blocklist.h
    cache.h
    clients.h
    completion.h
    ConvertUTF.h
    crypto.h
    crypto-utils.h
    fdlimit.h
    handshake.h
    history.h
    inout.h
    list.h
    magnet.h
    metainfo.h
    natpmp_local.h
    net.h
    peer-common.h
    peer-io.h
    peer-mgr.h
    peer-msgs.h
    platform.h
    platform-quota.h
    port-forwarding.h
    ptrarray.h
    resume.h
    rpc-server.h
    session.h
    stats.h
    torrent.h
    torrent-magnet.h
    tr-dht.h
    trevent.h
    tr-lpd.h
    tr-udp.h
    tr-utp.h
    upnp.h
    variant-common.h
    verify.h
    version.h
    watchdir-common.h
    webseed.h
)

if(NOT ENABLE_UTP)
    set_source_files_properties(tr-utp.c PROPERTIES HEADER_FILE_ONLY ON)
endif()

add_definitions(
    -D__TRANSMISSION__
    "-DPACKAGE_DATA_DIR=\"${CMAKE_INSTALL_FULL_DATAROOTDIR}\""
    ${NATPMP_DEFINITIONS}
    ${MINIUPNPC_DEFINITIONS}
)

if(ENABLE_LIGHTWEIGHT)
    add_definitions(-DTR_LIGHTWEIGHT)
endif()

if(NOT ENABLE_NLS)
    add_definitions(-DDISABLE_GETTEXT)
endif()

if(ENABLE_UTP)
    add_definitions(-DWITH_UTP)
endif()

if(MINIUPNPC_VERSION VERSION_LESS 1.7)
    # API version macro was only added in 1.7
    add_definitions(-DMINIUPNPC_API_VERSION=${MINIUPNPC_API_VERSION})
endif()

if(USE_SYSTEM_B64)
    add_definitions(-DUSE_SYSTEM_B64)
endif()

if(CYASSL_IS_WOLFSSL)
    add_definitions(-DCYASSL_IS_WOLFSSL)
endif()

if(POLARSSL_IS_MBEDTLS)
    add_definitions(-DPOLARSSL_IS_MBEDTLS)
endif()

include_directories(
    ${PROJECT_SOURCE_DIR}
    ${PROJECT_BINARY_DIR}
    ${ZLIB_INCLUDE_DIRS}
    ${CRYPTO_INCLUDE_DIRS}
    ${CURL_INCLUDE_DIRS}
    ${EVENT2_INCLUDE_DIRS}
    ${NATPMP_INCLUDE_DIRS}
    ${MINIUPNPC_INCLUDE_DIRS}
    ${DHT_INCLUDE_DIRS}
    ${UTP_INCLUDE_DIRS}
    ${B64_INCLUDE_DIRS}
)

if(ICONV_FOUND)
    include_directories(${ICONV_INCLUDE_DIRS})
endif()

if(ENABLE_UTP)
    include_directories(${TP_TOP}/libutp)
endif()

add_library(${TR_NAME} STATIC
    ${${PROJECT_NAME}_SOURCES}
    ${${PROJECT_NAME}_PUBLIC_HEADERS}
    ${${PROJECT_NAME}_PRIVATE_HEADERS}
)

foreach(UT ${EVENT2_UPSTREAM_TARGET}
           ${NATPMP_UPSTREAM_TARGET}
           ${MINIUPNPC_UPSTREAM_TARGET}
           ${DHT_UPSTREAM_TARGET}
           ${UTP_UPSTREAM_TARGET}
           ${B64_UPSTREAM_TARGET})
    add_dependencies(${TR_NAME} ${UT})
endforeach()

target_link_libraries(${TR_NAME}
    ${CMAKE_THREAD_LIBS_INIT}
    ${ZLIB_LIBRARIES}
    ${CRYPTO_LIBRARIES}
    ${CURL_LIBRARIES}
    ${EVENT2_LIBRARIES}
    ${NATPMP_LIBRARIES}
    ${MINIUPNPC_LIBRARIES}
    ${DHT_LIBRARIES}
    ${UTP_LIBRARIES}
    ${B64_LIBRARIES}
    ${LIBINTL_LIBRARY}
    ${LIBM_LIBRARY}
    ${TR_NETWORK_LIBRARIES}
)

if(ICONV_FOUND)
    target_link_libraries(${TR_NAME} ${ICONV_LIBRARIES})
endif()

if(ENABLE_TESTS)
    add_library(${TR_NAME}-test STATIC
        libtransmission-test.c
        libtransmission-test.h
    )

    target_link_libraries(${TR_NAME}-test ${TR_NAME})
    set_property(TARGET ${TR_NAME}-test PROPERTY FOLDER "UnitTests")

    set(crypto-test_ADD_SOURCES crypto-test-ref.h)

    set(watchdir@generic-test_DEFINITIONS WATCHDIR_TEST_FORCE_GENERIC)

    foreach(T bitfield blocklist clients crypto error file history json magnet makemeta metainfo move peer-msgs quark rename rpc
              session tr-getopt utils variant watchdir watchdir@generic)
        set(TP ${TR_NAME}-test-${T})
        if(T MATCHES "^([^@]+)@.+$")
            string(REPLACE "@" "_" TP "${TP}")
            set(${TP}_TEST_BASENAME "${CMAKE_MATCH_1}")
        else()
            set(${TP}_TEST_BASENAME "${T}")
        endif()
        add_executable(${TP} ${${TP}_TEST_BASENAME}-test.c ${${T}-test_ADD_SOURCES})
        target_link_libraries(${TP} ${TR_NAME} ${TR_NAME}-test)
        if(DEFINED ${T}-test_DEFINITIONS)
            target_compile_definitions(${TP} PRIVATE ${${T}-test_DEFINITIONS})
        endif()
        add_test(NAME ${T} COMMAND ${TP})
        set_property(TARGET ${TP} PROPERTY FOLDER "UnitTests")
    endforeach()
endif()

if(INSTALL_LIB)
    install(TARGETS ${TR_NAME} DESTINATION ${CMAKE_INSTALL_LIBDIR})
    install(FILES ${${PROJECT_NAME}_PUBLIC_HEADERS} DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${TR_NAME})
endif()
