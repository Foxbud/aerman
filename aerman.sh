#!/usr/bin/env bash
# Copyright 2021 Garrett Fairburn <garrett@fairburn.dev>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



# Constants.

_VERSION="1.0.4"

_SCRIPT="$(readlink -f "$(which "$0")")"
_SCRIPTNAME="$(basename "$_SCRIPT")"
_SCRIPTDIR="$(dirname "$_SCRIPT")"

_CLI_DEPS="jq rsync sha256sum tar wget"
_GUI_DEPS="zenity"

_DEFAULT_PATCH_REPO='https://api.github.com/repos/Foxbud/aerpatch'
_PATCH_REPO="${AER_PATCH_REPO:-$_DEFAULT_PATCH_REPO}"

_DEFAULT_MRE_REPO='https://api.github.com/repos/Foxbud/libaermre'
_MRE_REPO="${AER_MRE_REPO:-$_DEFAULT_MRE_REPO}"

_DEFAULT_GAMEDIR_RAW='$HOME/.local/share/Steam/steamapps/common/HyperLightDrifter'
_DEFAULT_GAMEDIR="$(eval echo "$_DEFAULT_GAMEDIR_RAW")"
_GAMEDIR="${AER_GAMEDIR:-$_DEFAULT_GAMEDIR}"

_DEFAULT_PAGER=less
_PAGER="${PAGER:-$_DEFAULT_PAGER}"

_DEFAULT_EDITOR=nano
_EDITOR="${EDITOR:-$_DEFAULT_EDITOR}"

_DEFAULT_LANG="en_US.UTF-8"
_LANG="${LANG:-$_DEFAULT_LANG}"

_AERDIR_REL="aer"
_AERDIR="$_GAMEDIR/$_AERDIR_REL"

_PATCHDIR_REL="$_AERDIR_REL/patch"
_PATCHDIR="$_GAMEDIR/$_PATCHDIR_REL"

_MREDIR_REL="$_AERDIR_REL/mre"
_MREDIR="$_GAMEDIR/$_MREDIR_REL"

_MODSDIR_REL="$_AERDIR_REL/mods"
_MODSDIR="$_GAMEDIR/$_MODSDIR_REL"

_PACKDIR_REL="$_AERDIR_REL/packs"
_PACKDIR="$_GAMEDIR/$_PACKDIR_REL"

_ASSETSDIR_REL="assets/mod"
_ASSETSDIR="$_GAMEDIR/$_ASSETSDIR_REL"

_TMPDIR_REL="$_AERDIR_REL/tmp"
_TMPDIR="$_GAMEDIR/$_TMPDIR_REL"

_ORIGEXEC="HyperLightDrifter"
_MODEXEC="${_ORIGEXEC}Patched"
_EXECDIFF="${_ORIGEXEC}Diff"



# Utility functions.

_now() {
	echo $(date -u +"%Y-%m-%dT%H:%M:%SZ")
}

_ensure_deps() {
	for _DEP in $1; do
		_DEPVAR=_${_DEP^^}
		declare -gx $_DEPVAR="$(which $_DEP 2>/dev/null)"
		if [ -z "${!_DEPVAR}" ]; then
			declare -gx $_DEPVAR="$(which "$_SCRIPTDIR/bin/$_DEP" 2>/dev/null)"
			if [ -z "${!_DEPVAR}" ]; then
				echo "This command requires \"$_DEP\" to function!" >&2
				exit 1
			fi
		fi
	done
}

_ensure_modsdir() {
	mkdir -p "$_MODSDIR"
}

_ensure_packdir() {
	mkdir -p "$_PACKDIR"
}

_prep_tmpdir() {
	rm -rf "$_TMPDIR"
	mkdir -p "$_TMPDIR"
}

_prep_assetsdir() {
	rm -rf "$_ASSETSDIR"
	mkdir -p "$_ASSETSDIR"
}

_modinfo() {
	_MODINFO="$1/ModInfo.json"
	if "$_JQ" -rcMe "$2" "$_MODINFO" 2>/dev/null; then
		return 0
	else
		return 1
	fi
}

_download_latest() {
	pushd "$2" >/dev/null
	wget "$(curl -s "$1/releases/latest" | grep 'browser_' | cut -d\" -f4)" >/dev/null 2>&1
	_ERR=$?
	popd >/dev/null

	return $_ERR
}



