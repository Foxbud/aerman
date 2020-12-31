#!/usr/bin/env bash
# Copyright 2020 Garrett Fairburn
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

_VERSION="0.1.0"

_DEPS="jq rsync tar"

_SCRIPT="$0"

_NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

_DEFAULT_GAMEDIR_RAW='$HOME/.local/share/Steam/steamapps/common/HyperLightDrifter'
_DEFAULT_GAMEDIR="$(eval echo "$_DEFAULT_GAMEDIR_RAW")"
if [ -n "$AERMAN_GAMEDIR" ]; then
	_GAMEDIR="$AERMAN_GAMEDIR"
else
	_GAMEDIR="$_DEFAULT_GAMEDIR"
fi

_DEFAULT_PAGER=less
if [ -n "$PAGER" ]; then
	_PAGER="$PAGER"
else
	_PAGER="$_DEFAULT_PAGER"
fi

_DEFAULT_EDITOR=nano
if [ -n "$EDITOR" ]; then
	_EDITOR="$EDITOR"
else
	_EDITOR="$_DEFAULT_EDITOR"
fi

_MODSDIR_REL="mods"
_MODSDIR="$_GAMEDIR/$_MODSDIR_REL"

_PACKDIR_REL="packs"
_PACKDIR="$_GAMEDIR/$_PACKDIR_REL"

_ASSETSDIR_REL="assets/mod"
_ASSETSDIR="$_GAMEDIR/$_ASSETSDIR_REL"

_TMPDIR_REL="aermantmp"
_TMPDIR="$_GAMEDIR/$_TMPDIR_REL"

_ORIGEXEC="HyperLightDrifter"
_MODEXEC="${_ORIGEXEC}Patched"
_EXECDIFF="${_ORIGEXEC}Diff"

_MRELIB="libaermre.so"



# Utility functions.

