#!/usr/bin/env bash
# shellcheck disable=SC2086
# https://github.com/nekwebdev/chocodots-lotus
# @nekwebdev
# LICENSE: GPLv3
#
# ~/.config/cocoa/cocoa.sh
#
# script to install and configure the system according to the dotfiles.
#
set -e

###### => variables ############################################################
available_managers=("apt" "pacman")
desktop_env=""

###### => display help screen ##################################################
function display_help() {
    echo "  Description:"
    echo "    Use cocoa to setup a system"
    echo
    echo "  Usage:"
    echo "    cocoa"
    echo "    cocoa        [--de ] name" 
    echo "                 [-h | --help]"
    echo
    echo "  Options:"
    echo "    -h --help    Show this screen."
    echo "    --de         Desktop csv package list, example: --de hyprland"
    echo
}

###### => echo helpers #########################################################
# _echo_step() outputs a step collored in cyan (6), without outputing a newline.
function _echo_step() { tput setaf 6;echo -n "$1";tput sgr 0 0; }
# _exit_with_message() outputs and logs a message in red (1) before exiting the script.
function _exit_with_message() { echo;tput setaf 1;echo "$1";tput sgr 0 0;echo;exit 1; }
# _echo_right() outputs a string at the rightmost side of the screen.
function _echo_right() { local T=$1;echo;tput cuu1;tput cuf "$(tput cols)";tput cub ${#T};echo "$T"; }
# _echo_success() outputs [ OK ] in green (2), at the rightmost side of the screen.
function _echo_success() { tput setaf 2;_echo_right "[ OK ]";tput sgr 0 0; }
# _echo_failure() outputs [ OK ] in red (1), at the rightmost side of the screen.
function _echo_failure() { tput setaf 1;_echo_right "[ FAILED ]";tput sgr 0 0; }

###### => install helpers ######################################################
function commandExists () { command -v $1 >/dev/null 2>&1; }

function installpkg() {
  if [[ $manager == "pacman" ]]; then
    sudo pacman --noconfirm -S "$@" >/dev/null 2>&1
  else
    sudo $manager install -yq "$@" >/dev/null 2>&1
  fi  
}

function aurInstall() {
	_echo_step "  Installing \`$1\` ($((n-1)) of $TOTAL_PKG) from the AUR. $1 $2"
  [[ $manager != "pacman" ]] && _echo_failure && return 0
	echo "$AUR_CHECK" | grep -q "^$1$" && _echo_success && return 0
	"$aur_bin" -S --noconfirm "$1" >/dev/null 2>&1 || { _echo_failure && return 0; }
  _echo_success
}

function gitMakeInstall() {
  local progname
	progname="$(basename "$1" .git)"
	local dir="$HOME/.local/src/$progname"
	_echo_step "  Installing \`$progname\` ($((n-1)) of $TOTAL_PKG) via \`git\` and \`make\`. $(basename "$1") $2"
	git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return 0 ; git pull --force origin master >/dev/null 2>&1; } || { _echo_failure && return 0; }
	cd "$dir" || exit 1
	make >/dev/null 2>&1 || { _echo_failure && cd /tmp && return 0; }
	make install >/dev/null 2>&1 || { _echo_failure && cd /tmp && return 0; }
 	_echo_success
}

function gitClone() {
	local progname
	progname="$(basename "$1" .git)"
	local dir="$HOME/.local/src/$progname"
	_echo_step "  Cloning \`$progname\` ($((n-1)) of $TOTAL_PKG) via \`git\`. $(basename "$1") $2"
	git clone "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return 0 ; git pull --force origin master >/dev/null 2>&1; } || { _echo_failure && return 0; }
  _echo_success
}

function pipInstall() { \
	_echo_step "  Installing the Python package \`$1\` ($((n-1)) of $TOTAL_PKG). $1 $2"
	[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1" || { _echo_failure && return 0; }
  _echo_success
}

function pacmanInstall() {
	_echo_step "  Installing \`$1\` ($((n-1)) of $TOTAL_PKG). $1 $2"
	installpkg "$1"|| { _echo_failure && return 0; }
  _echo_success
}

function installPackages() {
	([ -f "$1" ] && cp "$1" /tmp/packages.csv) || curl -Ls "$1" | sed '/^#/d' > /tmp/packages.csv
  TOTAL_PKG=$(wc -l < /tmp/packages.csv)
  # remove header line from total
  TOTAL_PKG=$((TOTAL_PKG-1))
	[[ $manager == "pacman" ]] && AUR_CHECK=$(pacman -Qqm)
  # ensure src directories exist
  mkdir -p "$HOME/.local/src"
	while IFS=, read -r tag program comment; do
		n=$((n+1))
    # skip header line, account for that with $((n-1)) in outputs
    [[ "$n" == '1' ]] && continue
    # shellcheck disable=SC2001
		echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurInstall "$program" "$comment" ;;
			"G") gitMakeInstall "$program" "$comment" ;;
			"P") pipInstall "$program" "$comment" ;;
			"C") gitClone "$program" "$comment" ;;
			"#") ;; # comment do nothing
			*) pacmanInstall "$program" "$comment" ;;
		esac
	done < /tmp/packages.csv
  echo
}

###### => functions ############################################################
function check_environment() {
	# find the available package manager
	manager=""
	for pkg_manager in "${available_managers[@]}"; do
			if commandExists "$pkg_manager"; then
					manager="$pkg_manager"
					break
			fi
	done

	# get information about the distro
	distro=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

	# find the aur helper binary
	aur_bin="yay"
	command -v /usr/bin/paru >/dev/null 2>/dev/null && aur_bin="paru"
}

function installStarship() {
	if commandExists starship; then
		_echo_step "  Starship prompt already installed"
		_echo_success
	else
		_echo_step "  Installing Starship prompt"
		curl -sS https://starship.rs/install.sh | sh
		_echo_success
	fi
}

function debianConfigs() {
	_echo_step "  Create symlink bat for batcat"
	[[ -x /usr/bin/batcat ]] && ln -sfT /usr/bin/batcat "$HOME/.local/bin/bat"
  _echo_success
}

###### => main #################################################################
function main() {
  # main steps
  _echo_step "Cocoa $distro configuration from dotfiles"; echo; echo
  local packages
  packages="$HOME/.config/cocoa/base/$manager.base.csv"
  _echo_step "Install base packages"; echo; echo
  [[ -f $packages ]] && installPackages "$packages"

	if [[ -n $desktop_env ]]; then
		packages="$HOME/.config/cocoa/desktop/$manager.$desktop_env.csv"
		_echo_step "Install $desktop_env packages"; echo; echo
		[[ -f $packages ]] && installPackages "$packages"
	fi

  _echo_step "Extra applications"; echo; echo
  installStarship

  if [[ $manager == "apt" ]]; then
  	_echo_step "Debian extra configurations"; echo; echo
		debianConfigs
  fi

  # save log
  [[ -f /tmp/chocolate.cocoa.log ]] && mv -f /tmp/chocolate.cocoa.log "$HOME"/.local/log/chocolate.cocoa.log
  exit 0
}

###### => parse flags ##########################################################
while (( "$#" )); do
  case "$1" in
    -h|--help) display_help; exit 0 ;;
    --de)
      if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
        desktop_env=$2; shift
      else
        _exit_with_message "when using --de a csv name must be given. Example: '--de hyprland'"
      fi ;;
    *)
      shift ;;
  esac
done

check_environment

main "$@" | tee /tmp/chocolate.cocoa.log
