cmake_minimum_required(VERSION 3.16)

find_package(Qt6 6.7 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 QuickTest)

qt_add_executable(tst_process_ui tst_process_ui.cpp)

set_source_files_properties(qml/tst_process.qml PROPERTIES QT_RESOURCE_ALIAS tst_process.qml)

qt_add_qml_module(tst_process_ui
    URI org.dylanos.process.tests
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    QML_FILES
        qml/tst_process.qml
)

target_compile_definitions(tst_process_ui PRIVATE DYLANOS_VERSION="test")

target_link_libraries(tst_process_ui PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::QuickTest
    # Modelos y módulo QML de producción: el test no usa dobles.
    dylanos_process_models
    dylanos_process_qml
    dylanos_process_qmlplugin
)

add_test(NAME process_ui COMMAND tst_process_ui -input ${CMAKE_CURRENT_SOURCE_DIR}/qml)
set_tests_properties(process_ui PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)
