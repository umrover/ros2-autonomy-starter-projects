# mrover_autonomy_starter

## Prerequisite

A working mrover install, per the
[Install ROS wiki page](https://github.com/umrover/mrover-ros2/wiki/2.-Install-ROS).

The ROS 2 workspace must also be built. This repo overlays that build, so it is not enough
to have cloned mrover:

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
auton_starter
build_starter
```

## Use

```bash
auton_starter
ros2 launch mrover_autonomy_starter starter_project.launch.py
```

After you change the code, run `build_starter`. It recompiles and re-sources the overlay in
one step. It needs the environment that `auton_starter` sets up, so run that alias first in
a new shell.
