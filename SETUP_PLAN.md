# Setup Script Plan

Plan for a setup script for `umrover/ros2-autonomy-starter-projects`.
Status: proposal. No code is written yet.

## 1. Goal and boundary

The script sets up **this repo**. It treats the mrover install as a prerequisite that it
checks. It never installs ROS on its own initiative.

The script does four things:

1. Checks that a working mrover install is present. If a check fails, the script prints
   the exact wiki command that fixes it, and **offers to run that command**. It runs
   nothing without a "yes".
2. Prompts for a location, then clones this repo there. The default is the home
   directory, outside the mrover workspace.
3. Builds this repo in place, as an overlay on the mrover install.
4. Adds a shell alias that calls `source_mrover_overlay`, then adds this overlay.

The [Install ROS wiki page](https://github.com/umrover/mrover-ros2/wiki/2.-Install-ROS)
stays the source of truth for the ROS install. This script only forwards the commands
from that page. It never reimplements them.

## 2. The workflow

### 2.1 What the member does

The normal path, with ROS already installed per the wiki:

```bash
curl -fsSL https://raw.githubusercontent.com/umrover/ros2-autonomy-starter-projects/integration/original_sim_baseline/setup.sh | bash
# Install path [~/ros2-autonomy-starter-projects]: <enter>
source ~/.zshrc
```

Every session after that:

```bash
auton_starter
ros2 launch mrover_autonomy_starter starter_project.launch.py
```

If ROS is absent, the preflight offers the fix:

```
mrover is not installed at ~/ros2_ws/src/mrover.

The wiki fix is:
  wget -O bootstrap.sh https://raw.githubusercontent.com/umrover/mrover-ros2/main/bootstrap.sh
  chmod +x ./bootstrap.sh && ./bootstrap.sh

Run it now? [y/N]:
```

A "no" exits, and the machine is unchanged. A "yes" runs the command, then stops, because
`bootstrap.sh` needs a reboot. The member reboots and runs `setup.sh` again.

### 2.2 What the script does, in order

```
setup.sh
 |
 |-- 0. preflight
 |      mrover repo present ......... else: offer the bootstrap command
 |      source_mrover_overlay defined  else: offer ./ansible.sh dev.yml
 |      mrover install built ........ else: offer mrover && ./build.sh
 |      colcon present in the venv .. else: offer the bootstrap command
 |      each failure prints the command first, and asks before it runs
 |
 |-- 1. place this repo             [skip if it is already on disk]
 |      prompt for a path, default ~/ros2-autonomy-starter-projects
 |      git clone https://github.com/umrover/ros2-autonomy-starter-projects
 |      NOT inside the mrover workspace
 |
 |-- 2. build this repo in place
 |      activate the mrover venv
 |      source <ws>/install/<profile>/setup.bash        (the underlay, read-only)
 |      colcon build, from the repo root
 |      -> <repo>/install/<profile>                     (the overlay)
 |
 |-- 3. install the alias
 |      write <repo>/scripts/auton_starter.zsh
 |      write ~/.oh-my-zsh/custom/auton-starter.zsh, which sources it
 |
 `-- 4. print the next commands
```

Outside an accepted offer, the script writes to exactly three places: the chosen repo
directory, the repo's build output, and one file under `~/.oh-my-zsh/custom/`. It never
writes inside the mrover workspace, and it never edits `~/.zshenv` or `~/.zshrc`.

### 2.3 What the alias does at run time

```
auton_starter
 |-- cd $AUTON_STARTER_PATH
 |-- source_mrover_overlay        (defined by mrover's own shell setup)
 |     |-- activate <ws>/src/mrover/venv
 |     |-- pick the newest of <ws>/install/{RelWithDebInfo,Release,Debug}
 |     |-- export MROVER_BUILD_PROFILE
 |     |-- strip stale ros2_ws entries from the ROS path variables
 |     `-- source <ws>/install/$MROVER_BUILD_PROFILE/setup.zsh
 `-- source $AUTON_STARTER_PATH/install/$MROVER_BUILD_PROFILE/setup.zsh
```

The order gives a correct overlay. mrover is sourced first, so its packages sit below.
The starter install is sourced second, so it sits on top.

`source_mrover_overlay` is the one thing this repo borrows from mrover. It is a function
in the member's shell, not a file in the mrover repo, so the borrow survives upstream
changes. See 3.2.

## 3. Research findings

Each fact below is verified on this machine. The facts control the design.

### 3.1 The mrover install, as a prerequisite

`bootstrap.sh` from `mrover-ros2` installs Ansible and git, clones the repo to
`<ws>/src/mrover`, and runs `ansible.sh dev.yml`. The workspace path is a prompt, and the
default is `~/ros2_ws`. The Ansible run changes the login shell to zsh and writes the
shell config, so a reboot follows. The member then runs `mrover` and `./build.sh`.

Three consequences:

- The workspace path is not fixed. Read `MROVER_ROS2_WS_PATH` if the shell exports it,
  and fall back to `$HOME/ros2_ws`. Accept a `--ros2-ws` flag as well.
- Each stage of that flow can be half-done. Check the stages one at a time, so each offer
  names the one command that fixes the one broken stage.
- `bootstrap.sh` reads its own workspace prompt from stdin. An accepted offer must give
  it a real terminal, not the `curl` pipe. See 3.9.

### 3.2 The mrover shell config moves between versions

This is the most important finding, and it changed during this research.

- On mrover `main` today, the `dev` Ansible role **copies** `~/.zshenv` and `~/.zshrc`
  from `ansible/roles/dev/files/home/`. `~/.zshenv` defines `source_mrover_overlay`.
  `~/.zshrc` holds `alias mrover=`.
- On another branch, the same role instead appends a `# BEGIN MROVER` block to
  `~/.zshenv`, which sources `mrover/scripts/mrover.zshenv`.

This machine showed both during the research. `~/.zshenv` held the copied definitions on
lines 1 to 53, plus a stale `# BEGIN MROVER` block that pointed at a file the current
mrover checkout does not have. Every zsh start printed:

```
/home/ejhon1116/.zshenv:source:55: no such file or directory: .../scripts/mrover.zshenv
```

That block is gone now, so the error is fixed on this machine. The finding still stands:
`~/.zshenv` is upstream property, it changes shape between mrover versions, and a member
who installed at the wrong time carries the wreckage.

Two rules follow:

1. **Never hardcode a path into the mrover repo.** Test for the function instead:
   `zsh -ic 'type source_mrover_overlay'`.
2. **Never write the alias into `~/.zshenv` or `~/.zshrc`.** The `dev` role rsyncs both
   files with no exclude list, so the next `./ansible.sh dev.yml` deletes anything added
   there. This applies to an offer the member accepts, so the rule holds even then.

The durable location is `~/.oh-my-zsh/custom/`. oh-my-zsh sources every `*.zsh` file in
that directory. mrover's rsync writes only `custom/themes/mrover.zsh-theme` there, and it
does not use `--delete`, so a file of our own survives.

### 3.3 What `source_mrover_overlay` does

1. Activates the venv at `<ws>/src/mrover/venv`.
2. Picks the newest of `<ws>/install/{RelWithDebInfo,Release,Debug}/setup.zsh`, and
   exports the choice as `MROVER_BUILD_PROFILE`.
3. Strips stale `ros2_ws` entries from `LD_LIBRARY_PATH`, `AMENT_PREFIX_PATH`,
   `PYTHONPATH`, `COLCON_PREFIX_PATH`, and `CMAKE_PREFIX_PATH`.
4. Sources the chosen file.

The function uses `${(P)1}`, which is zsh-only. The alias is therefore zsh-only. The login
shell is already zsh, because the `dev` role runs `chsh`.

Step 3 filters on the literal string `ros2_ws`. The default install path
`~/ros2-autonomy-starter-projects` does not contain that string, so the overlay entries
survive the cleanup. The alias re-sources the overlay anyway, which keeps the order
correct. A member who answers the path prompt with something under `~/ros2_ws` would lose
the entries, so the prompt must reject such a path. See 6, Step 1.

`MROVER_BUILD_PROFILE` is exported. This repo reuses it, so the two builds always agree on
a profile.

### 3.4 This package needs the mrover install at run time, not at build time

- `src/state_machine/state_publisher_server.py` imports `mrover.msg.StateMachineStructure`,
  `StateMachineTransition`, and `StateMachineStateUpdate`.
- `launch/starter_project.launch.py` calls `get_package_share_directory("mrover")` and
  starts the `mrover` nodes `simulator`, `superstructure.py`, and
  `differential_drive_controller`.
- `package.xml` declares `<exec_depend>mrover</exec_depend>`.

At build time the package is self-contained. It vendors its own `util` and `state_machine`
modules, and it generates its own `StarterProjectTag` message.

This is what makes the separation clean. The two repos meet at one install directory and
one shell function. They do not share a build.

### 3.5 colcon is only inside the mrover venv

`which colcon` resolves to `<ws>/src/mrover/venv/bin/colcon`. There is no system colcon.
Every build step must activate that venv first.

The venv already holds the Python run-time dependencies: `numpy` 1.26.4 and
`transforms3d` 0.4.2.

This is a read-only use of the mrover workspace. The build never writes there.

### 3.6 An in-place build works

Verified with the repo root as the workspace root:

```
$ colcon list
mrover_autonomy_starter	.	(ros.ament_cmake)
```

colcon writes `COLCON_IGNORE` into the directories it creates, so a later crawl skips its
own output. `.gitignore` already ignores `/build/`, `/install/`, and `/log/` at the repo
root. The repo was already shaped for this layout.

### 3.7 How mrover builds

`<ws>/src/mrover/build.sh` runs `pushd ../..`, so colcon runs from the workspace root. It
sets `CC=clang` and `CXX=clang++`, and uses:

```
--cmake-args -G Ninja -W no-dev -DCMAKE_BUILD_TYPE=$profile
--symlink-install
--build-base   build/$profile
--install-base install/$profile
```

The default profile is `RelWithDebInfo`. This machine has only that profile built. This
repo copies the flag shape, but not the workspace root. See section 7.

### 3.8 Other facts

- `umrover/ros2-autonomy-starter-projects` is a public repo. The GitHub API returns 200.
  HTTPS clone works, so this script needs no SSH key. Only the mrover clone does.
- The default branch is `integration/original_sim_baseline`, not `main`.
- Ubuntu 22.04.5 LTS. ROS 2 Humble at `/opt/ros/humble`.
- `build.sh` and `README.md` in this repo are empty files.
- mrover still builds an old copy of the starter project at `starter_project/autonomy/`.
  That copy belongs to the `mrover` package, so its executable names differ. There is no
  collision with `mrover_autonomy_starter`.

### 3.9 A piped script has no stdin left for a prompt

The `curl … | bash` form gives bash the pipe as stdin. A plain `read` then consumes the
script text, or returns nothing at all. The same fault would break any command the script
runs on the member's behalf.

The fix, used for every prompt and every accepted offer:

- Read from `/dev/tty`, not stdin: `read -r reply < /dev/tty`.
- If `/dev/tty` cannot be opened, the run is non-interactive. Take the default for a
  prompt, and refuse an offer. Never assume "yes" for a command that changes the machine.
- Give an accepted command the terminal as well, so its own prompts work:
  `bash ./bootstrap.sh < /dev/tty`.

## 4. Key decision: a standalone overlay, not a package in the mrover workspace

**Recommendation: install this repo at `~/ros2-autonomy-starter-projects` by default, and
build it in place as its own one-package workspace.**

The repo root is the workspace root, and the package root, and the git root. There is no
`src/` wrapper to remove when the structure is flattened.

Reasons:

- It keeps the two setups separate. This repo reads the mrover install. It never adds to
  it.
- `mrover/clean.sh` runs `rm -rf build install log` in the mrover workspace. It cannot
  delete this build.
- The package needs mrover only at run time, per 3.4. A plain overlay is enough.
- `colcon build` here rebuilds one small package. It never re-enters the mrover build.
- The layout matches what `.gitignore` already expects, per 3.6.

Cost, compared with a package inside `<ws>/src`: the alias sources two files, not one.
That is one extra line, shown in 2.3.

## 5. Files to add

| File | Purpose |
| --- | --- |
| `setup.sh` | The entry point. Bash. |
| `scripts/auton_starter.zsh` | The alias and the overlay source line. |
| `build.sh` | In-place colcon build. Currently empty. |
| `README.md` | The prerequisite, the one command, and the alias name. Currently empty. |

## 6. `setup.sh` specification

Shell: `#!/usr/bin/env bash`, with `set -Eeuo pipefail`. It writes zsh config, but it does
not need to run under zsh. Every prompt reads from `/dev/tty`, per 3.9.

Two modes:

- **Bootstrap mode.** The repo is not on disk. The member pipes the script from
  `raw.githubusercontent.com`. The script prompts for a path, then clones.
- **In-repo mode.** The member runs `./setup.sh` from a checkout. The script uses that
  checkout where it is, and skips the path prompt. It never moves or copies the clone.

### Step 0 — Preflight, with an offer on each failure

Resolve the workspace path first: `--ros2-ws`, then `MROVER_ROS2_WS_PATH`, then
`$HOME/ros2_ws`.

Then check four things, in this order. Stop at the first failure, print the wiki command,
and ask before running it.

| Check | Test | Offered command | After it runs |
| --- | --- | --- | --- |
| mrover repo | `<ws>/src/mrover/package.xml` exists | `wget` + `chmod +x` + `./bootstrap.sh` | Stop. A reboot is needed. |
| shell setup | `zsh -ic 'type source_mrover_overlay'` succeeds | `<ws>/src/mrover/ansible.sh dev.yml` | Stop. A reboot is needed. |
| mrover build | some `<ws>/install/<profile>/setup.bash` exists | `cd <ws>/src/mrover && ./build.sh`, with the venv active | Re-check, then continue. |
| colcon | `<ws>/src/mrover/venv/bin/colcon` is executable | The bootstrap command, as above | Stop. A reboot is needed. |

Rules for every offer:

- Print the full command before the prompt. The member sees what will run.
- The default answer is **no**. A bare Enter exits, and the machine is unchanged.
- Pass `/dev/tty` to the command, so its own prompts work. `bootstrap.sh` has one.
- The two commands that end in a reboot make the script exit 0 with a clear next step:
  "Reboot, then run setup.sh again."
- `--no-offer` turns every offer into a plain error. Use it in CI, and in any
  non-interactive run.

A fifth check belongs after the underlay is sourced, in Step 2: `ros2 pkg prefix mrover`
must resolve. That proves the simulator package is installed, not only that a workspace
was built. It has no offer, because a partial mrover build is not a one-command fix.

Add a `--check` flag that runs Step 0 with `--no-offer` and exits. It gives members a fast
way to test a suspect install, with no side effects.

Ubuntu version and disk space are not checked. They belong to the wiki.

### Step 1 — Place this repo

- In in-repo mode, use the current checkout, at any path. Skip the rest of this step.
- Otherwise prompt:
  ```
  Install path [~/ros2-autonomy-starter-projects]:
  ```
  A bare Enter takes the default. `--path PATH` skips the prompt.
- Expand `~` and relative paths to an absolute path.
- Reject a path inside the mrover workspace, and say why: `source_mrover_overlay` strips
  every path that contains `ros2_ws` from the ROS path variables. See 3.3.
- Reject a path inside an existing colcon workspace, for the same class of reason.
- Clone over HTTPS, on branch `integration/original_sim_baseline`.
- If the path exists and holds this repo, keep it and continue.
- If the path exists and holds anything else, stop with a clear message.

### Step 2 — Build this repo

Run this repo's `build.sh`. See section 7.

### Step 3 — Install the alias

- Write `scripts/auton_starter.zsh` in the repo. See section 8.
- Write `~/.oh-my-zsh/custom/auton-starter.zsh`, containing two lines:
  ```zsh
  export AUTON_STARTER_PATH="/abs/path/from/step/1"
  source "$AUTON_STARTER_PATH/scripts/auton_starter.zsh"
  ```
  Overwrite the file on a re-run. The script owns it, and it carries the chosen path, so
  the path prompt survives into every later shell.
- If `~/.oh-my-zsh` does not exist, print the two lines and ask the member to add them to
  their own shell config. Do not edit `~/.zshrc` or `~/.zshenv`, per 3.2.

### Step 4 — Report

Print:

```
source ~/.zshrc
auton_starter
ros2 launch mrover_autonomy_starter starter_project.launch.py
```

## 7. `build.sh` specification

The flag shape follows `mrover/build.sh`. The workspace root is this repo.

- Accept an optional profile argument: `Release`, `RelWithDebInfo`, or `Debug`. Default to
  `$MROVER_BUILD_PROFILE`, then to `RelWithDebInfo`.
- Run colcon from the repo root. Never `pushd` out of the repo.
- Use `--build-base build/$profile` and `--install-base install/$profile`, so
  `scripts/auton_starter.zsh` can find the result.
- Add `--symlink-install`, so Python edits need no rebuild.
- Set `CC=clang` and `CXX=clang++`, as mrover does.
- Before the build:
  - Activate the mrover venv if `colcon` is not on `PATH`.
  - Source `<ws>/install/$profile/setup.bash` if `AMENT_PREFIX_PATH` does not already hold
    it. This lets `./build.sh` run from a plain terminal, not only after the alias.
  - Stop if `ros2 pkg prefix mrover` fails.

## 8. `scripts/auton_starter.zsh` specification

```zsh
# MRover autonomy starter project
export AUTON_STARTER_PATH="${AUTON_STARTER_PATH:-$HOME/ros2-autonomy-starter-projects}"

source_auton_starter_overlay() {
    if ! typeset -f source_mrover_overlay > /dev/null; then
        echo "source_mrover_overlay is not defined. Check the mrover shell setup."
        return 1
    fi

    source_mrover_overlay

    local profile="${MROVER_BUILD_PROFILE:-RelWithDebInfo}"
    local overlay="${AUTON_STARTER_PATH}/install/${profile}/setup.zsh"

    if [ -f "${overlay}" ]; then
        source "${overlay}" > /dev/null
    else
        echo "No overlay for profile ${profile}. Run ${AUTON_STARTER_PATH}/build.sh"
    fi
}

alias auton_starter="cd \$AUTON_STARTER_PATH && source_auton_starter_overlay"
alias build_auton_starter="\$AUTON_STARTER_PATH/build.sh && auton_starter"
```

Notes:

- The `:-` default is a fallback only. Step 3 exports the real path first, in
  `~/.oh-my-zsh/custom/auton-starter.zsh`.
- Use `export`, not `readonly`. mrover's `readonly MROVER_ROS2_WS_PATH` prints
  `read-only variable` on every nested zsh start. Do not repeat that fault.
- The guard turns a silent `command not found` into a message that names the cause.
- The profile follows `MROVER_BUILD_PROFILE`, so the overlay always matches the underlay
  that `source_mrover_overlay` chose.

Alias names: `auton_starter` and `build_auton_starter`. They match `mrover` and
`build_mrover` in shape.

## 9. Idempotency and failure handling

- A declined offer changes nothing, so a failed preflight leaves the machine as it was.
- Every later step tests for its own result first, then skips. A second run is safe.
- The alias file is rewritten, not appended, so it never duplicates. A second run with a
  different path moves the alias to the new path.
- `trap ... ERR` prints the failed step and a suggested fix.
- Flags: `--check` for preflight only, `--no-offer` to never run a fix, `--path PATH` to
  skip the path prompt, `--ros2-ws PATH` for a non-default mrover workspace, and
  `--skip-build` to install only the alias.
- A run with no terminal, per 3.9, behaves as `--no-offer` plus the default path.

## 10. Verification

The script can check, after Step 3:

- `ros2 pkg list` contains `mrover_autonomy_starter`.
- `ros2 pkg executables mrover_autonomy_starter` lists `starter_localization`,
  `starter_perception`, and `starter_navigation`.

Full verification needs a display, so keep it manual:

```
ros2 launch mrover_autonomy_starter starter_project.launch.py
```

## 11. Out of scope

- Reimplementing the ROS install. The script forwards the wiki's own commands, and only
  after a "yes". It never writes its own version of them.
- A stale `# BEGIN MROVER` block in `~/.zshenv`, described in 3.2. The preflight can
  report it as a warning, but the fix belongs in `mrover-ros2`.
- The `read-only variable: MROVER_ROS2_WS_PATH` error. Same repo, same reason.
- The simulator timeout recorded in commit `79cd7f6`.
- Bash support for the alias. `source_mrover_overlay` is zsh-only.
- macOS, WSL, and VM installs. The wiki does not support them.

## 12. Decisions

| Question | Decision |
| --- | --- |
| Alias name | `auton_starter`, and `build_auton_starter` |
| A failed preflight | Print the wiki command, then offer to run it. Default no. |
| The install path | Prompt, and default to `~/ros2-autonomy-starter-projects` |
| The workspace layout | Standalone. Built in place, outside the mrover workspace. |

No open questions remain. The next step is to write the four files in section 5.
