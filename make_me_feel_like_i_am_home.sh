#!/usr/bin/env bash
set -euo pipefail
shopt -s extglob nullglob
IFS=$'\n\t'

# colored echo
function cecho {
	case "${1}" in
		red   ) echo -e "\e[91m${2}\e[39m";;
		green ) echo -e "\e[92m${2}\e[39m";;
		blue  ) echo -e "\e[94m${2}\e[39m";;
		cyan  ) echo -e "\e[96m${2}\e[39m";;
	esac
}

# check if system has necessary software
check_software () {
	for program in "$@"
	do
		command -v "${program}" >/dev/null 2>&1 || \
		{
			echo >&2 "This script needs ${program}. Aborting."
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
		wget --quiet "https://raw.githubusercontent.com/deponian/scripts/master/necessary-packages.sh" \
			--output-document necessary-packages
		chmod +x necessary-packages
		sudo ./necessary-packages "${mode}"
	)
	rm -rf "${tmpdir}"
	cecho green "[Done]"
}

# install programs which you rarely can find in distro repos
# they are all one-binary programs, so you don't need any dependencies
install_utils () {
	local install_path tmpdir

	install_path="${1:-/usr/local/bin}"
	cecho blue "[Installing utils]"
	tmpdir="/tmp/${RANDOM}"
	mkdir -p "${tmpdir}"
	(
		cd "${tmpdir}"
		wget --quiet "https://raw.githubusercontent.com/deponian/scripts/master/necessary-utils.sh" \
			--output-document necessary-utils
		chmod +x necessary-utils
		sudo ./necessary-utils "${install_path}"
	)
	rm -rf "${tmpdir}"
	cecho green "[Done]"
}

# copy dotfiles
copy_dotfiles () {
	cecho blue "[Copying dotfiles]"
	for dotfile in ./.*; do
		if [[ -f "${dotfile}" ]]; then
			echo "::: Copying ${dotfile}"
			cp "${dotfile}" "${HOME}"
		fi
	done
	cecho green "[Done]"
}

# copy fonts
copy_fonts () {
	cecho blue "[Copying fonts]"
	mkdir -p "${HOME}/.local/share/fonts"
	cp Inconsolata-SemiBold.otf "${HOME}/.local/share/fonts"
	cecho green "[Done]"
}

# setup vim and neovim config
setup_vim () {
	local mode

	mode="${1:?"You have to specify mode as first parametr"}"
	cecho blue "[Setting up vim and neovim]"
	if [[ "${mode}" == minimal ]]; then
		# only vim wiht light config
		[[ -d "${HOME}/.vim" ]] && mv -n "${HOME}/.vim" "${HOME}/.vim.old" && rm -rf "${HOME}/.vim"
		git clone -b light "https://github.com/deponian/vim.config" "${HOME}/.vim"
		echo
	elif [[ "${mode}" == full ]]; then
		# vim and neovim with full config
		[[ -d "${HOME}/.vim" ]] && mv -n "${HOME}/.vim" "${HOME}/.vim.old" && rm -rf "${HOME}/.vim"
		[[ -d "${HOME}/.config/nvim" ]] && mv -n "${HOME}/.config/nvim" "${HOME}/.config/nvim.old" && rm -rf "${HOME}/.config/nvim"
		git clone "https://github.com/deponian/vim.config" "${HOME}/.vim"
		mkdir -p "${HOME}/.config"
		ln -fsn "${HOME}/.vim" "${HOME}/.config/nvim"
	else
		echo "You have to specify mode as first parametr for setup_vim(). Modes are minimal and full."
		exit 1
	fi
	cecho green "[Done]"
}

# setup zsh
setup_zsh () {
	local zsh_files tmpdir

	cecho blue "[Setting up zsh]"
	# make backup if previous installation exists
	zsh_files=("${HOME}"/.z*)
	if [[ "${#zsh_files[@]}" != 0 && ! -d "${HOME}/.old.zsh" ]]; then
		mkdir "${HOME}/.old.zsh"
		cp -r "${zsh_files[@]}" "${HOME}/.old.zsh"
	fi

	tmpdir="/tmp/${RANDOM}"
	mkdir -p "${tmpdir}"
	(
		cd "${tmpdir}"
		wget --quiet "https://raw.githubusercontent.com/deponian/zsh.config/master/install.sh" \
			--output-document install.sh
		chmod +x install.sh

		./install.sh
	)
	rm -rf "${tmpdir}"
	cecho green "[Done]"
}

