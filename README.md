# Auton Starter Project Setup

## Prerequisite

A working mrover install, per the
[Install ROS wiki page](https://github.com/umrover/mrover-ros2/wiki/2.-Install-ROS).

Then build the ROS 2 workspace via 
```bash
build_mrover
```

```bash
mrover
./build.sh
```

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/umrover/ros2-autonomy-starter-projects/main/scripts/setup.sh | bash
```

After it finishes:

```bash
source ~/.zshrc
```

## Use
In every new terminal run 
```bash
auton_starter
```

After making changes to your code, compile through
```bash
build_starter
```

Then to run the simulator with your code run
```bash
ros2 launch mrover_autonomy_starter starter_project.launch.py
```
