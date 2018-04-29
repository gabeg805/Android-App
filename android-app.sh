#!/bin/bash

##
# Source utilities.
##
. "commandline.sh"
. "io.sh"

# Globals
APPFULLNAME="com.${APPNAME,,}"

##
# Directories.
##
ANDROID_APP_DIR="${HOME}/projects/android/dev/${APPNAME}"

##
# Emulator.
##
ANDROID_APP_EMULATOR_PORT="5554"
ANDROID_APP_EMULATOR_ARG="-s emulator-${ANDROID_APP_EMULATOR_PORT}"

##
# Options.
##
VERBOSE=

##
# Exit statuses.
##
EXIT_ANDROID_APP_INVALID_APP_NAME=10
EXIT_ANDROID_APP_INVALID_AVD=11
EXIT_ANDROID_APP_EMULATOR_NOT_RUNNING=12
EXIT_ANDROID_APP_EMULATOR_RUNNING=13
EXIT_ANDROID_APP_GRADLE_WRAPPER_DOES_NOT_EXIST=14
EXIT_ANDROID_APP_BUILD_GRADLE_FILE_DOES_NOT_EXIST=15
EXIT_ANDROID_APP_APK_DOES_NOT_EXIST=16
EXIT_ANDROID_APP_BUILD_FAILED=17
EXIT_ANDROID_APP_CLEAN_FAILED=18

##
# Android build.
##
main()
{
    cli_options "-h|--help       |Print program usage." \
                "-v|--verbose    |Verbose output." \
                "-a|--all        |Execute all actions (build, install, emulator, run app)." \
                "-b|--build      |Build the application." \
                "-c|--clean      |Clean the application build." \
                "-d|--avd=device:|An Android Virtual Device to use." \
                "-e|--emulator   |Run the emulator, if there is not one already running." \
                "-i|--install    |Install the application." \
                "-k|--kill       |Kill any running instances of the emulator." \
                "-n|--name=app:  |Name of the app (case-sensitive)." \
                "-r|--run        |Run the application, if the emulator is running." \
                "-u|--uninstall  |Uninstall the application."
    cli_parse "${@}"

    local help=$(cli_get "help")
    local all=$(cli_get "all")
    local build=$(cli_get "build")
    local clean=$(cli_get "clean")
    local avd=$(cli_get "avd")
    local emulator=$(cli_get "emulator")
    local install=$(cli_get "install")
    local kill=$(cli_get "kill")
    local name=$(cli_get "name")
    local run=$(cli_get "run")
    local uninstall=$(cli_get "uninstall")

    if [ -n "${help}" ]
    then
        cli_usage
    elif [ -n "${kill}" ]
    then
        android_app_kill
    else
        if [ -z "${name}" ]
        then
            print_err "Must specify the name of the app."
            exit ${EXIT_ANDROID_APP_INVALID_APP_NAME}
        fi
        if ! android_app_is_app "${name}"
        then
            print_err "Invalid app name '${name}'."
            exit ${EXIT_ANDROID_APP_INVALID_APP_NAME}
        fi
        if [ -z "${avd}" ]
        then
            avd=$(android_app_get_avd)
        fi

        if [ -n "${all}" ]
        then
            android_app_run_all "${name}" "${avd}"
        elif [ -n "${build}" ]
        then
            android_app_build "${name}"
        elif [ -n "${clean}" ]
        then
            android_app_clean "${name}"
        elif [ -n "${emulator}" ]
        then
            android_app_emulator "${avd}" "${name}"
        elif [ -n "${install}" ]
        then
            android_app_install "${name}"
        elif [ -n "${run}" ]
        then
            android_app_run "${name}"
        elif [ -n "${uninstall}" ]
        then
            android_app_uninstall "${name}"
        else
            :
        fi
    fi
    exit $?

}

##
# Run all actions.
##
android_app_run_all()
{
    local name="${1}"
    local avd="${2}"
    android_app_build "${name}" || return $?
    android_app_emulator "${avd}" "${name}"
    case $? in
        0)
            if ! android_app_is_emulator_running
            then
                sleep 10
            fi
            ;;
        ${EXIT_ANDROID_APP_EMULATOR_RUNNING})
            ;;
        *)
            return $?
            ;;
    esac
    android_app_install "${name}" || return $?
    android_app_run "${name}" || return $?
    return 0
}

##
# Build the application.
##
android_app_build()
{
    local name="${1}"
    echo ":: Building app '${name}'."
    builtin cd "${ANDROID_APP_DIR}/${name}"
    android_app_gradle_wrapper_verify "${name}" || return $?
    ./gradlew assembleDebug lintDebug testDebugUnitTest --stacktrace
    if [ $? -ne 0 ]
    then
        print_err "Build failed."
        return ${EXIT_ANDROID_APP_BUILD_FAILED}
    fi
    return 0
}

##
# Clean the application build.
##
android_app_clean()
{
    local name="${1}"
    echo ":: Cleaning app '${name}'."
    builtin cd "${ANDROID_APP_DIR}/${name}"
    android_app_gradle_wrapper_verify "${name}" || return $?
    ./gradlew clean
    if [ $? -ne 0 ]
    then
        print_err "Cleaning failed."
        return ${EXIT_ANDROID_APP_CLEAN_FAILED}
    fi
    rm -rf .gradle
    rm -rf "${HOME}/.gradle/caches/"
    return 0
}

##
# Run the Android emulator (if it isn't already running).
##
android_app_emulator()
{
    local avd="${1}"
    local name="${2}"
    local log=$(android_app_get_log_cat_filter "${name}")
    echo ":: Running emulator '${avd}'."
    android_app_emulator_verify "${avd}" || return $?
    emulator -no-boot-anim -netfast -logcat "'${log}'" -avd "${avd}" &
    return $?
}

