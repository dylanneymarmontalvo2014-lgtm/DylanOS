# DylanOS Store application: prototype UI (QML) + real libdiscover data layer.

set(QML_DIR qml)
set_source_files_properties(
    ${QML_DIR}/theme/Colors.qml ${QML_DIR}/theme/Metrics.qml ${QML_DIR}/theme/Typography.qml
    ${QML_DIR}/theme/Draw.qml ${QML_DIR}/theme/Strings.qml ${QML_DIR}/theme/Nav.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

file(GLOB ICON_FILES CONFIGURE_DEPENDS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/data/icons/*.svg)

set(CORE_SOURCES
    models/AppItem.h models/AppItem.cpp
    models/AppModel.h models/AppModel.cpp
    models/AppFilterModel.h models/AppFilterModel.cpp
    models/IconImageProvider.h models/IconImageProvider.cpp
    models/AppIconImageProvider.h models/AppIconImageProvider.cpp
    models/StoreController.h models/StoreController.cpp
    services/PackageBackend.h
    services/MockPackageBackend.h services/MockPackageBackend.cpp
    services/LibDiscoverBackend.h services/LibDiscoverBackend.cpp
    services/CatalogSync.h services/CatalogSync.cpp)

# Semilla del catálogo editorial: copia del SQLite del repo (catalog/store.db).
file(COPY_FILE ${CMAKE_CURRENT_SOURCE_DIR}/../../catalog/store.db ${CMAKE_CURRENT_BINARY_DIR}/store-seed.db)
set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/store-seed.db PROPERTIES QT_RESOURCE_ALIAS "data/store-seed.db")

qt_add_executable(dylanos-store main.cpp ${CORE_SOURCES})
target_include_directories(dylanos-store PRIVATE models services)
target_compile_definitions(dylanos-store PRIVATE DYLANOS_STORE_VERSION="${PROJECT_VERSION}")

qt_add_qml_module(dylanos-store
    URI DylanOS
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        ${QML_DIR}/Main.qml
        ${QML_DIR}/theme/Colors.qml ${QML_DIR}/theme/Metrics.qml ${QML_DIR}/theme/Typography.qml
        ${QML_DIR}/theme/Draw.qml ${QML_DIR}/theme/Strings.qml ${QML_DIR}/theme/Nav.qml
        ${QML_DIR}/components/Txt.qml ${QML_DIR}/components/Icon.qml ${QML_DIR}/components/RoundedBox.qml
        ${QML_DIR}/components/AppIcon.qml ${QML_DIR}/components/Btn.qml ${QML_DIR}/components/Chip.qml
        ${QML_DIR}/components/StatusBadge.qml ${QML_DIR}/components/Progress.qml ${QML_DIR}/components/Skeleton.qml
        ${QML_DIR}/components/ActionButton.qml ${QML_DIR}/components/Card.qml ${QML_DIR}/components/AutoGrid.qml
        ${QML_DIR}/components/SectionHead.qml ${QML_DIR}/components/AbstractButtonLike.qml
        ${QML_DIR}/components/AppCard.qml ${QML_DIR}/components/AppRow.qml ${QML_DIR}/components/EmptyState.qml
        ${QML_DIR}/components/ErrorBox.qml ${QML_DIR}/components/Select.qml ${QML_DIR}/components/Toggle.qml
        ${QML_DIR}/components/ConfirmDialog.qml ${QML_DIR}/components/Toasts.qml ${QML_DIR}/components/PageScaffold.qml
        ${QML_DIR}/components/Panel.qml ${QML_DIR}/components/CategoryTile.qml ${QML_DIR}/components/SidebarPanel.qml
        ${QML_DIR}/pages/HomePage.qml ${QML_DIR}/pages/CategoriesPage.qml ${QML_DIR}/pages/BrowsePage.qml
        ${QML_DIR}/pages/SearchPage.qml ${QML_DIR}/pages/DetailPage.qml ${QML_DIR}/pages/InstalledPage.qml
        ${QML_DIR}/pages/UpdatesPage.qml ${QML_DIR}/pages/LibraryPage.qml ${QML_DIR}/pages/SettingsPage.qml
)

# Plain data resources live under :/data/... (catalog for tests, config, font, icon set, logo).
qt_add_resources(dylanos-store data_resources PREFIX "/" FILES
    data/demo-apps.json data/store-config.json data/logo.png data/fonts/Onest.ttf ${ICON_FILES}
    ${CMAKE_CURRENT_BINARY_DIR}/store-seed.db)

target_link_libraries(dylanos-store PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Svg Qt6::Sql
    KF6::Crash KF6::DBusAddons KF6::I18n KF6::CoreAddons
    Discover::Common)

set_target_properties(dylanos-store PROPERTIES INSTALL_RPATH ${CMAKE_INSTALL_FULL_LIBDIR}/plasma-discover)
install(TARGETS dylanos-store ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})

configure_file(org.dylanos.store.desktop.cmake ${CMAKE_CURRENT_BINARY_DIR}/org.dylanos.store.desktop)
install(PROGRAMS ${CMAKE_CURRENT_BINARY_DIR}/org.dylanos.store.desktop DESTINATION ${KDE_INSTALL_APPDIR})

if(BUILD_STORE_TESTS)
    add_subdirectory(tests)
endif()
