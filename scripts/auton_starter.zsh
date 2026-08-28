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