# Operations.

_framework_complete_install() {
	_framework_patch_install
	_framework_mre_install
}

_framework_complete_uninstall() {
	_framework_patch_uninstall
	_framework_mre_uninstall
}

_framework_complete_purge() {
	echo "Are you sure you wish to uninstall the AER modding framework"
	echo "along with all mods and modpacks?"
	read -n 1 -rp "[N/y] " _INPUT
	echo
	case "$_INPUT" in
		'y'|'Y')
			;;
		*)
			echo "Framework will not be purged."
			exit 0
			;;
	esac
	rm -rf "$_GAMEDIR/$_MODEXEC" "$_AERDIR" "$_ASSETSDIR"
	echo "Successfully purged framework."
}

_framework_patch_install() {
	# Check if already installed.
	if [ -d "$_PATCHDIR" ]; then
		echo "Patch is already installed!" >&2
		exit 1
	fi

	# Determine archive source.
	_PATCHARCHIVE=
	_prep_tmpdir
	# Get archive from repository.
	if [ -z "$1" ]; then
		_download_latest "$_PATCH_REPO" "$_TMPDIR"
		if [ ! $? -eq 0 ]; then
			echo "Could not download latest release of patch!" >&2
			exit 1
		fi
		_PATCHARCHIVE="$(find "$_TMPDIR" -maxdepth 1 -mindepth 1 -type f)"
	# Use existing archive.
	else
		_PATCHARCHIVE="$1"
	fi

	# Extract archive.
	"$_TAR" -C "$_TMPDIR" -xf "$_PATCHARCHIVE" 2>/dev/null
	if [ ! $? -eq 0 ]; then
		echo "\"$_PATCHARCHIVE\" is not a valid patch archive!" >&2
		exit 1
	fi
	_STAGEDIR="$(find "$_TMPDIR" -maxdepth 1 -mindepth 1 -type d)"

	# Verify version compatibility.
	pushd "$_GAMEDIR" >/dev/null
	"$_SHA256SUM" -c "$_STAGEDIR/HyperLightDrifter.checksum.txt" >/dev/null 2>&1
	if [ ! $? -eq 0 ]; then
		echo "Patch is not compatible with present version of executable!" >&2
		exit 1
	fi
	popd >/dev/null

	# Patch executable.
	_PATCHVER="$(cat "$_STAGEDIR/VERSION.txt")"
	mv "$_STAGEDIR" "$_PATCHDIR"
	cp "$_GAMEDIR/$_ORIGEXEC" "$_GAMEDIR/$_MODEXEC"
	"$_RSYNC" --read-batch="$_PATCHDIR/$_EXECDIFF" "$_GAMEDIR/$_MODEXEC" 2>/dev/null
	if [ ! $? -eq 0 ]; then
		echo "Could not patch executable!" >&2
		rm -r "$_PATCHDIR"
		rm "$_GAMEDIR/$_MODEXEC"
		exit 1
	fi
	echo "Successfully installed patch (version $_PATCHVER)."
}

_framework_patch_uninstall() {
	if [ ! -d "$_PATCHDIR" ]; then
		echo "Patch is not installed!" >&2
		exit 1
	fi
	_PATCHVER="$(cat "$_PATCHDIR/VERSION.txt")"
	rm -f "$_GAMEDIR/$_MODEXEC"
	rm -rf "$_PATCHDIR"
	echo "Successfully uninstalled patch (version $_PATCHVER)."
}

_framework_mre_install() {
	# Check if already installed.
	if [ -d "$_MREDIR" ]; then
		echo "MRE is already installed!" >&2
		exit 1
	fi

	# Determine archive source.
	_MREARCHIVE=
	_prep_tmpdir
	# Get archive from repository.
	if [ -z "$1" ]; then
		_download_latest "$_MRE_REPO" "$_TMPDIR"
		if [ ! $? -eq 0 ]; then
			echo "Could not download latest release of MRE!" >&2
			exit 1
		fi
		_MREARCHIVE="$(find "$_TMPDIR" -maxdepth 1 -mindepth 1 -type f)"
	# Use existing archive.
	else
		_MREARCHIVE="$1"
	fi

	# Extract archive.
	"$_TAR" -C "$_TMPDIR" -xf "$_MREARCHIVE" 2>/dev/null
	if [ ! $? -eq 0 ]; then
		echo "\"$_MREARCHIVE\" is not a valid MRE archive!" >&2
		exit 1
	fi
	_STAGEDIR="$(find "$_TMPDIR" -maxdepth 1 -mindepth 1 -type d)"

	# Install MRE.
	_MREVER="$(cat "$_STAGEDIR/VERSION.txt")"
	mv "$_STAGEDIR" "$_MREDIR"
	echo "Successfully installed MRE (version $_MREVER)."
}

