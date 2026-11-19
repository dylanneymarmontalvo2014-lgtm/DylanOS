cmake_minimum_required(VERSION 3.16)

project(dylanos-process VERSION 1.0.0 LANGUAGES C CXX)

# El núcleo de datos es Rust (core/): se compila como librería estática con
# cargo y se enlaza al binario Qt. Sin dependencias externas del crate, así que
# `cargo build --offline` funciona dentro del chroot sin red.
set(DYLANOS_RELEASE "1.1.0-pre-beta" CACHE STRING "Versión DylanOS mostrada por la app")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)

find_package(Qt6 6.7 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

option(DYLANOS_PROCESS_SKIP_CORE "Enlaza una libcore.a ya construida (sin cargo)" OFF)

set(CORE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/core)
set(CORE_LIB ${CORE_DIR}/target/release/libdylanos_process_core.a)

if(NOT DYLANOS_PROCESS_SKIP_CORE)
    find_program(CARGO_EXECUTABLE cargo REQUIRED)
    add_custom_command(
        OUTPUT ${CORE_LIB}
        COMMAND ${CARGO_EXECUTABLE} build --release --offline --locked
                --manifest-path ${CORE_DIR}/Cargo.toml
        COMMENT "Compilando el núcleo Rust de DylanOS Process"
        VERBATIM
    )
    add_custom_target(dylanos_process_core ALL DEPENDS ${CORE_LIB})
endif()

if(NOT EXISTS ${CORE_LIB})
    message(FATAL_ERROR
        "Falta ${CORE_LIB}. Compílalo con: cd ${CORE_DIR} && cargo build --release")
endif()

# ── Modelos (librería estática) ─────────────────────────────────────────────
# Los tests enlazan esta MISMA librería: ejercitan el código de producción.
add_library(dylanos_process_models STATIC
    src/processmodel.cpp
    src/processmodel.h
    src/applicationmodel.cpp
    src/applicationmodel.h
    src/servicemodel.cpp
    src/servicemodel.h
    src/processcontroller.cpp
    src/processcontroller.h
    src/iconprovider.cpp
    src/iconprovider.h
    src/coreapi.h
)

target_include_directories(dylanos_process_models PUBLIC src)
target_link_libraries(dylanos_process_models PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    ${CORE_LIB}
    stdc++
    pthread
    dl
    m
)
if(TARGET dylanos_process_core)
    add_dependencies(dylanos_process_models dylanos_process_core)
endif()

# ── Módulo QML (librería estática) ──────────────────────────────────────────
# Separado del ejecutable para que los tests QtQuickTest puedan importarlo.
#
# Los singletons Theme y Format se marcan con QT_QML_SINGLETON_TYPE para que
# CMake los registre en el qmldir generado. NO se les pone QT_RESOURCE_ALIAS: al
# aliasarlos a la raíz del módulo quedaban en otro directorio que sus
# consumidores y QML fallaba con "Theme is not defined". El qmldir también lo
# genera CMake: escribirlo a mano choca con el generado.
set_source_files_properties(qml/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Format.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_library(dylanos_process_qml STATIC)

qt_add_qml_module(dylanos_process_qml
    URI org.dylanos.process
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/Main.qml
        qml/Theme.qml
        qml/Format.qml
        qml/TitleBar.qml
        qml/WindowButton.qml
        qml/TabBar.qml
        qml/ResourceCard.qml
        qml/ResourceCards.qml
        qml/FilterChip.qml
        qml/StateBadge.qml
        qml/PerformanceChart.qml
        qml/PerfCard.qml
        qml/ActionButton.qml
        qml/ProcessIcon.qml
        qml/TableCell.qml
        qml/HeaderCell.qml
        qml/DetailStat.qml
        qml/DetailRow.qml
        qml/ProcessesPage.qml
        qml/PerformancePage.qml
        qml/ApplicationsPage.qml
        qml/ServicesPage.qml
        qml/StatusFooter.qml
)

target_link_libraries(dylanos_process_qml PUBLIC
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    dylanos_process_models
)

# ── Ejecutable ──────────────────────────────────────────────────────────────
qt_add_executable(dylanos-process src/main.cpp)

target_compile_definitions(dylanos-process PRIVATE
    DYLANOS_VERSION="${DYLANOS_RELEASE}"
)

target_link_libraries(dylanos-process PRIVATE
    dylanos_process_qml
    # Plugin estático del módulo: necesario para Q_IMPORT_QML_PLUGIN y para que
    # `import org.dylanos.process` resuelva dentro de la propia app.
    dylanos_process_qmlplugin
    dylanos_process_models
)

install(TARGETS dylanos-process RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES org.dylanos.process.desktop
    DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES org.dylanos.process.metainfo.xml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo)

# ── Tests ───────────────────────────────────────────────────────────────────
option(DYLANOS_PROCESS_BUILD_TESTS "Compila los tests QtQuickTest de la app" ON)
if(DYLANOS_PROCESS_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
