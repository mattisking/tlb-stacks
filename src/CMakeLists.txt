set_source_files_properties("../package/contents/ui/ApplicationArgumentsDialog.qml" PROPERTIES
    QT_RESOURCE_ALIAS "ApplicationArgumentsDialog.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/CustomLauncherDialog.qml" PROPERTIES
    QT_RESOURCE_ALIAS "CustomLauncherDialog.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/ListReorderHandle.qml" PROPERTIES
    QT_RESOURCE_ALIAS "ListReorderHandle.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/ListReorderController.qml" PROPERTIES
    QT_RESOURCE_ALIAS "ListReorderController.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/FolderMenu.qml" PROPERTIES
    QT_RESOURCE_ALIAS "FolderMenu.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/ApplicationCategories.js" PROPERTIES
    QT_RESOURCE_ALIAS "ApplicationCategories.js" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/StackMembers.js" PROPERTIES
    QT_RESOURCE_ALIAS "StackMembers.js" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/CategoryChipBar.qml" PROPERTIES
    QT_RESOURCE_ALIAS "CategoryChipBar.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/AppPickerDialog.qml" PROPERTIES
    QT_RESOURCE_ALIAS "AppPickerDialog.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/StackSettingsEditor.qml" PROPERTIES
    QT_RESOURCE_ALIAS "StackSettingsEditor.qml" QT_QML_SKIP_CACHEGEN TRUE)
# One source of application-menu behavior, available to both widget packages.
set_source_files_properties("../package/contents/ui/ApplicationMenu.qml" PROPERTIES
    QT_RESOURCE_ALIAS "ApplicationMenu.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/ApplicationIcon.qml" PROPERTIES
    QT_RESOURCE_ALIAS "ApplicationIcon.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/StackToolTip.qml" PROPERTIES
    QT_RESOURCE_ALIAS "StackToolTip.qml" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/MenuNavigation.js" PROPERTIES
    QT_RESOURCE_ALIAS "MenuNavigation.js" QT_QML_SKIP_CACHEGEN TRUE)
set_source_files_properties("../package/contents/ui/IconOverrides.js" PROPERTIES
    QT_RESOURCE_ALIAS "IconOverrides.js" QT_QML_SKIP_CACHEGEN TRUE)
qt_add_qml_module(tlbstacksplugin
    URI com.mattphilmon.tlbstacks
    VERSION 1.0
    PLUGIN_TARGET tlbstacksplugin
    NO_GENERATE_PLUGIN_SOURCE
    NO_PLUGIN_OPTIONAL
    CLASS_NAME TLBStacksPlugin

    OUTPUT_DIRECTORY
        "${CMAKE_BINARY_DIR}/qml/com/mattphilmon/tlbstacks"

    QML_FILES
        ../package/contents/ui/ApplicationArgumentsDialog.qml
        ../package/contents/ui/CustomLauncherDialog.qml
        ../package/contents/ui/ListReorderHandle.qml
        ../package/contents/ui/ListReorderController.qml
        ../package/contents/ui/FolderMenu.qml
        ../package/contents/ui/ApplicationCategories.js
        ../package/contents/ui/StackMembers.js
        ../package/contents/ui/CategoryChipBar.qml
        ../package/contents/ui/AppPickerDialog.qml
        ../package/contents/ui/StackSettingsEditor.qml
        ../package/contents/ui/ApplicationMenu.qml
        ../package/contents/ui/ApplicationIcon.qml
        ../package/contents/ui/StackToolTip.qml
        ../package/contents/ui/MenuNavigation.js
        ../package/contents/ui/IconOverrides.js

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