# create symlinks in root home directory
# and change default shell
setup_root () {
	cecho red "[Setting up root user]"
	user_home="$(getent passwd "$(whoami)" | cut -f6 -d:)"
	root_home="$(getent passwd root | cut -f6 -d:)"

	echo "::: Setting up vim and neovim "
	sudo mkdir -p "${root_home}/.config"
	sudo ln -fsn "${user_home}/.vim" "${root_home}/.vim"
	sudo ln -fsn "${user_home}/.vim" "${root_home}/.config/nvim"

	echo "::: Setting up tmux"
	sudo ln -fsn "${user_home}/.tmux.conf" "${root_home}/.tmux.conf"

	echo "::: Setting up zsh"
	sudo chsh -s /usr/bin/zsh
	sudo ln -fsn "${user_home}/.zprezto" "${root_home}/.zprezto"
	sudo ln -fsn "${user_home}/.zprezto/runcoms/zlogin" "${root_home}/.zlogin"
	sudo ln -fsn "${user_home}/.zprezto/runcoms/zlogout" "${root_home}/.zlogout"
	sudo ln -fsn "${user_home}/.zprezto/runcoms/zpreztorc" "${root_home}/.zpreztorc"
	sudo ln -fsn "${user_home}/.zprezto/runcoms/zprofile" "${root_home}/.zprofile"
	sudo ln -fsn "${user_home}/.zprezto/runcoms/zshenv" "${root_home}/.zshenv"
	sudo ln -fsn "${user_home}/.zprezto/runcoms/zshrc" "${root_home}/.zshrc"
	cecho green "[Done]"
}

main () {
	local mode

	# check we have everything we need
	check_software git wget zsh chsh sudo

	cat <<- EOF
	::: You have to specify installation mode.
	::: There are three of them: minimal, server and desktop.
	::: All of them copy dotfiles and zsh config, but they differ in the following:
	::: * minimal - minimal set of packages, no statically-linked utils from github and very light vim config.
	::: * server - standard set of packages, all statically-linked utils form github, full config for vim and neovim.
	::: * desktop - like standard plus gui-related packages and other stuff (like fonts)
	EOF

	mode="${1:-}"
	while true; do
		if [[ "${mode}" =~ ^(minimal|server|desktop)$ ]]; then
			break
		else
			read -r -p 'Incorrect mode. Choose packages mode from "minimal", "server" and "desktop": ' mode
		fi
	done

	cat <<- EOF
	::: You have to choose if you want to setup root directory configuration or not.
	::: There are two options: root and noroot.
	::: * root - create symlinks in root home directory to files in your user home directory
	::: * noroot - don't create symlinks in root home directory
	::: If you run this script as root then "noroot" option is applied in any case.
	EOF

	root_option="${2:-}"
	while true; do
		if [[ "${root_option}" =~ ^(root|noroot)$ ]]; then
			break
		else
			read -r -p 'Incorrect option. Choose "root" or "noroot": ' root_option
		fi
	done

	# these actions are the same for all modes.
	copy_dotfiles
	setup_zsh

	case "${mode}" in
		minimal)
			install_packages minimal
			setup_vim minimal
			;;
		server)
			install_packages server
			install_utils /usr/local/bin
			setup_vim full
			;;
		desktop)
			install_packages desktop
			install_utils /usr/local/bin
			setup_vim full
			copy_fonts
			;;
		*)
			echo "Wrong mode."
			exit 1
			;;
	esac

	# create symlinks in root home directory to installed configuration
	# if root doesn't run this script
	if [[ "${root_option}" == "root" && "$(id -u)" != 0 ]]; then
		setup_root
	fi

	cecho cyan "::::::: Now you can feel like you are home. :::::::"
}

main "$@"
