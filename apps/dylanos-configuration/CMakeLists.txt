cmake_minimum_required(VERSION 3.16)
project(dylanos-configuration VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Svg DBus)

qt_add_executable(dylanos-configuration
    src/main.cpp
    src/services/SystemService.cpp
    src/services/LucideProvider.cpp
)

set_source_files_properties(qml/theme/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(dylanos-configuration
    URI org.dylanos.configuration
    VERSION 1.0
    # Prefijo estándar de Qt 6.8 (igual que DylanOS Explorer): con "/" los
    # tipos compuestos no se resuelven vía import del módulo en Qt 6.8
    # ("Toast is not a type") porque quedan fuera de los import paths del
    # engine (:/qt/qml). El binario final se carga desde
    # qrc:/qt/qml/org/dylanos/configuration/qml/Main.qml.
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/theme/Theme.qml
        qml/components/LucideIcon.qml
        qml/components/WindowControls.qml
        qml/components/IconTile.qml
        qml/components/DToggle.qml
        qml/components/DSlider.qml
        qml/components/DSelect.qml
        qml/components/DSegmented.qml
        qml/components/TabsBar.qml
        qml/components/GroupBox.qml
        qml/components/PanelBox.qml
        qml/components/RowItem.qml
        qml/components/SectionTitle.qml
        qml/components/BadgePill.qml
        qml/components/Dlg.qml
        qml/components/EmptyState.qml
        qml/components/ErrorBanner.qml
        qml/components/Meter.qml
        qml/components/SearchField.qml
        qml/components/Toast.qml
        qml/components/NavRow.qml
        qml/components/ActionButton.qml
        qml/pages/SystemPage.qml
        qml/pages/AboutPage.qml
        qml/pages/PersonalizationPage.qml
        qml/pages/NetworkPage.qml
        qml/pages/BluetoothPage.qml
        qml/pages/AppsPage.qml
        qml/pages/AccountsPage.qml
        qml/pages/DateTimePage.qml
        qml/pages/PrivacyPage.qml
        qml/pages/PowerPage.qml
        qml/pages/AccessibilityPage.qml
        qml/pages/UpdatesPage.qml
        qml/pages/DisplayPage.qml
        qml/pages/SoundPage.qml
        qml/pages/NotificationsPage.qml
        qml/pages/StoragePage.qml
        qml/Main.qml
)

qt_add_resources(dylanos-configuration "assets"
    PREFIX "/"
    FILES
        assets/icons/monitor.svg
        assets/icons/bluetooth.svg
        assets/icons/wifi.svg
        assets/icons/wifi-off.svg
        assets/icons/palette.svg
        assets/icons/layout-grid.svg
        assets/icons/user.svg
        assets/icons/globe.svg
        assets/icons/shield.svg
        assets/icons/battery.svg
        assets/icons/battery-charging.svg
        assets/icons/accessibility.svg
        assets/icons/settings-2.svg
        assets/icons/info.svg
        assets/icons/sun.svg
        assets/icons/moon.svg
        assets/icons/volume-2.svg
        assets/icons/volume-x.svg
        assets/icons/bell.svg
        assets/icons/hard-drive.svg
        assets/icons/image.svg
        assets/icons/refresh-cw.svg
        assets/icons/cpu.svg
        assets/icons/memory-stick.svg
        assets/icons/laptop.svg
        assets/icons/chevron-right.svg
        assets/icons/chevron-down.svg
        assets/icons/chevron-left.svg
        assets/icons/check.svg
        assets/icons/search.svg
        assets/icons/x.svg
        assets/icons/menu.svg
        assets/icons/arrow-left.svg
        assets/icons/trash-2.svg
        assets/icons/zap.svg
        assets/icons/speaker.svg
        assets/icons/mic.svg
        assets/icons/headphones.svg
        assets/icons/keyboard.svg
        assets/icons/mouse.svg
        assets/icons/smartphone.svg
        assets/icons/network.svg
        assets/icons/camera.svg
        assets/icons/map-pin.svg
        assets/icons/eye.svg
        assets/icons/type.svg
        assets/icons/contrast.svg
        assets/icons/languages.svg
        assets/icons/log-out.svg
        assets/icons/circle-check-big.svg
        assets/icons/loader-circle.svg
        assets/icons/rotate-ccw.svg
        assets/icons/package.svg
        assets/icons/play.svg
        assets/icons/link-2.svg
        assets/icons/folder-open.svg
        assets/icons/mail.svg
        assets/icons/clock.svg
        assets/icons/lock.svg
        assets/icons/power.svg
        assets/icons/sliders-horizontal.svg
        assets/icons/box.svg
        assets/icons/download.svg
)

target_link_libraries(dylanos-configuration PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Svg Qt6::DBus
)

# El logo oficial (branding/logo.png) se incrusta en el binario cuando está
# presente; scripts/build.sh lo copia al árbol fuente antes de configurar.
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/logo.png")
    qt_add_resources(dylanos-configuration "logo"
        PREFIX "/"
        FILES assets/logo.png
    )
endif()

install(TARGETS dylanos-configuration RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES assets/org.dylanos.configuration.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES assets/dylanos-configuration.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
# El PNG 512 es la variante rasterizada del icono (para kits que no escalan SVG).
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/assets/dylanos-configuration.png")
    install(FILES assets/dylanos-configuration.png DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/512x512/apps)
endif()

# --- Prueba de humo de QML (opcional) -----------------------------------------
find_package(Qt6 6.4 QUIET COMPONENTS QuickTest)