_ensure_deps() {
	for _DEP in $_DEPS; do
		which $_DEP 1>/dev/null 2>&1
		if [ ! $? -eq 0 ]; then
			echo "This script requires \"$_DEP\" to function!" >&2
			return 1
		fi
	done
	return 0
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

_modinfo() {
	_MODINFO="$1/ModInfo.json"
	if jq -rcMe "$2" "$_MODINFO" 2>/dev/null; then
		return 0
	else
		return 1
	fi
}



# Operations.

_framework_install() {
	if [ -e "$_GAMEDIR/$_MODEXEC" -a -e "$_GAMEDIR/lib/$_MRELIB" ]; then
		echo "Framework is already installed!" >&2
		exit 1
	fi
	rm -rf "$_GAMEDIR/$_MODEXEC" "$_GAMEDIR/lib/$_MRELIB"
	_prep_tmpdir
	_PATCHARCHIVE="$1"
	tar -C "$_TMPDIR" -xf "$_PATCHARCHIVE" 2>/dev/null
	if [ ! $? -eq 0 ]; then
		echo "\"$_PATCHARCHIVE\" is not a valid patch archive!" >&2
		exit 1
	fi
	_STAGEDIR="$(find "$_TMPDIR" -maxdepth 1 -mindepth 1)"
	cp "$_GAMEDIR/$_ORIGEXEC" "$_GAMEDIR/$_MODEXEC"
	rsync --read-batch="$_STAGEDIR/$_EXECDIFF" "$_GAMEDIR/$_MODEXEC" 2>/dev/null
	if [ ! $? -eq 0 ]; then
		echo "Could not patch executable!" >&2
		rm "$_GAMEDIR/$_MODEXEC"
		exit 1
	fi
	_prep_tmpdir
	_MREARCHIVE="$2"
	tar -C "$_TMPDIR" -xf "$_MREARCHIVE" 2>/dev/null
	if [ ! $? -eq 0 ]; then
		echo "\"$_MREARCHIVE\" is not a valid MRE archive!" >&2
		exit 1
	fi
	_STAGEDIR="$(find "$_TMPDIR" -maxdepth 1 -mindepth 1)"
	mv "$_STAGEDIR/lib/$_MRELIB" "$_GAMEDIR/lib/$_MRELIB"
	echo "Successfully installed framework."
}

_framework_uninstall() {
	if [ ! \( -e "$_GAMEDIR/$_MODEXEC" -o -e "$_GAMEDIR/lib/$_MRELIB" \) ]; then
		echo "Framework is not installed!" >&2
		exit 1
	fi
	rm -rf "$_GAMEDIR/$_MODEXEC" "$_GAMEDIR/lib/$_MRELIB"
	echo "Successfully uninstalled framework."
}

_framework_status() {
	test -e "$_GAMEDIR/$_MODEXEC"
	_PATCH_INSTALLED=$?
	test -e "$_GAMEDIR/lib/$_MRELIB"
	_MRE_INSTALLED=$?
	if [ $_PATCH_INSTALLED -eq 0 ]; then
		echo "Patch installed."
		if [ $_MRE_INSTALLED -eq 0 ]; then
			echo "MRE installed."
			return 0
		else
			echo "MRE not installed."
			return 2
		fi
	else
		echo "Patch not installed."
		if [ $_MRE_INSTALLED -eq 0 ]; then
			echo "MRE installed."
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
	_prep_tmpdir
	for _MODARCHIVE in $@; do
		tar -C "$_TMPDIR" -xf "$_MODARCHIVE" 2>/dev/null
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
		_SRCLICENSE="$_STAGEDIR/LICENSE.source.txt"
		if [ -e "$_SRCLICENSE" ]; then
			while true; do
				echo "Mod \"$_MODNAME\" has a source code license."
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
						"$_PAGER" "$_SRCLICENSE"
						;;
				esac
			done
		fi
		_ASSETLICENSE="$_STAGEDIR/LICENSE.assets.txt"
		if [ -e "$_ASSETLICENSE" ]; then
			while true; do
				echo "Mod \"$_MODNAME\" has an asset license."
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
						"$_PAGER" "$_ASSETLICENSE"
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

_mod_info() {
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
	for _PACKFILE in $(find "$_PACKDIR" -maxdepth 1 -mindepth 1 -regex '.*\.sh'); do
		_PACKNAME=$(basename "$_PACKFILE")
		_PACKNAME=${_PACKNAME%.sh}
		echo $_PACKNAME
	done
}

_pack_create() {
	_ensure_packdir
	_PACKNAME=$1
	shift
	_PACKFILE="$_PACKDIR/${_PACKNAME}.sh"
	if [ -e "$_PACKFILE" ]; then
		echo "Modpack \"$_PACKNAME\" already exists!" >&2
		exit 1
	fi
	echo "#!/usr/bin/env bash" >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo "# Modpack \"$_PACKNAME\"." >>"$_PACKFILE"
	echo "# Automatically generated by \"$_SCRIPT\" on $_NOW." >>"$_PACKFILE"
	echo "# Change a configuration value by uncommenting the appropriate export." >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo "# Set working directory." >>"$_PACKFILE"
	echo "if [ -n \"\$AERMAN_GAMEDIR\" ]; then" >>"$_PACKFILE"
	echo "	cd \"\$AERMAN_GAMEDIR\"" >>"$_PACKFILE"
	echo "else" >>"$_PACKFILE"
	echo "	cd \"$_DEFAULT_GAMEDIR_RAW\"" >>"$_PACKFILE"
	echo "fi" >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo "# Prepare mod asset directory." >>"$_PACKFILE"
	echo "rm -rf ./$_ASSETSDIR_REL" >>"$_PACKFILE"
	echo "mkdir -p ./$_ASSETSDIR_REL" >>"$_PACKFILE"
	for _MODNAME in $@; do
		_MODDIR="$_MODSDIR/$_MODNAME"
		if [ ! -d "$_MODDIR" ]; then
			echo "No such mod \"$_MODNAME\"!" >&2
			rm "$_PACKFILE"
			exit 1
		fi
		echo >>"$_PACKFILE"
		echo >>"$_PACKFILE"
		echo >>"$_PACKFILE"
		echo "# Mod \"$_MODNAME\" configuration." >>"$_PACKFILE"
		echo >>"$_PACKFILE"
		echo "# Prepare mod resources." >>"$_PACKFILE"
		echo "export LD_LIBRARY_PATH=./$_MODSDIR_REL/$_MODNAME/lib:\$LD_LIBRARY_PATH" >>"$_PACKFILE"
		if [ -d "$_MODDIR/assets" ]; then
			echo "ln -sf \"\$PWD/$_MODSDIR_REL/$_MODNAME/assets\" ./$_ASSETSDIR_REL/$_MODNAME" >>"$_PACKFILE"
		fi
		_MODCONF="$(_modinfo "$_MODDIR" '.configuration')"
		if [ ! $? -eq 0 ]; then
			continue
		fi
		_NUMCONF=$(jq -rcM '. | length' <<<"$_MODCONF")
		if [ $_NUMCONF -eq 0 ]; then
			continue
		fi
		echo >>"$_PACKFILE"
		for _CONFIDX in $(seq 0 $(($_NUMCONF - 1))); do
			_CONFELEM="$(jq -rcM ".[$_CONFIDX]" <<<"$_MODCONF")"
			if _CONFDESC="$(jq -rcMe '.description' <<<"$_CONFELEM")"; then
				echo "# $_CONFDESC" >>"$_PACKFILE"
			fi
			_CONFKEY=$(jq -rcM '.key' <<<"$_CONFELEM")
			echo "#export $_CONFKEY=\"\"" >>"$_PACKFILE"
		done
	done
	echo >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo >>"$_PACKFILE"
	echo "# Launch this modpack." >>"$_PACKFILE"
	echo "export AER_MODS=\"$@\"" >>"$_PACKFILE"
	echo "export LD_LIBRARY_PATH=./lib:\$LD_LIBRARY_PATH" >>"$_PACKFILE"
	echo "./$_MODEXEC 2>&1 | tee ./$_PACKDIR_REL/${_PACKNAME}.log" >>"$_PACKFILE"
	chmod +x "$_PACKFILE"
	echo "Successfully created modpack \"$_PACKNAME\"."
}

_pack_delete() {
	_ensure_packdir
	for _PACKNAME in $@; do
		_PACKFILE="$_PACKDIR/${_PACKNAME}.sh"
		if [ ! -f "$_PACKFILE" ]; then
			echo "No such modpack \"$_PACKNAME\"!" >&2
			continue
		fi
		_PACKLOG="$_PACKDIR/${_PACKNAME}.log"
		rm -rf "$_PACKFILE" "$_PACKLOG"
		echo "Successfully deleted modpack \"$_PACKNAME\"."
	done
}

_pack_edit() {
	_PACKFILE="$_PACKDIR/$1.sh"
	if [ ! -f "$_PACKFILE" ]; then
		echo "No such modpack \"$1\"!" >&2
		exit 1
	fi
	"$_EDITOR" "$_PACKFILE"
}

_pack_launch() {
	_PACKFILE="$_PACKDIR/$1.sh"
	if [ ! -f "$_PACKFILE" ]; then
		echo "No such modpack \"$1\"!" >&2
		exit 1
	fi
	if [ ! \( -e "$_GAMEDIR/$_MODEXEC" -o -e "$_GAMEDIR/lib/$_MRELIB" \) ]; then
		echo "Framework is not installed!" >&2
		exit 1
	fi
	"$_PACKFILE"
}

_pack_log() {
	_PACKFILE="$_PACKDIR/$1.sh"
	if [ ! -f "$_PACKFILE" ]; then
		echo "No such modpack \"$1\"!" >&2
		exit 1
	fi
	_PACKLOG="$_PACKDIR/$1.log"
	if [ ! -f "$_PACKLOG" ]; then
		echo "Modpack \"$1\" does not have a runtime log!" >&2
		exit 1
	fi
	"$_PAGER" "$_PACKLOG"
}

_usage() {
	echo "usage: $_SCRIPT <operation> [...]"
	echo
	echo "Management tool for the AER modding framework."
	echo
	echo "framework operations:"
	echo "	framework-install <patch_archive> <mre_archive>"
	echo "		Install the AER modding framework."
	echo "	framework-uninstall"
	echo "		Uninstall the AER modding framework."
	echo "	framework-status"
	echo "		Display the status of the AER modding framework installation."
	echo "		Returns:"
	echo "			0 if the framework is completely installed."
	echo "			1 if the framework is not installed."
	echo "			2 if the patch is installed but not the MRE."
	echo "			3 if the MRE is installed but not the patch."
	echo
	echo "mod operations:"
	echo "	mod-list"
	echo "		List installed mods."
	echo "	mod-install <mod_archive [...]>"
	echo "		Install one or more mods from mod archives."
	echo "	mod-uninstall <mod_name [...]>"
	echo "		Uninstall one or more mods."
	echo "	mod-info <mod_name [...]>"
	echo "		Display information about one or more mods."
	echo
	echo "modpack operations:"
	echo "	pack-list"
	echo "		List created modpacks."
	echo "	pack-create <pack_name> [mod_name [...]]"
	echo "		Create a modpack with an optional number of mods."
	echo "		Note that the order of the mods given determines mod priority."
	echo "	pack-delete <pack_name [...]>"
	echo "		Delete one or more modpacks."
	echo "	pack-edit <pack_name>"
	echo "		Edit the contents of a modpack."
	echo "	pack-launch <pack_name>"
	echo "		Launch a modpack."
	echo "	pack-log <pack_name>"
	echo "		Display a modpack's most recent runtime log."
	echo
	echo "miscellaneous operations:"
	echo "	help"
	echo "		Display this help message."
	echo "	version"
	echo "		Display the version of \"$_SCRIPT\"."
	echo
	echo "environment:"
	echo "	AERMAN_GAMEDIR"
	echo "		Hyper Light Drifter game directory."
	echo "		Defaults to \"$_DEFAULT_GAMEDIR_RAW\"."
	echo "		Currently set to \"$_GAMEDIR\"."
	echo "	PAGER"
	echo "		Pager program used to display text."
	echo "		Defaults to \"$_DEFAULT_PAGER\"."
	echo "		Currently set to \"$_PAGER\"."
	echo "	EDITOR"
	echo "		Editing program used to modify text."
	echo "		Defaults to \"$_DEFAULT_EDITOR\"."
	echo "		Currently set to \"$_EDITOR\"."
}

_version() {
	echo "$_VERSION"
}



# Check that dependencies are met.
_ensure_deps || exit 1

# Determine operation.
case "$1" in

	# Framework operations.
	'framework-install')
		if [ $# -lt 3 ]; then
			echo "Arguments \"patch_archive\" and \"mre_archive\" are required!" >&2
			exit 1
		fi
		_framework_install "$2" "$3"
		;;

	'framework-uninstall')
		_framework_uninstall
		;;

	'framework-status')
		_framework_status
		;;

	# Mod operations.
	'mod-list')
		_mod_list
		;;

	'mod-install')
		if [ $# -lt 2 ]; then
			echo "Argument \"mod_name\" is required!" >&2
			exit 1
		fi
		shift
		_mod_install $@
		;;

	'mod-uninstall')
		if [ $# -lt 2 ]; then
			echo "Argument \"mod_name\" is required!" >&2
			exit 1
		fi
		shift
		_mod_uninstall $@
		;;

	'mod-info')
		if [ $# -lt 2 ]; then
			echo "Argument \"mod_name\" is required!" >&2
			exit 1
		fi
		shift
		_mod_info $@
		;;

	# Modpack operations.
	'pack-list')
		_pack_list
		;;

	'pack-create')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		_PACKNAME=$2
		shift 2
		_pack_create $_PACKNAME $@
		;;

	'pack-delete')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		shift
		_pack_delete $@
		;;

	'pack-edit')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		_pack_edit $2
		;;

	'pack-launch')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		_pack_launch $2
		;;

	'pack-log')
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		_pack_log $2
		;;

	# Miscellaneous operations.
	'version')
		_version
		;;

	*)
		_usage
		;;

esac
