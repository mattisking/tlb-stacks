qt_add_qml_module(truelaunchbarplugin
    URI com.mattphilmon.truelaunchbar
    VERSION 1.0
    PLUGIN_TARGET truelaunchbarplugin
    NO_GENERATE_PLUGIN_SOURCE

    OUTPUT_DIRECTORY
        "${CMAKE_BINARY_DIR}/qml/com/mattphilmon/truelaunchbar"

    SOURCES
        launcher.cpp
        launcher.h
        plugin.cpp
)

target_link_libraries(truelaunchbarplugin
    PRIVATE
        Qt6::Core
        Qt6::Qml
        KF6::KIOGui
        KF6::Service
)