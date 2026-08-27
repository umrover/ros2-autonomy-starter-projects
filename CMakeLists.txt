cmake_minimum_required(VERSION 3.16)
project(mrover_autonomy_starter VERSION 1.0.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(ament_cmake REQUIRED)
find_package(rclcpp REQUIRED)
find_package(sensor_msgs REQUIRED)
find_package(geometry_msgs REQUIRED)
find_package(tf2 REQUIRED)
find_package(tf2_ros REQUIRED)
find_package(rosidl_default_generators REQUIRED)
find_package(OpenCV REQUIRED)

rosidl_generate_interfaces(${PROJECT_NAME}
    "msg/StarterProjectTag.msg"
)

rosidl_get_typesupport_target(
    starter_typesupport_target
    ${PROJECT_NAME}
    rosidl_typesupport_cpp
)

# Perception
add_executable(
    starter_perception
    src/perception/perception.cpp
)

target_include_directories(
    starter_perception
    PRIVATE
    src/perception
    ${OpenCV_INCLUDE_DIRS}
)

ament_target_dependencies(
    starter_perception
    rclcpp
    sensor_msgs
)

target_link_libraries(
    starter_perception
    ${OpenCV_LIBS}
    "${starter_typesupport_target}"
)

install(
    TARGETS starter_perception
    RUNTIME DESTINATION lib/${PROJECT_NAME}
)

# Localization: Python baseline for now but supports later C++ port
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/src/localization/localization.cpp")
    add_executable(
    starter_localization
    src/localization/localization.cpp
    )

    target_include_directories(
        starter_localization
        PRIVATE
        src/localization
        include
    )

    ament_target_dependencies(
        starter_localization
        rclcpp
        sensor_msgs
        geometry_msgs
        tf2
        tf2_ros
    )

    install(
        TARGETS starter_localization
        RUNTIME DESTINATION lib/${PROJECT_NAME}
    )
else()
    install(
        PROGRAMS src/localization/localization.py
        DESTINATION lib/${PROJECT_NAME}
        RENAME starter_localization
    )
endif()

# Navigation executable
install(
    PROGRAMS src/navigation/navigation_starter_project.py
    DESTINATION lib/${PROJECT_NAME}
    RENAME starter_navigation
)

# Navigation helper modules are installed beside the executable.
install(
    DIRECTORY src/navigation/
    DESTINATION lib/${PROJECT_NAME}
    FILES_MATCHING
    PATTERN "*.py"
    PATTERN "navigation_starter_project.py" EXCLUDE
)

install(
    DIRECTORY
        src/util
        src/state_machine
    DESTINATION lib/${PROJECT_NAME}
    FILES_MATCHING PATTERN "*.py"
)

install(
    DIRECTORY launch
    DESTINATION share/${PROJECT_NAME}
)

ament_export_dependencies(rosidl_default_runtime)
ament_package()