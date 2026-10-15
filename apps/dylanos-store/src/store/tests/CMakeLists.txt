# Unit tests over the mock backend (the real PackageKit backend is exercised
# live in the ISO). StoreController.cpp includes libdiscover headers, so the
# tests link Discover::Common but never touch the system at runtime.

set(CORE_TEST_SOURCES
    ../models/AppItem.h ../models/AppItem.cpp
    ../models/AppModel.h ../models/AppModel.cpp
    ../models/AppFilterModel.h ../models/AppFilterModel.cpp
    ../models/StoreController.h ../models/StoreController.cpp
    ../services/PackageBackend.h
    ../services/MockPackageBackend.h ../services/MockPackageBackend.cpp)

remove_definitions(-DQT_NO_CAST_FROM_ASCII -DQT_NO_CAST_FROM_BYTEARRAY -DQT_NO_CAST_TO_ASCII)

function(add_store_test name source)
    qt_add_executable(${name} ${source} ${CORE_TEST_SOURCES})
    target_include_directories(${name} PRIVATE .. ../models ../services)
    target_compile_definitions(${name} PRIVATE DEMO_JSON="${CMAKE_CURRENT_SOURCE_DIR}/../data/demo-apps.json" DYLANOS_STORE_VERSION="${PROJECT_VERSION}")
    target_link_libraries(${name} PRIVATE Qt6::Test Qt6::Svg Discover::Common)
    add_test(NAME ${name} COMMAND ${name})
endfunction()

add_store_test(tst_backend tst_backend.cpp)
add_store_test(tst_controller tst_controller.cpp)
add_store_test(tst_filter tst_filter.cpp)

set_tests_properties(tst_backend tst_controller tst_filter PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