_framework_mre_uninstall() {
	if [ ! -d "$_MREDIR" ]; then
		echo "MRE is not installed!" >&2
		exit 1
	fi
	_MREVER="$(cat "$_MREDIR/VERSION.txt")"
	rm -rf "$_MREDIR"
	echo "Successfully uninstalled MRE (version $_MREVER)."
}

_framework_status() {
	_PATCHVER="$(cat "$_PATCHDIR/VERSION.txt" 2>/dev/null)"
	_MREVER="$(cat "$_MREDIR/VERSION.txt" 2>/dev/null)"
	if [ -n "$_PATCHVER" ]; then
		echo "Patch installed (version $_PATCHVER)."
		if [ -n "$_MREVER" ]; then
			echo "MRE installed (version $_MREVER)."
			return 0
		else
			echo "MRE not installed."
			return 2
		fi
	else
		echo "Patch not installed."
		if [ -n "$_MREVER" ]; then
			echo "MRE installed (version $_MREVER)."
			return 3
		else
			echo "MRE not installed."
			return 1
		fi
	fi
}

_mod_list() {
	_ensure_modsdir
	for _MODDIR in $(find "$_MODSDIR" -maxdepth 1 -mindepth 1); do
		_MODNAME=$(_modinfo "$_MODDIR" '.name')
		echo "$_MODNAME"
	done
}

_mod_install() {
	for _MODARCHIVE in $@; do
		_prep_tmpdir
		"$_TAR" -C "$_TMPDIR" -xf "$_MODARCHIVE" 2>/dev/null
		if [ ! $? -eq 0 ]; then
			echo "\"$_MODARCHIVE\" is not a valid mod archive!" >&2
			continue
		fi
		_STAGEDIR="$(find "$_TMPDIR" -maxdepth 1 -mindepth 1)"
		_MODNAME=$(_modinfo "$_STAGEDIR" '.name')
		_MODVER=$(_modinfo "$_STAGEDIR" '.version')
		_MODDIR="$_MODSDIR/$_MODNAME"
		if [ -d "$_MODDIR" ]; then
			echo "Mod \"$_MODNAME\" already installed!" >&2
			continue
		fi
		_LICENSE="$_STAGEDIR/LICENSE.txt"
		if [ -e "$_LICENSE" ]; then
			while true; do
				echo "Mod \"$_MODNAME\" has a license."
				echo "You can [v]iew, [r]eject or [a]ccept it."
				read -n 1 -rp "[V/r/a] " _INPUT
				echo
				case "$_INPUT" in
					'r'|'R')
						echo "Mod \"$_MODNAME\" will not be installed."
						continue 2
						;;
					'a'|'A')
						break
						;;
					*)
						"$_PAGER" "$_LICENSE"
						;;
				esac
			done
		fi
		echo "Installing mod \"$_MODNAME\"..."
		_ensure_modsdir
		mv "$_STAGEDIR" "$_MODDIR"
		echo "Successfully installed mod \"$_MODNAME\" (version $_MODVER)."
	done
}

_mod_uninstall() {
	_ensure_modsdir
	for _MODNAME in $@; do
		_MODDIR="$_MODSDIR/$_MODNAME"
		if [ ! -d "$_MODDIR" ]; then
			echo "No such mod \"$_MODNAME\"!" >&2
			continue
		fi
		_MODVER=$(_modinfo "$_MODDIR" '.version')
		rm -rf "$_MODDIR"
		echo "Successfully uninstalled mod \"$_MODNAME\" (version $_MODVER)."
	done
}

