#!/bin/bash
# ------------------------------------------------------------------------------
# 
# Name:    android.sh
# Author:  Gabriel Gonzalez
# 
# Brief: Build an android app.
# 
# ------------------------------------------------------------------------------

##
# Project name.
##
PROJECT="${0##*/}"

##
# Directories.
##
ANDROID_APP_DIR="${HOME}/projects/android/app"

##
# Emulator.
##
ANDROID_EMULATOR_PORT="5554"
ANDROID_EMULATOR_ARG="-s emulator-${ANDROID_EMULATOR_PORT}"

##
# Options.
##
ALL=
BUILD=
CLEAN=
DEVICE=
EMULATOR=
INSTALL=
KILL=
NAME=
RELEASE=
RUN=
UNINSTALL=

##
# Exit statuses.
##
EXIT_ANDROID_APP_INVALID_APP_NAME=10
EXIT_ANDROID_APP_INVALID_AVD=11
EXIT_ANDROID_EMULATOR_NOT_RUNNING=12
EXIT_ANDROID_EMULATOR_RUNNING=13
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
	# Parse options
	local short="habcd:eikn:ru"
	local long="help,all,build,clean,avd:,emulator,install,kill,name:,release,run,uninstall"
	local args=$(getopt -o "${short}" --long "${long}" \
						--name "${PROJECT}" -- "${@}")
	if [ $? -ne 0 ]
	then
		usage
		exit 1
	fi
	eval set -- "${args}"

	while true
	do
		case "${1}" in
			-h|--help)
				usage
				exit 0
				;;
			-a|--all)
				ALL=true
				;;
			-b|--build)
				BUILD=true
				;;
			-c|--clean)
				CLEAN=true
				;;
			-d|--avd)
				shift
				DEVICE="${1}"
				;;
			-e|--emulator)
				EMULATOR=true
				;;
			-i|--install)
				INSTALL=true
				;;
			-k|--kill)
				KILL=true
				;;
			-n|--name)
				shift
				NAME="${1}"
				;;
			--release)
				RELEASE=true
				;;
			-r|--run)
				RUN=true
				;;
			-u|--uninstall)
				UNINSTALL=true
				;;
			*)
				break
				;;
		esac
		shift
	done


	# Run options
	if [ -z "${DEVICE}" ]
	then
		DEVICE=$(android_get_avd)
	fi

	if [ -n "${HELP}" ]
	then
		usage
	elif [ -n "${KILL}" ]
	then
		android_kill
	elif [ -n "${EMULATOR}" ]
	then
		android_emulator "${DEVICE}"
	else
		if [ -z "${NAME}" ]
		then
			echo "${PROJECT}: Must specify the name of the app." 1>&2
			exit ${EXIT_ANDROID_APP_INVALID_APP_NAME}
		fi

		if ! android_is_app "${NAME}"
		then
			echo "${PROJECT}: Invalid app name '${NAME}'." 1>&2
			exit ${EXIT_ANDROID_APP_INVALID_APP_NAME}
		fi

		if [ -n "${ALL}" ]
		then
			android_all "${NAME}" "${DEVICE}"
		elif [ -n "${BUILD}" ]
		then
			android_build "${NAME}"
		elif [ -n "${CLEAN}" ]
		then
			android_clean "${NAME}"
		elif [ -n "${INSTALL}" ]
		then
			android_install "${NAME}"
		elif [ -n "${RELEASE}" ]
		then
			android_release "${NAME}"
		elif [ -n "${RUN}" ]
		then
			android_run "${NAME}"
		elif [ -n "${UNINSTALL}" ]
		then
			android_uninstall "${NAME}"
		else
			:
		fi
	fi
	exit $?

}

##
# Print program usage.
##
usage()
{
	echo "Usage: ${PROJECT} [options] [args]"
	echo 
	echo "Options:"
	echo "	  -h, --help"
	echo "		  Print program usage."
	echo 
	echo "	  -a, --all"
	echo "		  Execute all actions (build, install, emulator, run)."
	echo 
	echo "	  -b, --build"
	echo "		  Build the app."
	echo 
	echo "	  -c, --clean"
	echo "		  Clean the app build."
	echo 
	echo "	  -d, --avd=<device>"
	echo "		  Android Virtual Device to use."
	echo 
	echo "	  -e, --emulator"
	echo "		  Run the emulator. Will not run if there is already one"
	echo "		  running."
	echo 
	echo "	  -i, --install"
	echo "		  Install the app."
	echo 
	echo "	  -k, --kill"
	echo "		  Kill the emulator if it is running."
	echo 
	echo "	  -n, --name=<app>"
	echo "		  The name of the app (case-sensitive)."
	echo 
	echo "	  -r, --run"
	echo "		  Run the app, if the emulator is running."
	echo 
	echo "	  -u, --uninstall"
	echo "		  Uninstall the app."
	echo 
	echo "Arguments:"
	echo "	  <app>"
	echo "		  The name of the app, e.g. 'NameOfApp'."
	echo 
	echo "	  <device>"
	echo "		  The Android Virtual Device to use, e.g. 'Nexus_5_API_21'."
}

