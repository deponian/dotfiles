#!/usr/bin/env bash
set -euo pipefail
shopt -s extglob nullglob
IFS=$'\n\t'

# colored echo
function cecho {
	case "${1}" in
		red   ) echo -e "\e[91m${2}\e[39m";;
		green ) echo -e "\e[92m${2}\e[39m";;
		yellow) echo -e "\e[93m${2}\e[39m";;
		blue  ) echo -e "\e[94m${2}\e[39m";;
		purple) echo -e "\e[95m${2}\e[39m";;
		cyan  ) echo -e "\e[96m${2}\e[39m";;
	esac
}

# check if system has necessary software
check_software () {
	for program in "$@"
	do
		command -v "${program}" >/dev/null 2>&1 || \
		{
			echo >&2 -e "Aborting.\nThis script needs these programs:\n${*}"
			exit 1
		}
	done
}
# install necessary well-known packages
# which you can find in default repos on every modern distro
install_packages () {
	local mode tmpdir

	mode="${1:?"You have to specify mode as first parametr"}"
	cecho blue "[Installing packages]"
	tmpdir="/tmp/${RANDOM}"
	mkdir -p "${tmpdir}"
	(
		cd "${tmpdir}"
		wget --quiet "https://raw.githubusercontent.com/deponian/scripts/main/necessary-packages.sh" \
			--output-document necessary-packages
		chmod +x necessary-packages
		sudo ./necessary-packages "${mode}"
	)
	rm -rf "${tmpdir}"
	cecho green "[Done]"
}

# copy dotfiles
copy_dotfiles () {
	cecho blue "[Copying dotfiles]"
	cp -r "$(dirname "${0}")"/dotfiles/.[^.]* "${HOME}"
	cecho green "[Done]"
}

# setup vim and neovim config
setup_vim () {
	local mode

	mode="${1:?"You have to specify mode as first parameter"}"
	cecho blue "[Setting up vim and neovim]"
	if [[ "${mode}" == minimal ]]; then
		# only vim with light config
		[[ -d "${HOME}/.vim" ]] && cecho purple "${HOME}/.vim already exists, skipping..." && return
		git clone -b light "https://github.com/deponian/vim.config" "${HOME}/.vim"
		echo
	elif [[ "${mode}" == full ]]; then
		# neovim with full config
		[[ -d "${HOME}/.config/nvim" ]] && cecho purple "${HOME}/.config/nvim already exists, skipping..." && return
		mkdir -p "${HOME}/.config/nvim"
		git clone "https://github.com/deponian/vim.config" "${HOME}/.config/nvim"
	else
		echo "You have to specify mode as first parameter for setup_vim()."
		exit 1
	fi
	cecho green "[Done]"
}

# setup zsh
setup_zsh () {
	local tmpdir

	cecho blue "[Setting up zsh]"

	[[ -d "${HOME}/.zim" ]] && cecho purple "${HOME}/.zim already exists, skipping..." && return

	tmpdir="/tmp/${RANDOM}"
	mkdir -p "${tmpdir}"
	(
		cd "${tmpdir}"
		wget --quiet "https://raw.githubusercontent.com/deponian/zsh.config/main/install.sh" \
			--output-document install.sh
		chmod +x install.sh

		./install.sh nochsh
	)
	rm -rf "${tmpdir}"
	cecho green "[Done]"
}

# create symlinks in root home directory
# and change default shell
setup_root () {
	cecho blue "[Setting up root user]"
	user_home="$(getent passwd "$(whoami)" | cut -f6 -d:)"
	root_home="$(getent passwd root | cut -f6 -d:)"

	echo "::: Setting up vim and neovim "
	sudo mkdir -p "${root_home}/.config"
	sudo ln -fsn "${user_home}/.config/nvim" "${root_home}/.config/nvim"

	echo "::: Setting up tmux"
	sudo ln -fsn "${user_home}/.tmux.conf" "${root_home}/.tmux.conf"

	echo "::: Setting up zsh"
	sudo bash -c "$(declare -f setup_zsh; declare -f cecho); setup_zsh"
	echo green "[Done]"
}

main () {
	local mode

	mode="${1:-}"
	while true; do
		if [[ "${mode}" =~ ^(minimal|server|desktop|dotfiles)$ ]]; then
			break
		else
			cat <<- EOF
			::: Choose an installation mode
			::: There are four of them: minimal, server, desktop and dotfiles
			::: First three copy dotfiles and zsh config, but they differ in details
			::: The last one installs only one component
			::: * minimal - minimal set of packages, no statically-linked utils from github and very light vim config
			::: * server - standard set of packages, all statically-linked utils form github, full config for vim and neovim
			::: * desktop - like standard plus gui-related packages and other stuff (like fonts)
			::: * dotfiles - only dotfiles
			EOF

			read -r -p 'Choose packages mode from the list above: ' mode
		fi
	done

	root_option="${2:-}"
	while true; do
		if [[ "${root_option}" =~ ^(root|noroot)$ ]]; then
			break
		else
			cat <<- EOF
			::: Do you want to set up root home directory
			::: There are two options: root and noroot
			::: * root - set up root home directory
			::: * noroot - don't touch any root files
			::: If you run this script as root then "root" option is applied in any case
			EOF

			read -r -p 'Choose "root" or "noroot": ' root_option
		fi
	done

	case "${mode}" in
		minimal)
			check_software git wget zsh sudo
			copy_dotfiles
			setup_zsh
			install_packages minimal
			setup_vim minimal
			;;
		server)
			check_software git wget zsh sudo
			copy_dotfiles
			setup_zsh
			install_packages server
			setup_vim full
			;;
		desktop)
			check_software git wget zsh sudo
			copy_dotfiles
			setup_zsh
			install_packages desktop
			setup_vim full
			;;
		dotfiles)
			check_software git wget zsh
			copy_dotfiles
			setup_zsh
			setup_vim full
			;;
		*)
			echo "Wrong mode."
			exit 1
			;;
	esac

	# setup root home directory
	# don't run setup_root if this script is already running by root
	if [[ "${root_option}" == "root" && "$(id -u)" != 0 ]]; then
		setup_root
	fi

	chsh_option="${3:-"chsh"}"
	if [[ "${chsh_option}" != "nochsh" ]]; then
		until chsh -s /usr/bin/zsh; do
			echo "Wrong password."
		done
	fi

	cecho cyan "::::::: Now you can feel like you are home. :::::::"
}

main "$@"
