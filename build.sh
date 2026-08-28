#!/usr/bin/env bash

# In-place colcon build for this repo. The repo root is the workspace root.
# See: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -Eeuo pipefail

readonly RED_BOLD='\033[1;31m'
readonly BLUE_BOLD='\033[1;34m'
readonly GREY_BOLD='\033[1;30m'
readonly NC='\033[0m'

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
readonly REPO_ROOT
readonly MROVER_ROS2_WS_PATH="${MROVER_ROS2_WS_PATH:-$HOME/ros2_ws}"

# determine the build profile
build_profile="${1:-${MROVER_BUILD_PROFILE:-RelWithDebInfo}}"

if [[ "$#" -gt 1 ]] || { [[ "$#" -eq 1 ]] && [[ "$1" != "Release" && "$1" != "RelWithDebInfo" && "$1" != "Debug" ]]; }; then
    echo "Usage: ./build.sh [Release|RelWithDebInfo|Debug]"
    exit 1
fi

echo -e "${GREY_BOLD}Using build profile: ${build_profile}${NC}"

# Activate the mrover venv if colcon is not already on PATH.
if ! command -v colcon > /dev/null 2>&1; then
    readonly VENV_ACTIVATE="${MROVER_ROS2_WS_PATH}/src/mrover/venv/bin/activate"
    if [ ! -f "${VENV_ACTIVATE}" ]; then
        echo -e "${RED_BOLD}colcon not found, and no mrover venv at ${VENV_ACTIVATE}${NC}"
        echo -e "${RED_BOLD}Run this repo's setup.sh, or activate the mrover venv yourself.${NC}"
        exit 1
    fi
    echo -e "${GREY_BOLD}Activating mrover venv ...${NC}"
    # The venv and ROS setup files read unbound variables, so -u comes off here.
    set +u
    # shellcheck source=/dev/null
    source "${VENV_ACTIVATE}" > /dev/null
    set -u
fi

# The mrover underlay profile is independent of the profile we build here.
# Pick the newest mrover install, the same way source_mrover_overlay does.
UNDERLAY=""
UNDERLAY_PROFILE=""
for profile in RelWithDebInfo Release Debug; do
    candidate="${MROVER_ROS2_WS_PATH}/install/${profile}/setup.bash"
    [ -f "${candidate}" ] || continue
    if [[ -z "${UNDERLAY}" || "${candidate}" -nt "${UNDERLAY}" ]]; then
        UNDERLAY="${candidate}"
        UNDERLAY_PROFILE="${profile}"
    fi
done
readonly UNDERLAY UNDERLAY_PROFILE

if [ -z "${UNDERLAY}" ]; then
    echo -e "${RED_BOLD}No mrover underlay under ${MROVER_ROS2_WS_PATH}/install${NC}"
    echo -e "${RED_BOLD}Build mrover first: cd ${MROVER_ROS2_WS_PATH}/src/mrover && ./build.sh${NC}"
    exit 1
fi

if [[ ":${AMENT_PREFIX_PATH:-}:" != *":${MROVER_ROS2_WS_PATH}/install/${UNDERLAY_PROFILE}:"* ]]; then
    echo -e "${GREY_BOLD}Sourcing mrover underlay: ${UNDERLAY}${NC}"
    set +u
    # shellcheck source=/dev/null
    source "${UNDERLAY}" > /dev/null
    set -u
fi

if ! ros2 pkg prefix mrover > /dev/null 2>&1; then
    echo -e "${RED_BOLD}ros2 pkg prefix mrover failed. mrover is not fully installed.${NC}"
    exit 1
fi

# Build in place, from the repo root. Never leave the repo.
cd "${REPO_ROOT}"

export CC=clang
export CXX=clang++

echo -e "${BLUE_BOLD}Building mrover_autonomy_starter (${build_profile}) ...${NC}"
colcon build \
    --cmake-args -G Ninja -Wno-dev -DCMAKE_BUILD_TYPE="${build_profile}" \
    --symlink-install \
    --build-base "build/${build_profile}" \
    --install-base "install/${build_profile}"

echo -e "${GREY_BOLD}Done. Overlay at ${REPO_ROOT}/install/${build_profile}${NC}"
