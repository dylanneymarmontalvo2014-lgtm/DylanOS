cmake_minimum_required(VERSION 3.16)
project(dylanos-widgets VERSION 1.0.0 LANGUAGES CXX)

set(DYLANOS_RELEASE "1.1.0-pre-beta" CACHE STRING "Versión DylanOS mostrada por la galería")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

qt_add_executable(dylanos-widgets
    src/main.cpp
)

set_source_files_properties(qml/WidgetCatalog.js PROPERTIES QT_RESOURCE_ALIAS WidgetCatalog.js)

qt_add_qml_module(dylanos-widgets
    URI org.dylanos.widgets.gallery
    VERSION 1.0
    # Prefijo estándar de Qt 6.8 (mismo criterio que Configuration y Explorer):
    # con "/" los tipos compuestos no se resuelven por import.
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/Main.qml
        qml/CatalogCard.qml
        qml/WidgetCatalog.js
        qml/lib/WidgetTokens.js
        qml/lib/qmldir
        qml/lib/WidgetCard.qml
        qml/lib/WidgetHeader.qml
)

target_compile_definitions(dylanos-widgets PRIVATE
    DYLANOS_VERSION="${DYLANOS_RELEASE}"
)

target_link_libraries(dylanos-widgets PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

install(TARGETS dylanos-widgets DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES assets/org.dylanos.widgets.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES assets/org.dylanos.widgets.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
