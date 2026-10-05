qt_add_qml_module(truelaunchbarplugin
    URI com.mattphilmon.truelaunchbar
    VERSION 1.0
    PLUGIN_TARGET truelaunchbarplugin
    NO_GENERATE_PLUGIN_SOURCE
    NO_PLUGIN_OPTIONAL
    CLASS_NAME TrueLaunchBarPlugin

    OUTPUT_DIRECTORY
        "${CMAKE_BINARY_DIR}/qml/com/mattphilmon/truelaunchbar"

    SOURCES
        folderreader.cpp
        folderreader.h
        foldersource.cpp
        foldersource.h
        stackentry.h
        folderpopup.cpp
        folderpopup.h
        launcher.cpp
        launcher.h
        plugin.cpp
)

target_link_libraries(truelaunchbarplugin
    PRIVATE
        Qt6::Core
        Qt6::Qml
        Qt6::Quick
        Qt6::Widgets
        Qt6::Concurrent
        KF6::KIOGui
        KF6::Service
)

# qt_add_qml_module creates build artifacts, but does not install them.
set(TLB_QML_INSTALL_DIR "lib64/qt6/qml" CACHE STRING
    "QML import root relative to CMAKE_INSTALL_PREFIX (or an absolute path)")
set(tlb_module_destination "${TLB_QML_INSTALL_DIR}/com/mattphilmon/truelaunchbar")
install(TARGETS truelaunchbarplugin
    LIBRARY DESTINATION "${tlb_module_destination}")
install(FILES
    "${CMAKE_BINARY_DIR}/qml/com/mattphilmon/truelaunchbar/qmldir"
    "${CMAKE_BINARY_DIR}/qml/com/mattphilmon/truelaunchbar/truelaunchbarplugin.qmltypes"
    DESTINATION "${tlb_module_destination}")

# Keep the verified build and installed binary identical (no install-time RPATH edit).
set_target_properties(truelaunchbarplugin PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE)