##
# Install the application.
##
android_app_install()
{
    local name="${1}"
    local fullname=$(android_app_get_com_name "${name}")
    local src="${ANDROID_APP_DIR}/${name}/app/build/outputs/apk/debug/app-debug.apk"
    local dst="/data/local/tmp/${fullname}"
    echo ":: Installing app '${name}'."
    android_app_install_verify "${src}" || return $?
    adb ${ANDROID_APP_EMULATOR_ARG} push  "${src}" "${dst}"
    adb ${ANDROID_APP_EMULATOR_ARG} shell pm install -r "${dst}"
    return $?
}

##
# Kill any running instances of the Android emulator.
##
android_app_kill()
{
    echo ":: Killing any instances of the Android emulator."
    for p in $(ps -U ${USER} -u ${USER} u \
                   | grep --color=never -w \
                          "emulator\|emulator-${ANDROID_APP_EMULATOR_PORT}" \
                   | awk '{ print $2 }')
    do
        if [ -d "/proc/${p}" ]
        then
            print_info "Killing '${p}'."
            kill -9 ${p}
            if [ $? -ne 0 ]
            then
                print_err "Error killing process."
            fi
        fi
    done
}

##
# Run the application, if the emulator is running.
##
android_app_run()
{
    local name="${1}"
    local fullname=$(android_app_get_com_name "${name}")
    echo ":: Running app '${name}'."
    android_app_run_verify || return $?
    adb ${ANDROID_APP_EMULATOR_ARG} shell monkey -p "${fullname}" \
        -c android.intent.category.LAUNCHER 1
    return $?
}

##
# Uninstall the application.
##
android_app_uninstall()
{
    local name="${1}"
    local fullname=$(android_app_get_com_name "${name}")
    echo ":: Uninstalling app '${name}'..."
    android_app_uninstall_verify || return $?
    adb ${ANDROID_APP_EMULATOR_ARG} shell pm uninstall "${fullname}"
    return $?
}

##
# Return the list of valid AVDs that can be used in the emulator.
##
android_app_list_avd()
{
    emulator -list-avds
    return $?
}

##
# Verify that the emulator is ready to be run.
##
android_app_emulator_verify()
{
    local avd="${1}"
    if android_app_is_emulator_running
    then
        echo ":: Emulator already running."
        return ${EXIT_ANDROID_APP_EMULATOR_RUNNING}
    fi
    if ! android_app_is_avd "${avd}"
    then
        print_err "Invalid Android Virtual Device '${avd}'."
        return ${EXIT_ANDROID_APP_INVALID_AVD}
    fi
    return 0
}

##
# Verify that the application is ready to be installed.
##
android_app_install_verify()
{
    local src="${1}"
    if [ ! -f "${src}" ]
    then
        print_err "The APK '${src}' does not exist. Has the app been built?"
        return ${EXIT_ANDROID_APP_APK_DOES_NOT_EXIST}
    fi
    if ! android_app_is_emulator_running
    then
        print_err "Emulator is not running. Exiting."
        return ${EXIT_ANDROID_APP_EMULATOR_NOT_RUNNING}
    fi
    return 0
}

##
# Verify that the application is ready to be run.
##
android_app_run_verify()
{
    if ! android_app_is_emulator_running
    then
        print_err "Emulator is not running. Exiting."
        return ${EXIT_ANDROID_APP_EMULATOR_NOT_RUNNING}
    fi
}

##
# Verify that the application is ready to be uninstalled.
##
android_app_uninstall_verify()
{
    if ! android_app_is_emulator_running
    then
        print_err "Emulator is not running. Exiting."
        return ${EXIT_ANDROID_APP_EMULATOR_NOT_RUNNING}
    fi
}

##
# Verify that the gradle wrapper exists.
##
android_app_gradle_wrapper_verify()
{
    local name="${1}"
    if [ ! -e "${ANDROID_APP_DIR}/${name}/gradlew" ]
    then
        print_err "Gradle wrapper does not exist. Exiting."
        return ${EXIT_ANDROID_APP_GRADLE_WRAPPER_DOES_NOT_EXIST}
    fi
    return 0
}

##
# Return the default AVD.
##
android_app_get_avd()
{
    android_app_list_avd | sort | uniq | head -1
}

##
# Return the app com name.
##
android_app_get_com_name()
{
    local name="${1}"
    local file="${ANDROID_APP_DIR}/${name}/app/build.gradle"
    if [ ! -f "${file}" ]
    then
        return ${EXIT_ANDROID_APP_BUILD_GRADLE_FILE_DOES_NOT_EXIST}
    fi
    grep "applicationId" "${file}" | perl -pe 's/.*"(.*)".*/\1/'
    return $?
}

##
# Return logcat filter string.
##
android_app_get_log_cat_filter()
{
    local name="${1}"
    local log="*:s AndroidRuntime:* System.out:*"
    if [ -n "${name}" ]
    then
        log+=" ${name}:*"
    fi
    echo "${log}"
}

##
# Check if the input app name is a valid app.
##
android_app_is_app()
{
    local name="${1}"
    if [ -d "${ANDROID_APP_DIR}/${name}" ]
    then
        return 0
    else
        return 1
    fi
}

##
# Check if the input AVD is valid.
##
android_app_is_avd()
{
    android_app_list_avd | grep -q "${1}"
    return $?
}

##
# Check if the emulator running.
##
android_app_is_emulator_running()
{
    if adb devices | grep "${ANDROID_APP_EMULATOR_PORT}" &> /dev/null
    then
        if ps -U ${USER} -u ${USER} u | grep emulator | grep -v defunct &> /dev/null
        then
            return 0
        fi
    fi
    return 1
}

##
# Run Android app builder.
##
main "${@}"
