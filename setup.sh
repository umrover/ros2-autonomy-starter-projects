#!/usr/bin/env bash

# Sets up this repo (mrover_autonomy_starter) as a standalone overlay on top of
# an existing mrover install. See SETUP_PLAN.md for the full design.
#
# This script never installs ROS on its own initiative. It only checks for a
# working mrover install, and offers to run the wiki's own fix commands.
#
# See: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -Eeuo pipefail

readonly RED_BOLD='\033[1;31m'
readonly BLUE_BOLD='\033[1;34m'
readonly GREY_BOLD='\033[1;30m'
readonly YELLOW_BOLD='\033[1;33m'
readonly NC='\033[0m'

readonly REPO_URL="https://github.com/umrover/ros2-autonomy-starter-projects"
readonly REPO_BRANCH="integration/original_sim_baseline"
readonly DEFAULT_INSTALL_PATH="$HOME/ros2-autonomy-starter-projects"
readonly WIKI_URL="https://github.com/umrover/mrover-ros2/wiki/2.-Install-ROS"

CHECK_ONLY=false
NO_OFFER=false
SKIP_BUILD=false
OPT_PATH=""
OPT_ROS2_WS=""

on_err() {
    local exit_code=$?
    local line=${1:-?}
    echo -e "${RED_BOLD}setup.sh failed at line ${line} (exit ${exit_code}).${NC}" >&2
    echo -e "${RED_BOLD}Fix the error above, then run setup.sh again.${NC}" >&2
}
trap 'on_err ${LINENO}' ERR

usage() {
    cat <<EOF
Usage: setup.sh [options]

  --check          Run preflight checks only (implies --no-offer), then exit.
  --no-offer       Never offer to run a fix command; fail instead.
  --path PATH      Install path for this repo. Default: ${DEFAULT_INSTALL_PATH}
  --ros2-ws PATH   Path to the mrover workspace. Default: \$MROVER_ROS2_WS_PATH or \$HOME/ros2_ws
  --skip-build     Install the alias only; skip the build step.
  -h, --help       Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_ONLY=true; NO_OFFER=true; shift ;;
        --no-offer) NO_OFFER=true; shift ;;
        --path) OPT_PATH="${2:?--path requires a value}"; shift 2 ;;
        --ros2-ws) OPT_ROS2_WS="${2:?--ros2-ws requires a value}"; shift 2 ;;
        --skip-build) SKIP_BUILD=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo -e "${RED_BOLD}Unknown option: $1${NC}" >&2; usage >&2; exit 1 ;;
    esac
done

# A run with no controlling terminal (e.g. curl | bash) behaves as --no-offer,
# and every prompt below takes its default. See SETUP_PLAN.md 3.9.
HAVE_TTY=true
# shellcheck disable=SC2217  # intentional: only checking that /dev/tty can be opened
if ! { true < /dev/tty; } 2> /dev/null; then
    HAVE_TTY=false
    NO_OFFER=true
fi

# Resolve the mrover workspace path: --ros2-ws, then MROVER_ROS2_WS_PATH, then ~/ros2_ws.
if [[ -n "${OPT_ROS2_WS}" ]]; then
    ROS2_WS="${OPT_ROS2_WS}"
else
    ROS2_WS="${MROVER_ROS2_WS_PATH:-$HOME/ros2_ws}"
fi
readonly ROS2_WS
readonly MROVER_PATH="${ROS2_WS}/src/mrover"

# Prompts read from /dev/tty, never from stdin, so the script keeps working
# when it is invoked as `curl ... | bash`. No tty => the default is taken.
# prompt_tty VAR "question text" "default"
prompt_tty() {
    local __var=$1 __question=$2 __default=$3 __reply=""
    if [[ "${HAVE_TTY}" == true ]]; then
        echo -e -n "${__question}" > /dev/tty
        read -r __reply < /dev/tty || __reply=""
    fi
    if [[ -z "${__reply}" ]]; then
        __reply="${__default}"
    fi
    printf -v "${__var}" '%s' "${__reply}"
}

# offer_command "description" "command to show and run"
# Prints the command, asks [y/N], and runs it (with /dev/tty attached) on yes.
# Returns 0 if the command ran, 1 if declined or refused.
offer_command() {
    local description=$1 command=$2
    echo
    echo -e "${YELLOW_BOLD}${description}${NC}"
    echo
    echo -e "${GREY_BOLD}${command}${NC}"
    echo

    if [[ "${NO_OFFER}" == true ]]; then
        echo -e "${RED_BOLD}--no-offer set (or no terminal available); not running the fix.${NC}"
        return 1
    fi

    local reply=""
    prompt_tty reply "Run it now? [y/N]: " "N"
    case "${reply}" in
        y|Y|yes|Yes|YES) ;;
        *) echo "Skipped."; return 1 ;;
    esac

    if ! bash -c "${command}" < /dev/tty; then
        echo -e "${RED_BOLD}That command failed:${NC}" >&2
        echo -e "${RED_BOLD}  ${command}${NC}" >&2
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Step 0: preflight
# ---------------------------------------------------------------------------

