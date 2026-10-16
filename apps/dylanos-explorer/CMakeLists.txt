cmake_minimum_required(VERSION 3.21)
project(DylanOSExplorer VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# Qt 6.4 is what Debian 12 ships; Debian 13 ships 6.8. Nothing newer is required.
find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Concurrent)
find_package(Qt6 6.4 QUIET OPTIONAL_COMPONENTS Test)
qt_standard_project_setup()

# --- Pure Qt Core services (also linked by the unit tests) -------------------
add_library(explorer_services STATIC
    src/services/FileOperations.cpp
    src/services/FileOperations.h
    src/services/Formatters.cpp
    src/services/Formatters.h
)
target_include_directories(explorer_services PUBLIC src)
target_link_libraries(explorer_services PUBLIC Qt6::Core)

# --- Application --------------------------------------------------------------
qt_add_executable(dylanos-explorer src/main.cpp)

set_source_files_properties(qml/theme/Theme.qml qml/theme/Icons.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(dylanos-explorer
    URI DylanOS.Explorer
    VERSION 1.0
    RESOURCE_PREFIX /qt/qml
    SOURCES
        src/models/FileListModel.cpp
        src/models/FileListModel.h
        src/models/PlacesService.cpp
        src/models/PlacesService.h
        src/services/ExplorerController.cpp
        src/services/ExplorerController.h
    QML_FILES
        qml/Main.qml
        qml/theme/Theme.qml
        qml/theme/Icons.qml
        qml/components/Txt.qml
        qml/components/Icon.qml
        qml/components/IconButton.qml
        qml/components/DButton.qml
        qml/components/DScrollBar.qml
        qml/components/FolderIcon.qml
        qml/components/FileTypeIcon.qml
        qml/components/WindowControls.qml
        qml/components/ResizeEdge.qml
        qml/components/Sidebar.qml
        qml/components/SidebarItem.qml
        qml/components/DeviceItem.qml
        qml/components/Header.qml
        qml/components/ViewToggle.qml
        qml/components/SearchField.qml
        qml/components/FolderCard.qml
        qml/components/RecentTable.qml
        qml/components/FileGridView.qml
        qml/components/FileListView.qml
        qml/components/FileColumnsView.qml
        qml/components/PreviewPanel.qml
        qml/components/EmptyState.qml
        qml/components/ContextMenu.qml
        qml/components/DlgBase.qml
        qml/components/ConfirmDialog.qml
        qml/components/PromptDialog.qml
        qml/components/PropertiesDialog.qml
        qml/components/SettingsDialog.qml
        qml/components/Toast.qml
        qml/components/ProgressPanel.qml
        qml/pages/HomePage.qml
        qml/pages/DirectoryPage.qml
)

target_include_directories(dylanos-explorer PRIVATE src src/models src/services)
target_link_libraries(dylanos-explorer PRIVATE
    explorer_services
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 Qt6::Concurrent
)

# --- Install -------------------------------------------------------------------
include(GNUInstallDirs)
install(TARGETS dylanos-explorer RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES assets/org.dylanos.explorer.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES assets/dylanos-explorer.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)

# --- Tests ---------------------------------------------------------------------
enable_testing()
if(Qt6Test_FOUND)
    qt_add_executable(tst_fileoperations tests/tst_fileoperations.cpp)
    target_link_libraries(tst_fileoperations PRIVATE explorer_services Qt6::Test)
    add_test(NAME fileoperations COMMAND tst_fileoperations)
else()
    message(STATUS "Qt6::Test not found: unit tests disabled (install qt6-base-dev)")
endif()
