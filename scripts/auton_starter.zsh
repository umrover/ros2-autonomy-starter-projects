# MRover autonomy starter project
export AUTON_STARTER_PATH="${AUTON_STARTER_PATH:-$HOME/ros2-autonomy-starter-projects}"

source_auton_starter_overlay() {
    if ! typeset -f source_mrover_overlay > /dev/null; then
        print -P '%F{red}%Bsource_mrover_overlay is not defined. Check the mrover shell setup.%b%f'
        return 1
    fi

    source_mrover_overlay

    local profile="${MROVER_BUILD_PROFILE:-RelWithDebInfo}"
    local overlay="${AUTON_STARTER_PATH}/install/${profile}/setup.zsh"

    if [ -f "${overlay}" ]; then
        source "${overlay}" > /dev/null
    else
        print -P "%F{green}%BNo overlay for profile ${profile}. Run build_starter%b%f"
    fi
}

alias auton_starter="cd \$AUTON_STARTER_PATH && source_auton_starter_overlay"
alias build_starter="\$AUTON_STARTER_PATH/scripts/build.sh && auton_starter"
alias clean_starter="rm -rf \$AUTON_STARTER_PATH/build \$AUTON_STARTER_PATH/log \$AUTON_STARTER_PATH/install"
