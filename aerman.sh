#!/usr/bin/env bash
# Copyright 2020 Garrett Fairburn <garrett@fairburn.dev>
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

_SCRIPT="$0"
_SCRIPTNAME="$(basename "$_SCRIPT")"

_NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

_DEFAULT_GAMEDIR_RAW='$HOME/.local/share/Steam/steamapps/common/HyperLightDrifter'
_DEFAULT_GAMEDIR="$(eval echo "$_DEFAULT_GAMEDIR_RAW")"
if [ -n "$AER_GAMEDIR" ]; then
	_GAMEDIR="$AER_GAMEDIR"
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

_AERDIR_REL="aer"
_AERDIR="$_GAMEDIR/$_AERDIR_REL"

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

_ensure_deps() {
	for _DEP in $@; do
		which $_DEP 1>/dev/null 2>&1
		if [ ! $? -eq 0 ]; then
			echo "This command requires \"$_DEP\" to function!" >&2
			exit 1
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
	if jq -rcMe "$2" "$_MODINFO" 2>/dev/null; then
		return 0
	else
		return 1
	fi
}



# Operations.

_framework_patch_install() {
	if [ -e "$_GAMEDIR/$_MODEXEC" ]; then
		echo "Patch is already installed!" >&2
		exit 1
	fi
	rm -rf "$_GAMEDIR/$_MODEXEC"
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
	echo "Successfully installed patch."
}

_framework_patch_uninstall() {
	if [ ! -e "$_GAMEDIR/$_MODEXEC" ]; then
		echo "Patch is not installed!" >&2
		exit 1
	fi
	rm -f "$_GAMEDIR/$_MODEXEC"
	echo "Successfully uninstalled patch."
}

_framework_mre_install() {
	if [ -d "$_MREDIR" ]; then
		echo "MRE is already installed!" >&2
		exit 1
	fi
	rm -rf "$_MREDIR"
	_prep_tmpdir
	_MREARCHIVE="$1"
	tar -C "$_TMPDIR" -xf "$_MREARCHIVE" 2>/dev/null
	if [ ! $? -eq 0 ]; then
		echo "\"$_MREARCHIVE\" is not a valid MRE archive!" >&2
		exit 1
	fi
	_STAGEDIR="$(find "$_TMPDIR" -maxdepth 1 -mindepth 1)"
	mv "$_STAGEDIR" "$_MREDIR"
	echo "Successfully installed MRE."
}

_framework_mre_uninstall() {
	if [ ! -d "$_MREDIR" ]; then
		echo "MRE is not installed!" >&2
		exit 1
	fi
	rm -rf "$_MREDIR"
	echo "Successfully uninstalled MRE."
}

