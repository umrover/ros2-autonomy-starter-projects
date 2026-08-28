# mrover_autonomy_starter

Standalone MRover autonomy starter project. It builds as its own overlay on top of an
existing mrover install; it never adds to the mrover workspace.

## Prerequisite

A working mrover install, per the
[Install ROS wiki page](https://github.com/umrover/mrover-ros2/wiki/2.-Install-ROS).

## Setup

```bash
curl -fsSL https://raw.githubusercontent.com/umrover/ros2-autonomy-starter-projects/integration/original_sim_baseline/setup.sh | bash
```

`setup.sh` checks the mrover install, clones this repo (default `~/ros2-autonomy-starter-projects`),
builds it in place, and installs a shell alias. If the mrover install is missing a piece,
it prints the exact wiki command and asks before running it — nothing runs without a "yes".

After it finishes:

```bash
source ~/.zshrc
```

## Everyday use

```bash
auton_starter
ros2 launch mrover_autonomy_starter starter_project.launch.py
```

`auton_starter` sources the mrover overlay, then this repo's overlay on top of it, and
`cd`s into the repo. `build_auton_starter` rebuilds this repo, then runs `auton_starter`.
