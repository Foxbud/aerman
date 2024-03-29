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

_TITLE="AERMan GUI"

_WIDTH="640"
_HEIGHT="480"

_AERMAN="$1"

_GO_SUF=" >>"
_GO="Go$_GO_SUF"
_BACK_PRE="<< "
_BACK="${_BACK_PRE}Back"



# Utility functions.

_widget() {
	$_ZENITY --title="$_TITLE" --width="$_WIDTH" --height="$_HEIGHT" "$@"
}

_aerman() {
	export PAGER=echo
	export EDITOR=echo
	"$_AERMAN" $@
}

_dialog_display() {
	echo "<span size=\"xx-large\"><b>$_TITLE</b>  </span><span size=\"large\">$1</span>\n\n$2"
}

_success_popup() {
	_widget \
		--info \
		--ok-label="$_BACK" \
		--text="$(_dialog_display "<span foreground=\"green\">Success</span>" \
		"$1")"
}

_warning_popup() {
	_widget \
		--warning \
		--ok-label="$_BACK" \
		--text="$(_dialog_display "<span foreground=\"yellow\">Warning</span>" \
		"$1")"
}

_list_mods() {
	_AERMAN_OUT="$(_aerman ml)"
	for _MOD in $_AERMAN_OUT; do
		echo "$_MOD" "$_MOD"
	done
}

_list_modpacks() {
	_AERMAN_OUT="$(_aerman pl)"
	for _PACK in $_AERMAN_OUT; do
		echo "$_PACK" "$_PACK"
	done
}

_escape() {
	_RESULT="$1"
	_RESULT="${_RESULT//'&'/'&amp;'}"
	_RESULT="${_RESULT//</'&lt;'}"
	_RESULT="${_RESULT//>/'&gt;'}"
	_RESULT="${_RESULT//"'"/'&\#39;'}"

	echo "$_RESULT"
}



# Dialogs.

_main_menu_dialog() {
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="${_BACK_PRE}Exit" \
		--text="$(_dialog_display "Main Menu" \
		"Which part of the AER framework would you like to manage?")" \
		--hide-header \
		--column="key" \
		"Framework" \
		"Mods" \
		"Modpacks" \
		--
		)"
	if [ ! $? -eq 0 ]; then
		echo
		return
	fi
	case "$_INPUT" in
		"Framework")
			echo "_framework_menu_dialog"
			;;
		"Mods")
			echo "_mod_menu_dialog"
			;;
		"Modpacks")
			echo "_modpack_menu_dialog"
			;;
		*)
			echo "_main_menu_dialog"
			;;
	esac
}

_framework_menu_dialog() {
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Framework Menu" \
			"Which AER framework operation would you like to perform?")" \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		"fci" "Install the Latest Framework Patch and Mod Runtime Environment" \
		"fcu" "Uninstall the Framework Patch and Mod Runtime Environment" \
		"fcp" "Uninstall all Components of the AER Framework" \
		"fpi" "Install the Framework Patch" \
		"fpu" "Uninstall the Framework Patch" \
		"fmi" "Install the Mod Runtime Environment" \
		"fmu" "Uninstall the Mod Runtime Environment" \
		"fs" "Display the Status of the Framework" \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_main_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"fci")
			echo "_framework_complete_install_dialog"
			;;
		"fcu")
			echo "_framework_complete_uninstall_dialog"
			;;
		"fcp")
			echo "_framework_complete_purge_dialog"
			;;
		"fpi")
			echo "_framework_patch_install_dialog"
			;;
		"fpu")
			echo "_framework_patch_uninstall_dialog"
			;;
		"fmi")
			echo "_framework_mre_install_dialog"
			;;
		"fmu")
			echo "_framework_mre_uninstall_dialog"
			;;
		"fs")
			echo "_framework_status_dialog"
			;;
		*)
			echo "_framework_menu_dialog"
			;;
	esac
}

_framework_complete_install_dialog() {
	if _widget \
		--question \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Framework Install" \
		"Are you sure you want to download and install the latest versions of the framework patch and MRE?")"
	then
		if _AERMAN_OUT="$(_aerman fci 2>&1)"; then
			_success_popup "$_AERMAN_OUT"
		else
			_warning_popup "$_AERMAN_OUT"
		fi
	fi

	echo "_framework_menu_dialog"
}

_framework_complete_uninstall_dialog() {
	if _widget \
		--question \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Framework Uninstall" \
		"Are you sure you want to uninstall the framework patch and MRE?")"
	then
		if _AERMAN_OUT="$(_aerman fcu 2>&1)"; then
			_success_popup "$_AERMAN_OUT"
		else
			_warning_popup "$_AERMAN_OUT"
		fi
	fi

	echo "_framework_menu_dialog"
}

