cmake_minimum_required(VERSION 3.16)
project(dylanos-calculator VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

include(GNUInstallDirs)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2)

qt_add_executable(dylanos-calculator
    src/main.cpp
)

qt_add_qml_module(dylanos-calculator
    URI org.dylanos.calculator
    VERSION 1.0
    QML_FILES
        qml/Main.qml
        qml/CalcButton.qml
)

target_link_libraries(dylanos-calculator PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
)

install(TARGETS dylanos-calculator DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES data/org.dylanos.calculator.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES icons/com.dylanos.calculator.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
    RENAME com.dylanos.calculator.svg
)