readonly BOOTSTRAP_CMD="wget -O bootstrap.sh https://raw.githubusercontent.com/umrover/mrover-ros2/main/bootstrap.sh && chmod +x ./bootstrap.sh && ./bootstrap.sh"

check_mrover_repo() {
    [[ -f "${MROVER_PATH}/package.xml" ]]
}

check_shell_setup() {
    zsh -ic 'type source_mrover_overlay' > /dev/null 2>&1
}

check_mrover_build() {
    local profile
    for profile in RelWithDebInfo Release Debug; do
        [[ -f "${ROS2_WS}/install/${profile}/setup.bash" ]] && return 0
    done
    return 1
}

check_colcon() {
    [[ -x "${MROVER_PATH}/venv/bin/colcon" ]]
}

preflight() {
    echo -e "${BLUE_BOLD}== Preflight: checking the mrover install at ${ROS2_WS} ==${NC}"

    if ! check_mrover_repo; then
        echo -e "${RED_BOLD}mrover is not installed at ${MROVER_PATH}.${NC}"
        if offer_command "The wiki fix is:" "${BOOTSTRAP_CMD}"; then
            echo -e "${YELLOW_BOLD}Reboot, then run setup.sh again.${NC}"
            exit 0
        fi
        echo -e "${RED_BOLD}See ${WIKI_URL}${NC}"
        exit 1
    fi
    echo -e "${GREY_BOLD}[ok] mrover repo present${NC}"

    if ! check_shell_setup; then
        echo -e "${RED_BOLD}source_mrover_overlay is not defined in your shell.${NC}"
        if offer_command "The wiki fix is:" "cd '${MROVER_PATH}' && ./ansible.sh dev.yml"; then
            echo -e "${YELLOW_BOLD}Reboot, then run setup.sh again.${NC}"
            exit 0
        fi
        echo -e "${RED_BOLD}See ${WIKI_URL}${NC}"
        exit 1
    fi
    echo -e "${GREY_BOLD}[ok] shell setup (source_mrover_overlay) present${NC}"

    if ! check_mrover_build; then
        echo -e "${RED_BOLD}mrover is not built at ${ROS2_WS}/install.${NC}"
        local build_cmd="cd '${MROVER_PATH}' && source venv/bin/activate && ./build.sh"
        if offer_command "The wiki fix is:" "${build_cmd}"; then
            if check_mrover_build; then
                echo -e "${GREY_BOLD}[ok] mrover build now present${NC}"
            else
                echo -e "${RED_BOLD}Still no build output after running the build. See ${WIKI_URL}${NC}"
                exit 1
            fi
        else
            echo -e "${RED_BOLD}See ${WIKI_URL}${NC}"
            exit 1
        fi
    else
        echo -e "${GREY_BOLD}[ok] mrover build present${NC}"
    fi

    if ! check_colcon; then
        echo -e "${RED_BOLD}colcon is not present in the mrover venv (${MROVER_PATH}/venv).${NC}"
        if offer_command "The wiki fix is:" "${BOOTSTRAP_CMD}"; then
            echo -e "${YELLOW_BOLD}Reboot, then run setup.sh again.${NC}"
            exit 0
        fi
        echo -e "${RED_BOLD}See ${WIKI_URL}${NC}"
        exit 1
    fi
    echo -e "${GREY_BOLD}[ok] colcon present in the mrover venv${NC}"

    echo -e "${BLUE_BOLD}Preflight passed.${NC}"
}

preflight

if [[ "${CHECK_ONLY}" == true ]]; then
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 1: place this repo
# ---------------------------------------------------------------------------

# ${BASH_SOURCE[0]} is unset when the script arrives on stdin, as it does under
# `curl ... | bash`. An empty SCRIPT_DIR then means bootstrap mode.
SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -n "${SCRIPT_SOURCE}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${SCRIPT_SOURCE}")" && pwd)"
else
    SCRIPT_DIR=""
fi
readonly SCRIPT_DIR
INSTALL_PATH=""

# In-repo mode: this script is already inside a checkout of the repo. Use it
# where it is, and skip the path prompt. An explicit --path always wins.
if [[ -z "${OPT_PATH}" && -n "${SCRIPT_DIR}" ]] \
    && [[ -f "${SCRIPT_DIR}/package.xml" ]] \
    && grep -q "<name>mrover_autonomy_starter</name>" "${SCRIPT_DIR}/package.xml" 2> /dev/null; then
    INSTALL_PATH="${SCRIPT_DIR}"
    echo -e "${GREY_BOLD}In-repo mode: using existing checkout at ${INSTALL_PATH}${NC}"