_framework_complete_purge_dialog() {
	if _widget \
		--question \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Framework Purge" \
		"Are you sure you want to uninstall all components the AER framework including mods and modpacks?")"
	then
		if _AERMAN_OUT="$(_aerman fcp <<<"y" 2>&1 | tail -n 1)"; then
			_success_popup "$_AERMAN_OUT"
		else
			_warning_popup "$_AERMAN_OUT"
		fi
	fi

	echo "_framework_menu_dialog"
}

_framework_patch_install_dialog() {
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Patch Install" \
			"Which patch archive would you like to install?")" \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		"r" "Download the Latest Version" \
		"a" "Use Your Own" \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_framework_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"r")
			if _AERMAN_OUT="$(_aerman fpi 2>&1)"; then
				_success_popup "$_AERMAN_OUT"
			else
				_warning_popup "$_AERMAN_OUT"
			fi
			echo "_framework_menu_dialog"
			;;
		"a")
			_INPUT="$(_widget \
				--file-selection \
				--file-filter="*.tar.xz *.tar.gz" \
				)"
			if _AERMAN_OUT="$(_aerman fpi "$_INPUT" 2>&1)"; then
				_success_popup "$_AERMAN_OUT"
			else
				_warning_popup "$_AERMAN_OUT"
			fi
			echo "_framework_menu_dialog"
			;;
		*)
			echo "_framework_patch_install_dialog"
			;;
	esac
}

_framework_patch_uninstall_dialog() {
	if _widget \
		--question \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Framework Patch Uninstall" \
		"Are you sure you want to uninstall the framework patch?")"
	then
		if _AERMAN_OUT="$(_aerman fpu 2>&1)"; then
			_success_popup "$_AERMAN_OUT"
		else
			_warning_popup "$_AERMAN_OUT"
		fi
	fi

	echo "_framework_menu_dialog"
}

_framework_mre_install_dialog() {
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "MRE Install" \
			"Which MRE archive would you like to install?")" \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		"r" "Download the Latest Version" \
		"a" "Use Your Own" \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_framework_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"r")
			if _AERMAN_OUT="$(_aerman fmi 2>&1)"; then
				_success_popup "$_AERMAN_OUT"
			else
				_warning_popup "$_AERMAN_OUT"
			fi
			echo "_framework_menu_dialog"
			;;
		"a")
			_INPUT="$(_widget \
				--file-selection \
				--file-filter="*.tar.xz *.tar.gz" \
				)"
			if _AERMAN_OUT="$(_aerman fmi "$_INPUT" 2>&1)"; then
				_success_popup "$_AERMAN_OUT"
			else
				_warning_popup "$_AERMAN_OUT"
			fi
			echo "_framework_menu_dialog"
			;;
		*)
			echo "_framework_mre_install_dialog"
			;;
	esac
}

_framework_mre_uninstall_dialog() {
	if _widget \
		--question \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Framework MRE Uninstall" \
		"Are you sure you want to uninstall the framework MRE?")"
	then
		if _AERMAN_OUT="$(_aerman fmu 2>&1)"; then
			_success_popup "$_AERMAN_OUT"
		else
			_warning_popup "$_AERMAN_OUT"
		fi
	fi

	echo "_framework_menu_dialog"
}

_framework_status_dialog() {
	_widget \
		--info \
		--ok-label="$_BACK" \
		--text="$(_dialog_display "Framework Status" \
		"$(_aerman fs)")"

	echo "_framework_menu_dialog"
}

_mod_menu_dialog() {
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Mod Menu" \
			"Which mod operation would you like to perform?")" \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		"mi" "Install One or More Mods" \
		"mu" "Uninstall One or More Mods" \
		"ms" "Display the Status of a Mod" \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_main_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"mi")
			echo "_mod_install_dialog"
			;;
		"mu")
			echo "_mod_uninstall_dialog"
			;;
		"ms")
			echo "_mod_status_dialog"
			;;
		*)
			echo "_mod_menu_dialog"
			;;
	esac
}