_mod_status() {
	for _MODNAME in $@; do
		_MODDIR="$_MODSDIR/$_MODNAME"
		if [ ! -d "$_MODDIR" ]; then
			echo "No such mod \"$_MODNAME\"!" >&2
			continue
		fi
		echo "$_MODNAME"
		if _MODVER=$(_modinfo "$_MODDIR" '.version'); then
			echo "	version: $_MODVER"
		fi
		if _MODDESC=$(_modinfo "$_MODDIR" '.description'); then
			echo "	description: $_MODDESC"
		fi
		if _MODURL=$(_modinfo "$_MODDIR" '.homepage'); then
			echo "	homepage: $_MODURL"
		fi
		if _MODAUTHS=$(_modinfo "$_MODDIR" '.authors'); then
			echo "	authors: $_MODAUTHS"
		fi
	done
}

_pack_list() {
	_ensure_packdir
	for _PACKFILE in $(find "$_PACKDIR" -maxdepth 1 -mindepth 1 -regex '.*\.toml'); do
		_PACKNAME=$(basename "$_PACKFILE")
		_PACKNAME=${_PACKNAME%.toml}
		echo $_PACKNAME
	done
}

_pack_create() {
	_ensure_packdir
	_PACKNAME=$1
	shift
	_PACKFILE="$_PACKDIR/${_PACKNAME}.toml"
	if [ -e "$_PACKFILE" ]; then
		echo "Modpack \"$_PACKNAME\" already exists!" >&2
		exit 1
	fi
	echo "# ================================" >>"$_PACKFILE"
	echo "#  MODPACK:  $_PACKNAME" >>"$_PACKFILE"
	echo "#  CREATED:  $(_now)" >>"$_PACKFILE"
	echo "#  TOOL:     $_SCRIPTNAME ($_VERSION)" >>"$_PACKFILE"
	echo "# ================================" >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo "# ================================" >>"$_PACKFILE"
	echo "#  MRE" >>"$_PACKFILE"
	echo "# ================================" >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo "[mre]" >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo "# Mods in this modpack from highest priority to lowest." >>"$_PACKFILE"
	echo "mods = [" >>"$_PACKFILE"
	for _MODNAME in $@; do
		echo -e "\t\"$_MODNAME\"," >>"$_PACKFILE"
	done
	echo "]" >>"$_PACKFILE"
	echo "."
	for _MODNAME in $@; do
		_MODDIR="$_MODSDIR/$_MODNAME"
		if [ ! -d "$_MODDIR" ]; then
			echo "No such mod \"$_MODNAME\"!" >&2
			rm "$_PACKFILE"
			exit 1
		fi
		_MODCONF="$(_modinfo "$_MODDIR" '.configuration')"
		if [ ! $? -eq 0 ]; then
			echo "."
			continue
		fi
		_NUMCONF=$("$_JQ" -rcM '. | length' <<<"$_MODCONF")
		if [ $_NUMCONF -eq 0 ]; then
			echo "."
			continue
		fi
		echo >>"$_PACKFILE"
		echo >>"$_PACKFILE"
		echo >>"$_PACKFILE"
		echo "# ================================" >>"$_PACKFILE"
		echo "#  ${_MODNAME^^}" >>"$_PACKFILE"
		echo "# ================================" >>"$_PACKFILE"
		echo >>"$_PACKFILE"
		echo "[$_MODNAME]" >>"$_PACKFILE"
		for _CONFIDX in $(seq 0 $(($_NUMCONF - 1))); do
			_CONFELEM="$("$_JQ" -rcM ".[$_CONFIDX]" <<<"$_MODCONF")"
			echo >>"$_PACKFILE"
			if _CONFDESC="$("$_JQ" -rcMe '.description' <<<"$_CONFELEM")"; then
				echo "# $_CONFDESC" >>"$_PACKFILE"
			fi
			_CONFKEY="$("$_JQ" -rcM '.key' <<<"$_CONFELEM")"
			_NUMKEY=$("$_JQ" -rcM '. | length' <<<"$_CONFKEY")
			_BUILTKEY="$("$_JQ" -rcM ".[0]" <<<"$_CONFKEY")"
			for _KEYIDX in $(seq 1 $(($_NUMKEY - 1))); do
				_BUILTKEY="$_BUILTKEY.$("$_JQ" -rcM ".[$_KEYIDX]" <<<"$_CONFKEY")"
			done
			_CONFDEF="$("$_JQ" -cM '.default' <<<"$_CONFELEM")"
			if [ "$_CONFDEF" = "null" ]; then
				_CONFDEF=""
			fi
			case "$_BUILTKEY" in
				*\ *)
					echo "#\"$_BUILTKEY\" = $_CONFDEF">>"$_PACKFILE"
					;;
				*)
					echo "#$_BUILTKEY = $_CONFDEF">>"$_PACKFILE"
					;;
			esac
		done
		echo "."
	done

	echo "Successfully created modpack \"$_PACKNAME\"."
}

