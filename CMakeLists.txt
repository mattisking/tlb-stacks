cmake_minimum_required(VERSION 3.24)

project(TrueLaunchBar VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick Widgets Concurrent)
find_package(KF6 REQUIRED COMPONENTS KIO Service)

qt_policy(SET QTP0001 NEW)
qt_standard_project_setup()

add_subdirectory(src)