else
    echo -e "${BLUE_BOLD}== Placing ros2-autonomy-starter-projects ==${NC}"

    if [[ -n "${OPT_PATH}" ]]; then
        INSTALL_PATH="${OPT_PATH}"
    else
        prompt_tty INSTALL_PATH "Install path [${DEFAULT_INSTALL_PATH}]: " "${DEFAULT_INSTALL_PATH}"
    fi

    # Expand ~ and relative paths to an absolute path.
    INSTALL_PATH="${INSTALL_PATH/#\~/$HOME}"
    if [[ "${INSTALL_PATH}" != /* ]]; then
        INSTALL_PATH="$(pwd)/${INSTALL_PATH}"
    fi

    if [[ "${INSTALL_PATH}" == *ros2_ws* ]]; then
        echo -e "${RED_BOLD}Refusing to install at ${INSTALL_PATH}.${NC}"
        echo -e "${RED_BOLD}source_mrover_overlay strips every path containing 'ros2_ws' from the${NC}"
        echo -e "${RED_BOLD}ROS path variables, so an overlay installed there would be dropped.${NC}"
        exit 1
    fi

    # Reject a path inside the mrover workspace itself, even under a custom
    # --ros2-ws that does not happen to contain the literal string "ros2_ws".
    case "${INSTALL_PATH}" in
        "${ROS2_WS}"/*|"${ROS2_WS}")
            echo -e "${RED_BOLD}Refusing to install inside the mrover workspace (${ROS2_WS}).${NC}"
            exit 1
            ;;
    esac

    # Reject a path inside any other existing colcon workspace: walk up from
    # the target's parent looking for a sibling install/setup.bash, the mark
    # of a workspace root.
    __ancestor="$(dirname "${INSTALL_PATH}")"
    while [[ "${__ancestor}" != "/" && -n "${__ancestor}" ]]; do
        if [[ -f "${__ancestor}/install/setup.bash" || -f "${__ancestor}/install/local_setup.bash" ]]; then
            echo -e "${RED_BOLD}Refusing to install inside an existing colcon workspace at ${__ancestor}.${NC}"
            exit 1
        fi
        __ancestor="$(dirname "${__ancestor}")"
    done
    unset __ancestor

    if [[ -e "${INSTALL_PATH}" ]]; then
        if [[ -f "${INSTALL_PATH}/package.xml" ]] && grep -q "<name>mrover_autonomy_starter</name>" "${INSTALL_PATH}/package.xml" 2> /dev/null; then
            echo -e "${GREY_BOLD}${INSTALL_PATH} already holds this repo. Reusing it.${NC}"
        else
            echo -e "${RED_BOLD}${INSTALL_PATH} exists and does not hold this repo. Aborting.${NC}"
            exit 1
        fi
    else
        echo -e "${GREY_BOLD}Cloning ${REPO_URL} (branch ${REPO_BRANCH}) to ${INSTALL_PATH} ...${NC}"
        git clone --branch "${REPO_BRANCH}" "${REPO_URL}" "${INSTALL_PATH}"
    fi
fi
readonly INSTALL_PATH

# ---------------------------------------------------------------------------
# Step 2: build this repo
# ---------------------------------------------------------------------------

if [[ "${SKIP_BUILD}" == true ]]; then
    echo -e "${GREY_BOLD}--skip-build set; not building.${NC}"
else
    echo -e "${BLUE_BOLD}== Building mrover_autonomy_starter ==${NC}"
    MROVER_ROS2_WS_PATH="${ROS2_WS}" "${INSTALL_PATH}/build.sh"
fi

# ---------------------------------------------------------------------------
# Step 3: install the alias
# ---------------------------------------------------------------------------

echo -e "${BLUE_BOLD}== Installing the auton_starter alias ==${NC}"

readonly CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
readonly CUSTOM_FILE="${CUSTOM_DIR}/auton-starter.zsh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    mkdir -p "${CUSTOM_DIR}"
    cat > "${CUSTOM_FILE}" <<EOF
export AUTON_STARTER_PATH="${INSTALL_PATH}"
source "\$AUTON_STARTER_PATH/scripts/auton_starter.zsh"
EOF
    echo -e "${GREY_BOLD}Wrote ${CUSTOM_FILE}${NC}"
else
    echo -e "${YELLOW_BOLD}~/.oh-my-zsh not found. Add these two lines to your own shell config:${NC}"
    echo
    echo -e "${GREY_BOLD}export AUTON_STARTER_PATH=\"${INSTALL_PATH}\"${NC}"
    echo -e "${GREY_BOLD}source \"\$AUTON_STARTER_PATH/scripts/auton_starter.zsh\"${NC}"
fi

# ---------------------------------------------------------------------------
# Step 4: report
# ---------------------------------------------------------------------------

echo
echo -e "${BLUE_BOLD}Setup complete.${NC}"
echo
echo -e "${GREY_BOLD}source ~/.zshrc${NC}"
echo -e "${GREY_BOLD}auton_starter${NC}"
echo -e "${GREY_BOLD}ros2 launch mrover_autonomy_starter starter_project.launch.py${NC}"
