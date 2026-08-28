#!/usr/bin/env bash

# Compile this package. Run it from an auton_starter shell: that alias
# supplies colcon, the mrover underlay, and MROVER_BUILD_PROFILE.
#
# See: https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -Eeuo pipefail

readonly RED_BOLD='\033[1;31m'
readonly BLUE_BOLD='\033[1;34m'
readonly GREY_BOLD='\033[1;30m'
readonly NC='\033[0m'

# determine the build profile
build_profile="${1:-${MROVER_BUILD_PROFILE:-RelWithDebInfo}}"

if [[ "$#" -gt 1 ]] || { [[ "$#" -eq 1 ]] && [[ "$1" != "Release" && "$1" != "RelWithDebInfo" && "$1" != "Debug" ]]; }; then
    echo "Usage: ./build.sh [Release|RelWithDebInfo|Debug]"
    exit 1
fi

if ! command -v colcon > /dev/null 2>&1; then
    echo -e "${RED_BOLD}colcon not found. Run auton_starter first, then build.${NC}"
    exit 1
fi

# Build in place: the repo root is the workspace root.
cd "$(dirname "${BASH_SOURCE[0]:-$0}")"

export CC=clang
export CXX=clang++

echo -e "${BLUE_BOLD}Building mrover_autonomy_starter (${build_profile}) ...${NC}"
colcon build \
    --cmake-args -G Ninja -Wno-dev -DCMAKE_BUILD_TYPE="${build_profile}" \
    --symlink-install \
    --build-base "build/${build_profile}" \
    --install-base "install/${build_profile}"

echo -e "${GREY_BOLD}Done. Run auton_starter to pick up the new overlay.${NC}"
