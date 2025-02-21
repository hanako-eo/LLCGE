#!/bin/bash

show_usage() {
	if [ -n "$1" ]; then
		unknown="\n\nUnknown: $1"
	fi
	echo -e "This is the build script for the LLCGE project.$unknown

Usage: $0 [commands] [options]

options:
    --release [mode]        Build in the release mode(: fast, safe, small)
    --verbose               Print commands before executing them
    --exclude [lib]         Exclude of the compile the provided lib (cannot be used with --only)
    --only    [lib]         Compile only the provided list of libs (cannot be used with --exclude)
    --static                Compile all libs into static libs
    --check                 Check if the project is correctly formatted (format command only)

commands:
    build                   Build all packages
    test                    Launch all tests
    format                  Format all the sources
    - fmt
"

	exit 1
}

print_err() {
	echo -e "---------------------------------------------------------------------------
\e[31m$1\e[0m
---------------------------------------------------------------------------"
}

PACKAGES=**/build.zig

# === VARIABLES ===
check=false
release=no
verbose=false
static=false
excludes=()
only=()

command=""

# Get all args and the executed command
until [ -z "$1" ]; do
	shift_size=1
	if [[ $1 != -* ]]; then
		if [ -n "$command" ]; then
			show_usage "commands '$command' with '$1'"
		fi

		command=$1
	else
		case $1 in
		--check) check=true ;;
		--static) static=true ;;
		--verbose) verbose=true ;;
		--release)
			release=$2
			case $release in
			fast|safe|small);;
			*) show_usage "--release $release";
			esac
			shift_size=2
		;;
		--exclude)
			excludes+=($2)
			shift_size=2
		;;
		--only)
			only+=($2)
			shift_size=2
		;;
		*) show_usage $1 ;;
		esac
	fi
	shift $shift_size
done

if [ -n "$excludes" ] && [ -n "$only" ]; then
	print_err "You cannot give an exclude list and an include list of libs to compile at the same time.

Please try again by removing --only or --exclude."
	exit 1
fi

case $command in
build) zig_command="build";;
test) zig_command="build test";;
format|fmt)
	ZFLAG=()
	$check && ZFLAG+=("--check")

	zig fmt ${ZFLAG[@]} .
	exit $?
;;
help) show_usage "" ;;
*) show_usage $command ;;
esac

end_message="Finish"
for build_file in $PACKAGES; do
	folder=${build_file:0:-10}
	if [[ ${exclude[@]} =~ $folder ]]; then
		continue
	fi

	if [ -z $only ] || [[ ${only[@]} =~ $folder ]]; then
		ZFLAG=("--prefix ../zig-out")
		$verbose && ZFLAG+=("--verbose")
		if [ $release != "no" ]; then
			$static && ZFLAG+=("--release=$release")
		fi
		if [ $folder != "utils" ]; then
			$static && ZFLAG+=("-Dstatic")
		fi

		if $verbose; then
			echo "---------------------------------------------------------------------------
Build package '$folder'
$ zig $zig_command ${ZFLAG[@]}
---------------------------------------------------------------------------"
		fi

		cd $folder
		zig $zig_command ${ZFLAG[@]}
		success=$?
		cd ..

		if [ $success != 0 ]; then
			print_err "Failed to $zig_command package $folder"
			end_message="Failed"
		fi
	fi
done

echo $end_message
