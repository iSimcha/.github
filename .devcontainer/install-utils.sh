#!/usr/bin/env bash

# Nushell is a new type of shell that can handle http and json natively.
# https://github.com/nushell/nushell
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
version="0.88.1"
repo="https://github.com/nushell/nushell/releases/download/${version}/nu-${version}-${arch}-${os}-musl-full.tar.gz"
tmp_dir=$(mktemp --directory)
curl --silent --location --output - "${repo}" | tar --strip-components 1 --directory="${tmp_dir}" --extract --gzip --file -
chmod a+rx "${tmp_dir}/nu"
sudo cp "${tmp_dir}/nu" /usr/local/bin/nu
sudo cp ${tmp_dir}/nu_plugin_* /usr/local/bin/
rm -r "${tmp_dir}"

# ouch is a utility to decompress files without knowing the compression format.
# https://github.com/ouch-org/ouch
# https://github.com/ouch-org/ouch/releases/download/0.5.1/ouch-x86_64-unknown-linux-musl.tar.gz
os=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
version="0.5.1"
repo="https://github.com/ouch-org/ouch/releases/download/${version}/ouch-${arch}-unknown-${os}-musl.tar.gz"
tmp_dir=$(mktemp --directory)
curl --silent --location --output - "${repo}" | tar --strip-components 1 --directory="${tmp_dir}" --extract --gzip --file -
chmod a+rx "${tmp_dir}/ouch"
sudo cp "${tmp_dir}/ouch" /usr/local/bin/ouch
rm -r "${tmp_dir}"

cd .devcontainer || ( echo "Could not cd to .devcontainer" && exit )

# Task is a general purpose cross-platform task runner.
# https://github.com/go-task/task
nu get-package.nu go-task/task

# Just is a just a command runner, similar to Task.
# https://github.com/casey/just
nu get-package.nu casey/just

# yq is an alternative to jq.
# https://github.com/mikefarah/yq
nu get-package.nu mikefarah/yq

# fd is a program to find entries in your filesystem.
# https://github.com/sharkdp/fd
nu get-package.nu sharkdp/fd

# ripgrep recursively searches directories for a regex pattern.
# https://github.com/BurntSushi/ripgrep
nu get-package.nu BurntSushi/ripgrep

# watchexec executes commands in response to file modifications
# https://github.com/watchexec/watchexec
nu get-package.nu watchexec/watchexec

# caddy is a web server.
# https://github.com/caddyserver/caddy
nu get-package.nu caddyserver/caddy