_mod_install_dialog() {
	_INPUT="$(_widget \
		--file-selection \
		--multiple \
		--separator=" " \
		--file-filter="*.tar.xz *.tar.gz" \
		)"
	_TMP=$(mktemp -d --tmpdir aerman-gui.XXXXXXXX)
	trap "rm -rf $_TMP" EXIT SIGINT
	_IN=$_TMP/_IN
	_OUT=$_TMP/_OUT
	mkfifo $_IN $_OUT
	_aerman mi $_INPUT <$_IN >$_OUT 2>&1 &
	_AERMAN_PID=$!
	trap "kill $_AERMAN_PID" SIGINT
	exec 3>$_IN 4<$_OUT
	while kill -0 $_AERMAN_PID 2>/dev/null; do
		while read _LINE <&4; do
			if grep "Successfully" <<<$_LINE >/dev/null; then
				_success_popup "$_LINE"
				continue
			fi
			if grep -e "valid" -e "already" -e "will not" <<<$_LINE >/dev/null; then
				_warning_popup "$_LINE"
				continue
			fi
			if grep "license" <<<$_LINE >/dev/null; then
				_MOD=$(grep -Po '(?<=")\S*(?=")' <<<$_LINE)
				read _LINE <&4
				echo -n 'v' >&3
				read _LINE <&4
				read _LICENSE <&4
				read _LINE <&4
				read _LINE <&4
				if _widget \
					--text-info \
					--ok-label="Accept$_GO_SUF" \
					--cancel-label="${_BACK_PRE}Reject" \
					--filename="$_LICENSE" \
					--checkbox="I accept the license of mod \"$_MOD\""
				then
					echo -n 'a' >&3
				else
					echo -n 'r' >&3
				fi
				continue
			fi
		done
	done

	echo "_mod_menu_dialog"
}

_mod_uninstall_dialog() {
	_AERMAN_OUT="$(_list_mods)"
	if [ -z "$_AERMAN_OUT" ]; then
		_warning_popup "There are no mods."
		echo "_mod_menu_dialog"
		return
	fi
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Mod Uninstall" \
			"Which mod(s) would you like to uninstall?")" \
		--multiple \
		--separator=" " \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		$_AERMAN_OUT \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_mod_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"")
			echo "_mod_uninstall_dialog"
			;;
		*)
			if _AERMAN_OUT="$(_aerman mu $_INPUT 2>&1)"; then
				_success_popup "$_AERMAN_OUT"
			else
				_warning_popup "$_AERMAN_OUT"
			fi
			echo "_mod_menu_dialog"
			;;
	esac
}

_mod_status_dialog() {
	_AERMAN_OUT="$(_list_mods)"
	if [ -z "$_AERMAN_OUT" ]; then
		_warning_popup "There are no mods."
		echo "_mod_menu_dialog"
		return
	fi
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Mod Status" \
			"Which mod would you like to display the status of?")" \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		$_AERMAN_OUT \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_mod_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"")
			echo "_mod_status_dialog"
			;;
		*)
			_AERMAN_OUT="$(_aerman ms $_INPUT)"
			_widget \
				--info \
				--ok-label="$_BACK" \
				--text="$(_dialog_display "Mod Status" \
				"$(_escape "$_AERMAN_OUT")")"
			echo "_mod_menu_dialog"
			;;
	esac
}

_modpack_menu_dialog() {
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Modpack Menu" \
			"Which modpack operation would you like to perform?")" \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		"pc" "Create a Modpack" \
		"pu" "Uninstall One or More Modpacks" \
		"pe" "Configure a Modpack" \
		"pr" "Run a Modpack" \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_main_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"pc")
			echo "_modpack_create_dialog"
			;;
		"pu")
			echo "_modpack_uninstall_dialog"
			;;
		"pe")
			echo "_modpack_edit_dialog"
			;;
		"pr")
			echo "_modpack_run_dialog"
			;;
		*)
			echo "_modpack_menu_dialog"
			;;
	esac
}

