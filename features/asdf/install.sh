#!/bin/bash -i
# This is part of devcontainers-contrib script library
# source: https://github.com/devcontainers-contrib/features
set -ex

OS_NAME=$(grep -m 1 "^ID_LIKE=\|^ID=" /etc/os-release | awk -F= '{print tolower($2)}') 
PLUGIN=${PLUGIN:-""}
VERSION=${VERSION:-"latest"}
DIRENV_VERSION="latest"
CUSTOM_PLUGIN_REPO=${CUSTOM_PLUGIN_REPO:-""}
LATEST_VERSION_PATTERN=${LATEST_VERSION_PATTERN:-""}
USER=$(id -u "${_REMOTE_USER:-"root"}")
HOME_DIR=${_REMOTE_HOME_DIR:-"${HOME}"}
ASDF_DIR="${HOME_DIR}/.asdf"
ASDF_SCRIPT="$ASDF_DIR/asdf.sh"
# Clean up
rm -rf /var/lib/apt/lists/*

if [[ "$(id -u)" != "${USER}" ]]; then
	su -c "${0}" - "${USER}"
	exit 1
fi


check_alpine_packages() {
    apk add -v --no-cache "$@"
}


check_packages() {
	if [[ "${OS_NAME}" = *"alpine"* ]]; then
		apk add -v --no-cache "$@"
	elif ! dpkg -s "$@" >/dev/null 2>&1; then
		if [[ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]]; then
			echo "Running apt-get update..."
			apt-get update -y
		fi
		apt-get -y install --no-install-recommends "$@"
	fi
}


_asdf() {
	$ASDF_DIR/bin/asdf "$@"
}
_asdf_add_text_if_not_exists() {
	local file="$1"
	local text="$2"
	if [[ $(cat "${file}" || true) != *"${text}"* ]]; then
		echo "Updating ${file}"
		echo -e "${text}" >>"${file}"
	fi
}

_asdf_load() {
	". ${ASDF_SCRIPT}"
}

_asdf_init_rc() {
	declare -A shells

	shells[zsh]="/etc/zsh/zshrc"
	shells[bash]="/etc/bash.bashrc"

	if [[ "${OS_NAME}" = *"alpine"* ]]; then
		_asdf_add_text_if_not_exists "/etc/profile" ". ${ASDF_SCRIPT}"
	fi
	
	for shell_name in "${!shells[@]}"; do
		if ! command -v "${shell_name}"; then
			continue
		fi

		shell_rc="${shells[${shell_name}]}"

		_asdf_add_text_if_not_exists "${shell_rc}" ". ${ASDF_SCRIPT}"
	done
}

asdf_get_plugin_version() {
	if [[ "${2}" == "latest" ]]; then
		_asdf latest "${1}" "${LATEST_VERSION_PATTERN}"
	else
		echo "${2}"
	fi
}

_asdf_is_installed() {
	[[ -f "${ASDF_DIR}" ]] && command -v asdf >/dev/null 2>&1
}

asdf_install() {
	rm -rf $ASDF_DIR
	git clone --depth=1 \
			-c core.eol=lf \
			-c core.autocrlf=false \
			-c fsck.zeroPaddedFilemode=ignore \
			-c fetch.fsck.zeroPaddedFilemode=ignore \
			-c receive.fsck.zeroPaddedFilemode=ignore \
			"https://github.com/asdf-vm/asdf.git" --branch v0.12.0 $ASDF_DIR 2>&1

	_asdf_init_rc
	
	_asdf_load

	_asdf_is_installed || {
		echo "Install fail"
		exit 1
	}
}

_asdf_direnv_is_installed() {
	_asdf list direnv >/dev/null 2>&1;
}

asdf_direnv_install() {
	version=$(asdf_get_plugin_version direnv latest)

	_asdf install direnv "${version}"
	_asdf global direnv "${version}"
	_asdf direnv setup --version "${version}"
}

if ! asdf_is_installed; then
	asdf_install
fi

if ! _asdf_direnv_is_installed; then
	asdf_direnv_install
fi

# install_via_asdf "$PLUGIN" "$VERSION" "$CUSTOM_PLUGIN_REPO"