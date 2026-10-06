cmake_minimum_required(VERSION 3.24)

project(TLBStacks VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick Widgets Concurrent)
find_package(KF6 REQUIRED COMPONENTS KIO Service)
find_package(PlasmaActivities REQUIRED)
find_package(PlasmaActivitiesStats REQUIRED)
include(KDEInstallDirs6)

qt_policy(SET QTP0001 NEW)
qt_standard_project_setup()

add_subdirectory(src)

# Distribution packages install the widget alongside its native QML module.
# The developer installer uses kpackagetool6 for the user-specific widget path.
option(TLB_INSTALL_WIDGET "Install the Plasma widget package" ON)
file(READ "${CMAKE_CURRENT_SOURCE_DIR}/package/metadata.json" tlb_metadata)
string(JSON tlb_widget_version GET "${tlb_metadata}" KPlugin Version)
if(NOT tlb_widget_version STREQUAL PROJECT_VERSION)
    message(FATAL_ERROR "Widget metadata version must match project version ${PROJECT_VERSION}")
endif()
if(TLB_INSTALL_WIDGET)
    install(DIRECTORY package/
        DESTINATION "${KDE_INSTALL_DATADIR}/plasma/plasmoids/com.mattphilmon.tlbstacks"
        PATTERN "__pycache__" EXCLUDE
        PATTERN "*.pyc" EXCLUDE)
endif()
install(FILES LICENSE DESTINATION "${KDE_INSTALL_DATADIR}/licenses/tlb-stacks")

# Experimental group shell: intentionally excluded from normal release packages.
option(TLB_INSTALL_GROUP "Install the experimental TLBStacks Group widget" OFF)
if(TLB_INSTALL_GROUP)
    file(READ "${CMAKE_CURRENT_SOURCE_DIR}/package-group/metadata.json" tlb_group_metadata)
    string(JSON tlb_group_version GET "${tlb_group_metadata}" KPlugin Version)
    if(NOT tlb_group_version STREQUAL PROJECT_VERSION)
        message(FATAL_ERROR "Group metadata version must match project version ${PROJECT_VERSION}")
    endif()
    install(DIRECTORY package-group/
        DESTINATION "${KDE_INSTALL_DATADIR}/plasma/plasmoids/com.mattphilmon.tlbstacks.group")
endif()
