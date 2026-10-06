qt_add_qml_module(tlbstacksplugin
    URI com.mattphilmon.tlbstacks
    VERSION 1.0
    PLUGIN_TARGET tlbstacksplugin
    NO_GENERATE_PLUGIN_SOURCE
    NO_PLUGIN_OPTIONAL
    CLASS_NAME TLBStacksPlugin

    OUTPUT_DIRECTORY
        "${CMAKE_BINARY_DIR}/qml/com/mattphilmon/tlbstacks"

    SOURCES
        activitysource.cpp
        activitysource.h
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

target_link_libraries(tlbstacksplugin
    PRIVATE
        Plasma::Activities
        Plasma::ActivitiesStats
        Qt6::Core
        Qt6::Qml
        Qt6::Quick
        Qt6::Widgets
        Qt6::Concurrent
        KF6::KIOGui
        KF6::Service
)

# qt_add_qml_module creates build artifacts, but does not install them.
set(TLB_QML_INSTALL_DIR "${KDE_INSTALL_QMLDIR}" CACHE STRING
    "QML import root relative to CMAKE_INSTALL_PREFIX (or an absolute path)")
set(tlb_module_destination "${TLB_QML_INSTALL_DIR}/com/mattphilmon/tlbstacks")
install(TARGETS tlbstacksplugin
    LIBRARY DESTINATION "${tlb_module_destination}")
install(FILES
    "${CMAKE_BINARY_DIR}/qml/com/mattphilmon/tlbstacks/qmldir"
    "${CMAKE_BINARY_DIR}/qml/com/mattphilmon/tlbstacks/tlbstacksplugin.qmltypes"
    DESTINATION "${tlb_module_destination}")

# Keep the verified build and installed binary identical (no install-time RPATH edit).
set_target_properties(tlbstacksplugin PROPERTIES BUILD_WITH_INSTALL_RPATH TRUE)