##
# Run all actions.
##
android_all()
{
	local name="${1}"
	local avd="${2}"
	android_build "${name}" || return $?
	android_emulator "${avd}"
	case $? in
		0)
			if ! android_is_emulator_running
			then
				sleep 15
			fi
			;;
		${EXIT_ANDROID_EMULATOR_RUNNING})
			;;
		*)
			return $?
			;;
	esac
	android_install "${name}" || return $?
	android_run "${name}" || return $?
	return 0
}

##
# Build the application.
##
android_build()
{
	local name="${1}"
	echo ":: Building app '${name}'."
	builtin cd "${ANDROID_APP_DIR}/${name}"
	android_gradle_wrapper_verify "${name}" || return $?
	#./gradlew assembleDebug lintDebug testDebugUnitTest --stacktrace
	./gradlew assemble lint test --stacktrace
	if [ $? -ne 0 ]
	then
		echo "${PROJECT}: Build failed." 1>&2
		return ${EXIT_ANDROID_APP_BUILD_FAILED}
	fi
	return 0
}

##
# Clean the application build.
##
android_clean()
{
	local name="${1}"
	echo ":: Cleaning app '${name}'."
	builtin cd "${ANDROID_APP_DIR}/${name}"
	android_gradle_wrapper_verify "${name}" || return $?
	./gradlew clean
	if [ $? -ne 0 ]
	then
		echo "${PROJECT}: Cleaning failed." 1>&2
		return ${EXIT_ANDROID_APP_CLEAN_FAILED}
	fi
	rm -rf .gradle
	rm -rf "${HOME}/.gradle/caches/"
	return 0
}

##
# Run the Android emulator (if it isn't already running).
##
android_emulator()
{
	local avd="${1}"
	echo ":: Running emulator '${avd}'."
	android_emulator_verify "${avd}" || return $?
	emulator -no-boot-anim -no-snapshot-load -timezone America/New_York \
		-netspeed full -netdelay none -netfast -avd "${avd}" &
	return $?
}

##
# Install the application.
##
android_install()
{
	local name="${1}"
	local fullname=$(android_get_com_name "${name}")
	local src="${ANDROID_APP_DIR}/${name}/app/build/outputs/apk/debug/app-debug.apk"

	if [ "${name}" == "Alarmio" ]
	then
		src="${ANDROID_APP_DIR}/${name}/app/build/outputs/apk/gplay/debug/app-gplay-debug.apk"
	fi

	local dst="/data/local/tmp/${fullname}"
	echo ":: Installing app '${name}' (${fullname})."
	android_install_verify "${src}" || return $?
	adb ${ANDROID_EMULATOR_ARG} push  "${src}" "${dst}"
	adb ${ANDROID_EMULATOR_ARG} shell pm install -r "${dst}"
	return $?
}

##
# Kill any running instances of the Android emulator.
##
android_kill()
{
	echo ":: Killing any instances of the Android emulator."
	for p in $(ps -U ${USER} -u ${USER} u \
		| grep --color=never -w \
			"emulator\|emulator-${ANDROID_EMULATOR_PORT}\|/usr/lib/jvm/java" \
		| grep -v grep \
		| awk '{ print $2 }')
	do
		if [ -d "/proc/${p}" ]
		then
			echo ":: Killing '${p}'."
			kill -9 ${p}
			if [ $? -ne 0 ]
			then
				echo "${PROJECT}: Error killing process." 1>&2
			fi
		fi
	done
}

