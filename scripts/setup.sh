#!/usr/bin/env bash

# Sets this repo up as a standalone overlay on an existing mrover install:
# clones it, and installs the auton_starter aliases. It does not build, and it
# does not install ROS. See the README for the prerequisites.
#
# Usage: scripts/setup.sh [install-path]
#
# See: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -Eeuo pipefail

readonly RED_BOLD='\033[1;31m'
readonly BLUE_BOLD='\033[1;34m'
readonly GREEN_BOLD='\033[1;32m'
readonly WHITE_BOLD='\033[1;37m'
readonly WHITE='\033[0;37m'
readonly NC='\033[0m'

readonly REPO_URL="git@github.com:umrover/ros2-autonomy-starter-projects.git"
readonly REPO_BRANCH="main"
readonly DEFAULT_INSTALL_PATH="$HOME/ros2-autonomy-starter-projects"
readonly WIKI_URL="https://github.com/umrover/mrover-ros2/wiki/2.-Install-ROS"

on_err() {
    local exit_code=$?
    local line=${1:-?}
    echo -e "${RED_BOLD}scripts/setup.sh failed at line ${line} (exit ${exit_code}).${NC}" >&2
    echo -e "${RED_BOLD}Fix the error above, then run scripts/setup.sh again.${NC}" >&2
}
trap 'on_err ${LINENO}' ERR

OPT_PATH=""
if [[ "$#" -gt 1 ]]; then
    echo -e "${RED_BOLD}Usage: scripts/setup.sh [install-path]${NC}" >&2
    exit 1
fi
if [[ "$#" -eq 1 ]]; then
    OPT_PATH="$1"
fi

# The path prompt reads from /dev/tty, never from stdin, so it still works when
# the script is invoked as `curl ... | bash`. No tty means take the default.
HAVE_TTY=true
# shellcheck disable=SC2217  # intentional: only checking that /dev/tty can be opened
if ! { true < /dev/tty; } 2> /dev/null; then
    HAVE_TTY=false
fi

readonly ROS2_WS="${MROVER_ROS2_WS_PATH:-$HOME/mrover-ros2}"
readonly MROVER_PATH="${ROS2_WS}"

# ---------------------------------------------------------------------------
# Step 0: preflight
# ---------------------------------------------------------------------------

fail() {
    echo -e "${RED_BOLD}$1${NC}" >&2
    shift
    local line
    for line in "$@"; do
        echo -e "${WHITE}${line}${NC}" >&2
    done
    exit 1
}

echo -e "${BLUE_BOLD}== Preflight: checking the mrover install at ${ROS2_WS} ==${NC}"

if [[ ! -f "${MROVER_PATH}/package.xml" ]]; then
    fail "mrover is not installed at ${MROVER_PATH}." "" "Install it first: ${WIKI_URL}"
fi
echo -e "${GREEN_BOLD}[ok] mrover repo present${NC}"

if ! zsh -ic 'type source_mrover_overlay' > /dev/null 2>&1; then
    fail "source_mrover_overlay is not defined in your shell." "" \
        "Finish the mrover shell setup, then reboot: ${WIKI_URL}"
fi
echo -e "${GREEN_BOLD}[ok] shell setup (source_mrover_overlay) present${NC}"

mrover_built=false
for profile in RelWithDebInfo Release Debug; do
    if [[ -f "${ROS2_WS}/install/${profile}/setup.bash" ]]; then
        mrover_built=true
        break
    fi
done
if [[ "${mrover_built}" != true ]]; then
    fail "mrover is not built at ${ROS2_WS}/install." "" \
        "Build it first:" "  mrover" "  ./build.sh"
fi
echo -e "${GREEN_BOLD}[ok] mrover build present${NC}"

if [[ ! -x "${MROVER_PATH}/venv/bin/colcon" ]]; then
    fail "colcon is not present in the mrover venv (${MROVER_PATH}/venv)." "" \
        "Reinstall the mrover dependencies: ${WIKI_URL}"
fi
echo -e "${GREEN_BOLD}[ok] colcon present in the mrover venv${NC}"

echo -e "${BLUE_BOLD}Preflight passed.${NC}"

# ---------------------------------------------------------------------------
# Step 1: place this repo
# ---------------------------------------------------------------------------

echo -e "${BLUE_BOLD}== Placing ros2-autonomy-starter-projects ==${NC}"

INSTALL_PATH="${OPT_PATH}"
if [[ -z "${INSTALL_PATH}" && "${HAVE_TTY}" == true ]]; then
    echo -e -n "Install path [${DEFAULT_INSTALL_PATH}]: " > /dev/tty
    read -r INSTALL_PATH < /dev/tty || INSTALL_PATH=""
fi
if [[ -z "${INSTALL_PATH}" ]]; then
    INSTALL_PATH="${DEFAULT_INSTALL_PATH}"
fi

# Expand ~ and relative paths to an absolute path.
INSTALL_PATH="${INSTALL_PATH/#\~/$HOME}"
if [[ "${INSTALL_PATH}" != /* ]]; then
    INSTALL_PATH="$(pwd)/${INSTALL_PATH}"
fi
readonly INSTALL_PATH

if [[ -e "${INSTALL_PATH}" ]]; then
    if [[ -f "${INSTALL_PATH}/package.xml" ]] \
        && grep -q "<name>mrover_autonomy_starter</name>" "${INSTALL_PATH}/package.xml" 2> /dev/null; then
        echo -e "${GREEN_BOLD}${INSTALL_PATH} already holds this repo. Reusing it.${NC}"
    else
        fail "${INSTALL_PATH} exists and does not hold this repo. Aborting."
    fi
else
    git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_PATH}"
fi

# ---------------------------------------------------------------------------
# Step 2: install the aliases
# ---------------------------------------------------------------------------

echo -e "${BLUE_BOLD}== Installing the auton_starter aliases ==${NC}"

readonly CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
readonly CUSTOM_FILE="${CUSTOM_DIR}/auton-starter.zsh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    mkdir -p "${CUSTOM_DIR}"
    cat > "${CUSTOM_FILE}" <<EOF
export AUTON_STARTER_PATH="${INSTALL_PATH}"
source "\$AUTON_STARTER_PATH/scripts/auton_starter.zsh"
EOF
    echo -e "${WHITE_BOLD}Wrote ${CUSTOM_FILE}${NC}"
else
    echo -e "${WHITE_BOLD}~/.oh-my-zsh not found. Add these two lines to your shell config:${NC}"
    echo
    echo -e "${WHITE}export AUTON_STARTER_PATH=\"${INSTALL_PATH}\"${NC}"
    echo -e "${WHITE}source \"\$AUTON_STARTER_PATH/scripts/auton_starter.zsh\"${NC}"
fi

# ---------------------------------------------------------------------------
# Step 3: report
# ---------------------------------------------------------------------------

echo
echo -e "${GREEN_BOLD}Setup complete.${NC}"
echo
echo -e "${BLUE_BOLD}Next steps:${NC}"
echo -e "${WHITE}source ~/.zshrc${NC}"
echo -e "${WHITE}auton_starter${NC}"
echo -e "${WHITE}build_starter${NC}"
echo -e "${WHITE}ros2 launch mrover_autonomy_starter starter_project.launch.py${NC}"