_framework_purge() {
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

_framework_status() {
	test -e "$_GAMEDIR/$_MODEXEC"
	_PATCH_INSTALLED=$?
	test -d "$_MREDIR"
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
		_SRCLICENSE="$_STAGEDIR/LICENSE.txt"
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
		_ASSETLICENSE="$_STAGEDIR/assets/LICENSE.txt"
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
	echo "#  CREATED:  $_NOW" >>"$_PACKFILE"
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
	echo "# Mods in this modpack." >>"$_PACKFILE"
	echo "mods = [" >>"$_PACKFILE"
	for _MODNAME in $@; do
		echo -e "\t\"$_MODNAME\"," >>"$_PACKFILE"
	done
	echo "]" >>"$_PACKFILE"
	echo -n "."
	for _MODNAME in $@; do
		_MODDIR="$_MODSDIR/$_MODNAME"
		if [ ! -d "$_MODDIR" ]; then
			echo "No such mod \"$_MODNAME\"!" >&2
			rm "$_PACKFILE"
			exit 1
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
		echo >>"$_PACKFILE"
		echo >>"$_PACKFILE"
		echo "# ================================" >>"$_PACKFILE"
		echo "#  ${_MODNAME^^}" >>"$_PACKFILE"
		echo "# ================================" >>"$_PACKFILE"
		echo >>"$_PACKFILE"
		echo "[$_MODNAME]" >>"$_PACKFILE"
		for _CONFIDX in $(seq 0 $(($_NUMCONF - 1))); do
			_CONFELEM="$(jq -rcM ".[$_CONFIDX]" <<<"$_MODCONF")"
			echo >>"$_PACKFILE"
			if _CONFDESC="$(jq -rcMe '.description' <<<"$_CONFELEM")"; then
				echo "# $_CONFDESC" >>"$_PACKFILE"
			fi
			_CONFKEY="$(jq -rcM '.key' <<<"$_CONFELEM")"
			_NUMKEY=$(jq -rcM '. | length' <<<"$_CONFKEY")
			_BUILTKEY="$(jq -rcM ".[0]" <<<"$_CONFKEY")"
			for _KEYIDX in $(seq 1 $(($_NUMKEY - 1))); do
				_BUILTKEY="$_BUILTKEY.$(jq -rcM ".[$_KEYIDX]" <<<"$_CONFKEY")"
			done
			_CONFDEF="$(jq -cM '.default' <<<"$_CONFELEM")"
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
			echo -n "."
		done
	done

	echo
	echo "Successfully created modpack \"$_PACKNAME\"."
}

_pack_delete() {
	_ensure_packdir
	for _PACKNAME in $@; do
		_PACKFILE="$_PACKDIR/${_PACKNAME}.toml"
		if [ ! -f "$_PACKFILE" ]; then
			echo "No such modpack \"$_PACKNAME\"!" >&2
			continue
		fi
		rm -rf "$_PACKFILE"
		echo "Successfully deleted modpack \"$_PACKNAME\"."
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

_pack_launch() {
	_PACKFILE="$_PACKDIR/$1.toml"
	if [ ! -f "$_PACKFILE" ]; then
		echo "No such modpack \"$1\"!" >&2
		exit 1
	fi
	if [ ! \( -e "$_GAMEDIR/$_MODEXEC" -o -d "$_AERDIR" \) ]; then
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
	echo "	framework-patch-install <patch_archive>"
	echo "		Install the AER patch."
	echo "	framework-patch-uninstall"
	echo "		Uninstall the AER patch."
	echo "	framework-mre-install <mre_archive>"
	echo "		Install the AER mod runtime environment."
	echo "	framework-mre-uninstall"
	echo "		Uninstall the AER mod runtime environment."
	echo "	framework-purge"
	echo "		Uninstall the AER modding framework along with all"
	echo "		mods and modpacks."
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
	echo
	echo "miscellaneous operations:"
	echo "	help"
	echo "		Display this help message."
	echo "	version"
	echo "		Display the version of \"$_SCRIPTNAME\"."
	echo
	echo "environment:"
	echo "	AER_GAMEDIR"
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



# Determine operation.
case "$1" in

	# Framework operations.
	'framework-patch-install')
		_ensure_deps rsync
		if [ $# -lt 2 ]; then
			echo "Argument \"patch_archive\" is required!" >&2
			exit 1
		fi
		_framework_patch_install "$2"
		;;

	'framework-patch-uninstall')
		_framework_patch_uninstall
		;;

	'framework-mre-install')
		if [ $# -lt 2 ]; then
			echo "Argument \"mre_archive\" is required!" >&2
			exit 1
		fi
		_framework_mre_install "$2"
		;;

	'framework-mre-uninstall')
		_framework_mre_uninstall
		;;

	'framework-purge')
		_framework_purge
		;;

	'framework-status')
		_framework_status
		;;

	# Mod operations.
	'mod-list')
		_ensure_deps jq
		_mod_list
		;;

	'mod-install')
		_ensure_deps jq
		if [ $# -lt 2 ]; then
			echo "Argument \"mod_name\" is required!" >&2
			exit 1
		fi
		shift
		_mod_install $@
		;;

	'mod-uninstall')
		_ensure_deps jq
		if [ $# -lt 2 ]; then
			echo "Argument \"mod_name\" is required!" >&2
			exit 1
		fi
		shift
		_mod_uninstall $@
		;;

	'mod-info')
		_ensure_deps jq
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
		_ensure_deps jq
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
		_ensure_deps jq
		if [ $# -lt 2 ]; then
			echo "Argument \"pack_name\" is required!" >&2
			exit 1
		fi
		_pack_launch $2
		;;

	# Miscellaneous operations.
	'version')
		_version
		;;

	*)
		_usage
		;;

esac