_pack_uninstall() {
	_ensure_packdir
	for _PACKNAME in $@; do
		_PACKFILE="$_PACKDIR/${_PACKNAME}.toml"
		if [ ! -f "$_PACKFILE" ]; then
			echo "No such modpack \"$_PACKNAME\"!" >&2
			continue
		fi
		rm -rf "$_PACKFILE"
		echo "Successfully uninstalled modpack \"$_PACKNAME\"."
	done
}

_pack_edit() {
	_PACKFILE="$_PACKDIR/$1.toml"
	if [ ! -f "$_PACKFILE" ]; then
		echo "No such modpack \"$1\"!" >&2
		exit 1
	fi
	"$_EDITOR" "$_PACKFILE"
}

_pack_run() {
	_PACKFILE="$_PACKDIR/$1.toml"
	if [ ! -f "$_PACKFILE" ]; then
		echo "No such modpack \"$1\"!" >&2
		exit 1
	fi
	if [ ! \( -d "$_PATCHDIR" -a -d "$_MREDIR" \) ]; then
		echo "Framework is not installed!" >&2
		exit 1
	fi
	ln -sf "$_PACKFILE" "$_AERDIR/conf.toml"
	_prep_assetsdir
	_ensure_modsdir
	for _MODDIR in $(find "$_MODSDIR" -maxdepth 1 -mindepth 1); do
		_MODNAME=$(_modinfo "$_MODDIR" '.name')
		LD_LIBRARY_PATH="$_MODDIR/lib:$LD_LIBRARY_PATH"
		if [ -d "$_MODDIR/assets" ]; then
			ln -sf "$_MODDIR/assets" "$_ASSETSDIR/$_MODNAME"
		fi
	done
	export LD_LIBRARY_PATH="$_MREDIR/lib:$_GAMEDIR/lib:$LD_LIBRARY_PATH"
	export LANG="$_LANG"
	cd "$_GAMEDIR"
	"./$_MODEXEC"
	rm -f "$_AERDIR/conf.toml"
	rm -rf "$_ASSETSDIR"
}

_usage() {
	echo "usage: $_SCRIPTNAME <operation> [...]"
	echo
	echo "Management tool for the AER modding framework."
	echo
	echo "framework operations:"
	echo "	fci, framework-complete-install"
	echo "		Install both the AER patch and mod runtime environment using"
	echo "		remote repositories."
	echo "	fcu, framework-complete-uninstall"
	echo "		Uninstall both the AER patch and mod runtime environment."
	echo "	fcp, framework-complete-purge"
	echo "		Uninstall the AER patch and mod runtime environment along"
	echo "		with all mods and modpacks."
	echo "	fpi, framework-patch-install [patch_archive]"
	echo "		Install the AER patch."
	echo "		If no archive is provided, use remote repository."
	echo "	fpu, framework-patch-uninstall"
	echo "		Uninstall the AER patch."
	echo "	fmi, framework-mre-install [mre_archive]"
	echo "		Install the AER mod runtime environment."
	echo "		If no archive is provided, use remote repository."
	echo "	fmu, framework-mre-uninstall"
	echo "		Uninstall the AER mod runtime environment."
	echo "	fs, framework-status"
	echo "		Display the status of the AER modding framework installation."
	echo "		Returns:"
	echo "			0 if the framework is completely installed."
	echo "			1 if the framework is not installed."
	echo "			2 if the patch is installed but not the MRE."
	echo "			3 if the MRE is installed but not the patch."
	echo
	echo "mod operations:"
	echo "	ml, mod-list"
	echo "		List installed mods."
	echo "	mi, mod-install <mod_archive [...]>"
	echo "		Install one or more mods from mod archives."
	echo "	mu, mod-uninstall <mod_name [...]>"
	echo "		Uninstall one or more mods."
	echo "	ms, mod-status <mod_name [...]>"
	echo "		Display information about one or more mods."
	echo
	echo "modpack operations:"
	echo "	pl, pack-list"
	echo "		List created modpacks."
	echo "	pc, pack-create <pack_name> [mod_name [...]]"
	echo "		Create a modpack with an optional number of mods."
	echo "		Note that the order of the mods given determines mod priority."
	echo "	pu, pack-uninstall <pack_name [...]>"
	echo "		Uninstall one or more modpacks."
	echo "	pe, pack-edit <pack_name>"
	echo "		Edit the contents of a modpack."
	echo "	pr, pack-run <pack_name>"
	echo "		Run a modpack."
	echo
	echo "miscellaneous operations:"
	echo "	h, help"
	echo "		Display this help message."
	echo "	g, gui"
	echo "		Launch the $_SCRIPTNAME GUI."
	echo "	v, version"
	echo "		Display the version of \"$_SCRIPTNAME\"."
	echo
	echo "environment:"
	echo "	AER_GAMEDIR"
	echo "		Hyper Light Drifter game directory."
	echo "		Defaults to \"$_DEFAULT_GAMEDIR_RAW\"."
	echo "		Currently set to \"$_GAMEDIR\"."
	echo "	AER_PATCH_REPO"
	echo "		Framework binary patch repository URL."
	echo "		Defaults to \"$_DEFAULT_PATCH_REPO\"."
	echo "		Currently set to \"$_PATCH_REPO\"."
	echo "	AER_MRE_REPO"
	echo "		Framework mod runtime environment repository URL."
	echo "		Defaults to \"$_DEFAULT_MRE_REPO\"."
	echo "		Currently set to \"$_MRE_REPO\"."
	echo "	PAGER"
	echo "		Pager program used to display text."
	echo "		Defaults to \"$_DEFAULT_PAGER\"."
	echo "		Currently set to \"$_PAGER\"."
	echo "	EDITOR"
	echo "		Editing program used to modify text."
	echo "		Defaults to \"$_DEFAULT_EDITOR\"."
	echo "		Currently set to \"$_EDITOR\"."
	echo "	LANG"
	echo "		Language used to run Hyper Light Drifter."
	echo "		Defaults to \"$_DEFAULT_LANG\"."
	echo "		Currently set to \"$_LANG\"."
}

