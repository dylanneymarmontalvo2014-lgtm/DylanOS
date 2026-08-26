cmake_minimum_required(VERSION 3.16)

project(dylanos-app-center)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    QuickControls2
)

find_package(KF6 REQUIRED COMPONENTS
    Service
    CoreAddons
)

# ─────────────────────────────────────────
# Ejecutable
# ─────────────────────────────────────────

qt_add_executable(dylanos-app-center
    src/main.cpp
    src/appmodel.cpp
    src/iconprovider.cpp
)

# ─────────────────────────────────────────
# Módulo QML
# ─────────────────────────────────────────

qt_add_qml_module(dylanos-app-center
    URI DylanOS.AppCenter
    VERSION 1.0

    QML_FILES
        qml/Main.qml
)

# ─────────────────────────────────────────
# Librerías
# ─────────────────────────────────────────

target_link_libraries(dylanos-app-center PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2

    KF6::Service
    KF6::CoreAddons
)

# ─────────────────────────────────────────
# Instalación
# ─────────────────────────────────────────

include(GNUInstallDirs)

# Ejecutable
install(
    TARGETS dylanos-app-center
    DESTINATION ${CMAKE_INSTALL_BINDIR}
)

# Archivo .desktop
install(
    FILES dylanos-app-center.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

# Icono personalizado
install(
    FILES icons/dylanos-app-center.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/512x512/apps
)

# ─────────────────────────────────────────
# Despliegue de QML
# ─────────────────────────────────────────

include(GNUInstallDirs)

install(
    TARGETS dylanos-app-center
    DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(
    FILES dylanos-app-center.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications
)

install(
    FILES icons/dylanos-app-center.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/512x512/apps
)
