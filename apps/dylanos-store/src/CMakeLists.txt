cmake_minimum_required(VERSION 3.21)

project(dylanos-store VERSION 1.0.0 LANGUAGES CXX)

set(QT_MIN_VERSION "6.7.0")
set(KF6_MIN_VERSION "6.10.0")
set(KDE_COMPILERSETTINGS_LEVEL "5.85")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)

set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH} "${CMAKE_SOURCE_DIR}/cmake")

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMInstallIcons)
include(ECMMarkAsTest)
include(GenerateExportHeader)
include(ECMQtDeclareLoggingCategory)
include(ECMDeprecationSettings)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED CONFIG COMPONENTS Core Gui Qml Quick QuickControls2 Svg Sql Test Network Concurrent DBus)

find_package(PkgConfig REQUIRED)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED CoreAddons Config Crash DBusAddons I18n Archive KIO Notifications StatusNotifierItem IconThemes IdleTime)

find_package(packagekitqt6 1.0.1 CONFIG REQUIRED)
find_package(AppStreamQt 1.0 CONFIG REQUIRED)

pkg_check_modules(Flatpak IMPORTED_TARGET flatpak>=0.11.8)

find_package(QCoro6 REQUIRED COMPONENTS Core)

qcoro_enable_coroutines()

list(APPEND CMAKE_AUTOMOC_MACRO_NAMES "DISCOVER_BACKEND_PLUGIN")

ecm_set_disabled_deprecation_versions(QT 6.8.1
    KF 6.9.0
)

add_definitions(-DQT_NO_SIGNALS_SLOTS_KEYWORDS -DQT_NO_URL_CAST_FROM_STRING)

option(BUILD_STORE_TESTS "Build the DylanOS Store unit tests" ON)
if (BUILD_STORE_TESTS)
    enable_testing()
endif()
# libdiscover's own test suite depends on ecm_add_test fixtures we do not ship;
# the store's unit tests are driven by BUILD_STORE_TESTS instead.
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)

configure_file(DiscoverVersion.h.in DiscoverVersion.h)

# Backends: PackageKit + Flatpak. The rest are disabled for DylanOS.
set(BUILD_SnapBackend OFF CACHE BOOL "" FORCE)
set(BUILD_FwupdBackend OFF CACHE BOOL "" FORCE)
set(BUILD_RpmOstreeBackend OFF CACHE BOOL "" FORCE)
set(BUILD_AlpineApkBackend OFF CACHE BOOL "" FORCE)
set(BUILD_SteamOSBackend OFF CACHE BOOL "" FORCE)

add_subdirectory(libdiscover)
add_subdirectory(store)

option(WITH_NOTIFIER "Build and install the update notifier" ON)
if(WITH_NOTIFIER)
    add_subdirectory(notifier)
endif()

add_feature_info(Flatpak Flatpak_FOUND
                "Library that exposes flatpak repositories. Required to build the Flatpak backend")
