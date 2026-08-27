from pathlib import Path

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, GroupAction
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node



def generate_launch_description() -> LaunchDescription:
    mrover_share = Path(get_package_share_directory("mrover"))

    start_simulator = LaunchConfiguration("start_simulator")
    headless = LaunchConfiguration("headless")
    rviz = LaunchConfiguration("rviz")

    simulator_group = GroupAction(
        condition=IfCondition(start_simulator),
        actions=[
            Node(
                package="mrover",
                executable="superstructure.py",
                name="superstructure",
                parameters=[
                    str(mrover_share / "config" / "superstructure.yaml"),
                    {"input_topics": ["sim_cmd_vel"]},
                ],
                output="log",
            ),
            Node(
                package="mrover",
                executable="simulator",
                name="simulator",
                cwd=str(mrover_share),
                parameters=[
                    str(mrover_share / "config" / "simulator.yaml"),
                    str(mrover_share / "config" / "reference_coords.yaml"),
                    {"headless": headless},]
                ,
                output="screen",
            ),
            Node(
                package="mrover",
                executable="differential_drive_controller",
                name="differential_drive_controller",
                parameters=[
                    str(mrover_share / "config" / "esw.yaml"),
                ],
                output="screen",
            ),
            Node(
                package="rviz2",
                executable="rviz2",
                name="rviz2",
                arguments=[
                    "-d",
                    str(mrover_share / "config" / "simulator.rviz"),
                ],
                condition=IfCondition(rviz),
                output="screen",
            ),
        ],
    )

    return LaunchDescription(
        [
            DeclareLaunchArgument("start_simulator", default_value="true"),
            DeclareLaunchArgument("headless", default_value="false"),
            DeclareLaunchArgument("rviz", default_value="false"),
            simulator_group,
            Node(
                package="mrover_autonomy_starter",
                executable="starter_localization",
                name="localization",
                output="screen",
            ),
            Node(
                package="mrover_autonomy_starter",
                executable="starter_perception",
                name="perception",
                output="screen",
            ),
            Node(
                package="mrover_autonomy_starter",
                executable="starter_navigation",
                name="navigation",
                output="screen",
            ),
        ]
    )