_gui() {
	# Search for GUI dependencies.
	_ensure_deps "$_GUI_DEPS"
	"$_SCRIPTDIR/bin/gui.sh" "$_SCRIPT"
}

_version() {
	echo "$_VERSION"
}



# Search for CLI dependencies.
_ensure_deps "$_CLI_DEPS"

# Determine operation.
case "$1" in

	# Framework operations.
	'fci'|'framework-complete-install')
		_framework_complete_install
		;;

	'fcu'|'framework-complete-uninstall')
		_framework_complete_uninstall
		;;

	'fcp'|'framework-complete-purge')
		_framework_complete_purge
		;;

	'fpi'|'framework-patch-install')
		_framework_patch_install "$2"
		;;

	'fpu'|'framework-patch-uninstall')
		_framework_patch_uninstall
		;;

	'fmi'|'framework-mre-install')
		_framework_mre_install "$2"
		;;

	'fmu'|'framework-mre-uninstall')
		_framework_mre_uninstall
		;;

	'fs'|'framework-status')
		_framework_status
		;;

	# Mod operations.
	'ml'|'mod-list')
		_mod_list
		;;

	'mi'|'mod-install')
		if [ $# -lt 2 ]; then
			echo "Argument \"mod_name\" is required!" >&2
			exit 1
		fi
		shift
		_mod_install $@
		;;

	'mu'|'mod-uninstall')
		if [ $# -lt 2 ]; then
			echo "Argument \"mod_name\" is required!" >&2
			exit 1
		fi
		shift
		_mod_uninstall $@
		;;

	'ms'|'mod-status')
		if [ $# -lt 2 ]; then
			echo "Argument \"mod_name\" is required!" >&2
			exit 1
		fi
		shift
		_mod_status $@
		;;

	# Modpack operations.
	'pl'|'pack-list')
		_pack_list
		;;

	'pc'|'pack-create')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		_PACKNAME=$2
		shift 2
		_pack_create $_PACKNAME $@
		;;

	'pu'|'pack-uninstall')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		shift
		_pack_uninstall $@
		;;

	'pe'|'pack-edit')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		_pack_edit $2
		;;

	'pr'|'pack-run')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		_pack_run $2
		;;

	# Miscellaneous operations.
	'g'|'gui')
		_gui
		;;
	'v'|'version')
		_version
		;;

	*)
		_usage
		;;

esac