##
# Create an android release.
##
android_release()
{
	local name="${1}"
	local apkdir="${ANDROID_APP_DIR}/${name}/app/build/outputs/apk/release"
	local gradleFile="${ANDROID_APP_DIR}/${name}/app/build.gradle"
	local versionName=$(grep -m 1 "versionName" "${gradleFile}" \
		| cut -f 2 -d '"' | cut -f 1 -d '"')
	local versionDate=$(date +"%m%d%y")
	local outputDir="${HOME}/app/${versionName}"
	local outputFileName="nfc_alarm_clock_${versionDate}"
	local outputFileNormal="${outputDir}/${outputFileName}.apk"
	local outputFileAligned="${outputDir}/${outputFileName}_aligned.apk"
	local outputFileSigned="${outputDir}/${outputFileName}_signed.apk"

	mkdir -v "${outputDir}"
	builtin cd "${outputDir}"
	cp "${apkdir}"/app-release-unsigned.apk "${outputFileNormal}"
	builtin cd /opt/android-sdk/build-tools/27.0.3
	./zipalign -v -p 4 "${outputFileNormal}" "${outputFileAligned}"
	./apksigner sign --ks ~/app/my-release-key.jks \
		--out "${outputFileSigned}" "${outputFileAligned}"

	#builtin cd "${HOME}/app/"
	#cp "${apkdir}"/app-release-unsigned.apk .
	#mv -i app-release-unsigned.apk nfc_alarm_clock_"${version}".apk
	#builtin cd /opt/android-sdk/build-tools/27.0.3
	#./zipalign -v -p 4 ~/app/nfc_alarm_clock_"${version}".apk ~/app/nfc_alarm_clock_"${version}"_aligned.apk
	#./apksigner sign --ks ~/app/my-release-key.jks --out ~/app/nfc_alarm_clock_"${version}"_signed.apk ~/app/nfc_alarm_clock_"${version}"_aligned.apk
}

##
# Run the application, if the emulator is running.
##
android_run()
{
	local name="${1}"
	local fullname=$(android_get_com_name "${name}")
	echo ":: Running app '${name}'."
	android_run_verify || return $?
	adb ${ANDROID_EMULATOR_ARG} shell monkey -p "${fullname}" \
		-c android.intent.category.LAUNCHER 1
	return $?
}

##
# Uninstall the application.
##
android_uninstall()
{
	local name="${1}"
	local fullname=$(android_get_com_name "${name}")
	echo ":: Uninstalling app '${name}'..."
	android_uninstall_verify || return $?
	adb ${ANDROID_EMULATOR_ARG} shell pm uninstall "${fullname}"
	return $?
}

##
# Return the list of valid AVDs that can be used in the emulator.
##
android_list_avd()
{
	emulator -list-avds
	return $?
}

##
# Verify that the emulator is ready to be run.
##
android_emulator_verify()
{
	local avd="${1}"
	if android_is_emulator_running
	then
		echo ":: Emulator already running."
		return ${EXIT_ANDROID_EMULATOR_RUNNING}
	fi
	if ! android_is_avd "${avd}"
	then
		echo "${PROJECT}: Invalid Android Virtual Device '${avd}'." 1>&2
		return ${EXIT_ANDROID_APP_INVALID_AVD}
	fi
	return 0
}

##
# Verify that the application is ready to be installed.
##
android_install_verify()
{
	local src="${1}"
	if [ ! -f "${src}" ]
	then
		echo "${PROJECT}: The APK '${src}' does not exist." 1>&2
		echo "${PROJECT}: Has the app been built?" 1>&2
		return ${EXIT_ANDROID_APP_APK_DOES_NOT_EXIST}
	fi
	if ! android_is_emulator_running
	then
		echo "${PROJECT}: Emulator is not running. Exiting." 1>&2
		return ${EXIT_ANDROID_EMULATOR_NOT_RUNNING}
	fi
	return 0
}

##
# Verify that the application is ready to be run.
##
android_run_verify()
{
	if ! android_is_emulator_running
	then
		echo "${PROJECT}: Emulator is not running. Exiting." 1>&2
		return ${EXIT_ANDROID_EMULATOR_NOT_RUNNING}
	fi
}

##
# Verify that the application is ready to be uninstalled.
##
android_uninstall_verify()
{
	if ! android_is_emulator_running
	then
		echo "${PROJECT}: Emulator is not running. Exiting." 1>&2
		return ${EXIT_ANDROID_EMULATOR_NOT_RUNNING}
	fi
}

##
# Verify that the gradle wrapper exists.
##
android_gradle_wrapper_verify()
{
	local name="${1}"
	if [ ! -e "${ANDROID_APP_DIR}/${name}/gradlew" ]
	then
		echo "${PROJECT}: Gradle wrapper does not exist. Exiting." 1>&2
		return ${EXIT_ANDROID_APP_GRADLE_WRAPPER_DOES_NOT_EXIST}
	fi
	return 0
}

##
# Return the default AVD.
##
android_get_avd()
{
	#android_list_avd | sort | uniq | head -1
	android_list_avd | uniq | tail -1
}

##
# Return the app com name.
##
android_get_com_name()
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
# Check if the input app name is a valid app.
##
android_is_app()
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
android_is_avd()
{
	android_list_avd | grep -q "${1}"
	return $?
}

##
# Check if the emulator running.
##
android_is_emulator_running()
{
	if adb devices | grep "${ANDROID_EMULATOR_PORT}" &> /dev/null
	then
		if ps -U ${USER} -u ${USER} u \
			| grep emulator \
			| grep -v defunct &> /dev/null
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