_modpack_create_dialog() {
	_PACKNAME="$(_widget \
		--entry \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="Enter a name for the new modpack:" \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_modpack_menu_dialog"
		return
	fi
	_AERMAN_OUT="$(_list_mods)"
	_MODS=()
	if [ -n "$_AERMAN_OUT" ]; then
		_MODS=($(_widget \
			--list \
			--ok-label="$_GO" \
			--cancel-label="$_BACK" \
			--text="$(_dialog_display "Modpack Create" \
				"Which mod(s) would you like to include in \"$_PACKNAME\"?")" \
			--multiple \
			--separator=" " \
			--hide-header \
			--hide-column=1 \
			--column="key" \
			--column="desc" \
			$(_list_mods) \
			))
		if [ ! $? -eq 0 ]; then
			echo "_modpack_menu_dialog"
			return
		fi
	fi
	_INC_AMOUNT=$((100 / (${#_MODS[@]} + 1)))
	_CUR_AMOUNT=0
	_TMP=$(mktemp -d --tmpdir aerman-gui.XXXXXXXX)
	trap "rm -rf $_TMP" EXIT SIGINT
	_IN=$_TMP/_IN
	_OUT=$_TMP/_OUT
	mkfifo $_IN $_OUT
	_aerman pc "$_PACKNAME" ${_MODS[@]} >$_OUT 2>&1 &
	_AERMAN_PID=$!
	trap "kill $_AERMAN_PID" SIGINT
	_widget \
		--progress \
		--auto-close \
		--no-cancel \
		--text="$(_dialog_display "Modpack Create" \
		"Creating modpack \"$_PACKNAME\"...")" <$_IN &
	trap "kill $!" SIGINT
	exec 3>$_IN 4<$_OUT
	while kill -0 $_AERMAN_PID 2>/dev/null; do
		while read _LINE <&4; do
			if grep "Successfully" <<<$_LINE >/dev/null; then
				echo 100 >&3
				_success_popup "$_LINE"
				continue
			fi
			if grep "already" <<<$_LINE >/dev/null; then
				echo 100 >&3
				_warning_popup "$_LINE"
				continue
			fi
			if grep "^\.$" <<<$_LINE >/dev/null; then
				_CUR_AMOUNT=$(($_CUR_AMOUNT + $_INC_AMOUNT))
				echo $_CUR_AMOUNT >&3
				continue
			fi
		done
	done

	echo "_modpack_menu_dialog"
}

_modpack_uninstall_dialog() {
	_AERMAN_OUT="$(_list_modpacks)"
	if [ -z "$_AERMAN_OUT" ]; then
		_warning_popup "There are no modpacks."
		echo "_modpack_menu_dialog"
		return
	fi
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Modpack Uninstall" \
			"Which modpack(s) would you like to uninstall?")" \
		--multiple \
		--separator=" " \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		$_AERMAN_OUT \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_modpack_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"")
			echo "_modpack_uninstall_dialog"
			;;
		*)
			if _AERMAN_OUT="$(_aerman pu $_INPUT 2>&1)"; then
				_success_popup "$_AERMAN_OUT"
			else
				_warning_popup "$_AERMAN_OUT"
			fi
			echo "_modpack_menu_dialog"
			;;
	esac
}

_modpack_edit_dialog() {
	_AERMAN_OUT="$(_list_modpacks)"
	if [ -z "$_AERMAN_OUT" ]; then
		_warning_popup "There are no modpacks."
		echo "_modpack_menu_dialog"
		return
	fi
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Modpack Configure" \
			"Which modpack would you like to configure?")" \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		$_AERMAN_OUT \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_modpack_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"")
			echo "_modpack_edit_dialog"
			;;
		*)
			_PACKFILE="$(_aerman pe $_INPUT 2>&1)"
			_PACK="$(basename -s ".toml" "$_PACKFILE")"
			if _PACKCONF="$(_widget \
				--text-info \
				--editable \
				--ok-label="Save$_GO_SUF" \
				--cancel-label="$_BACK" \
				--filename="$_PACKFILE")"
			then
				echo "$_PACKCONF" >"$_PACKFILE"
				_success_popup "Successfully configured modpack \"$_PACK\"."
			fi
			echo "_modpack_menu_dialog"
			;;
	esac
}

_modpack_run_dialog() {
	_AERMAN_OUT="$(_list_modpacks)"
	if [ -z "$_AERMAN_OUT" ]; then
		_warning_popup "There are no modpacks."
		echo "_modpack_menu_dialog"
		return
	fi
	_INPUT="$(_widget \
		--list \
		--ok-label="$_GO" \
		--cancel-label="$_BACK" \
		--text="$(_dialog_display "Modpack Run" \
			"Which modpack would you like to run?")" \
		--hide-header \
		--hide-column=1 \
		--column="key" \
		--column="desc" \
		$_AERMAN_OUT \
		)"
	if [ ! $? -eq 0 ]; then
		echo "_modpack_menu_dialog"
		return
	fi
	case "$_INPUT" in
		"")
			echo "_modpack_run_dialog"
			;;
		*)
			_TMP=$(mktemp -d --tmpdir aerman-gui.XXXXXXXX)
			trap "rm -rf $_TMP" EXIT SIGINT
			_OUT=$_TMP/_OUT
			mkfifo $_OUT
			_aerman pr "$_INPUT" >$_OUT 2>&1 &
			exec 3<$_OUT
			if _widget \
				--text-info \
				--ok-label="Stop$_GO_SUF" \
				--cancel-label="$_BACK" <&3
			then
				_HLD_PID=($(pgrep "HyperLight")) && kill -s KILL ${_HLD_PID[-1]}
			fi
			echo "_modpack_menu_dialog"
			;;
	esac
}



# Event loop.
_NEXT_DIALOG="_main_menu_dialog"
while [  "${_NEXT_DIALOG::1}" = "_" ]; do
	_NEXT_DIALOG="$($_NEXT_DIALOG 2>&1)"
	if [ ! \( $? -eq 0 -a \( "${_NEXT_DIALOG::1}" = "_" -o -z "$_NEXT_DIALOG" \) \) ]; then
		_widget \
			--error \
			--text="$(_dialog_display "<span foreground=\"red\">Error</span>" \
			"$_NEXT_DIALOG")"
		exit 1
	fi
done
