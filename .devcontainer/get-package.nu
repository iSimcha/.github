#!/usr/bin/env nu

# Pulled from https://github.com/NiceGuyIT/justfiles/blob/main/packages/get-package.nu
use std log
$env.NU_LOG_LEVEL = DEBUG

# get-github-assets will download the latest GitHub release JSON and return the assets as a record.
def get-github-assets [repo: string]: nothing -> table<record> {
	# TODO: Use this to skip the download and prevent hitting GitHub's rate limit.
	#open $"github-fzf.json"
	http get $"https://api.github.com/repos/($repo)/releases/latest"
		| get assets
		| select browser_download_url name content_type size
}

# download-github-assets downloads the GitHub asset and returns a list of files.
def download-github-asset [
	--dest-dir (-d): string,		# Destination directory to save the files
	--remote-name (-f): string,		# Name of the remote file to save locally
	--decompress (-u): bool,		# If true, decompress (uncompress) the files
]: string -> list {
	let url: string = $in
	mut url_name = ($url | url-filename)
	if not ($remote_name | is-empty) {
		$url_name = $remote_name
	}
	let save_file: string = ($dest_dir | path join $url_name)
	log debug $"dest_dir: ($dest_dir)"
	log debug $"url_name: ($url_name)"
	log debug $"save_file: ($save_file)"
	# mkdir doesn't care if the directory exists
	mkdir $dest_dir
	http get $url | save $save_file
	if (not ($decompress | is-empty)) and $decompress {
		# ouch decompresses into exactly one directory EXCEPT if there is only 1 file.
		ouch --yes --quiet --accessible decompress --dir $dest_dir $save_file
		if (ls $dest_dir | where type == dir | length) == 0 {
			# Only 1 file was extracted.
			return (ls $dest_dir | where type == file and name != $save_file | each {|it| ([ $dest_dir $it.name ] | path join)})
		} else {
			let asset_dir = (ls $dest_dir | where type == dir).name.0
			return (ls $asset_dir | where size > 1mb | each {|it| ([ $dest_dir $asset_dir $it.name ] | path join)})
		}
	} else {
		return (ls $save_file | each {|it| ([ $dest_dir $it.name ] | path join)})
	}
}

# install-binaries will install the files into bin_dir
def install-binaries [bin_dir: string, files: list<string>]: nothing -> nothing {
	if ($bin_dir | is-empty) or ($bin_dir | str length) == 0 {
		log error $"bin_dir is not defined: '($bin_dir)'"
		return null
	}
	$files | each {|it|
		let filename: string = ($it | path basename)
		log info $"installing '($it)' to '($bin_dir)'"
		cp $it $bin_dir
		if $nu.os-info.name != "windows" {
			^chmod a+rx ([$bin_dir, $filename] | path join)
		}
	}
	return null
}

# get-bin-dir will get the bin directory to install the binaries.
def get-bin-dir []: string -> string {
	mut bin_dir = ""
	if $nu.os-info.name == "windows" {
		$bin_dir = ""
	} else {
		# *nix (Linux, macOS, BSD)
		if $env.USER == "root" {
			$bin_dir = "/usr/local/bin"
		} else {
			$bin_dir = $"($env.HOME)/.local/bin"
			if not ($bin_dir | path exists) {
				mkdir $bin_dir
			}
		}
	}
	return $bin_dir
}

# file-basename will return the basename of the filename.
def file-basename []: string -> string {
	split column '.' | get column1.0
}

# file-extension will return the extension of the filename.
def file-extension []: string -> string {
	str replace --regex '^[^\.]+\.' ''
}

# url-filename will extract the filename from the URL.
def url-filename []: string -> string {
	(url parse).path | path basename
}

# filter-os will filter out binaries that do not match the current OS
def filter-os []: table<record> -> table<record> {
	let input: table = $in
	# Map the OS to possible OS values in the release names. This is mainly for Apple.
	# os_map: record<linux: list<string>, darwin: list<string>, windows: list<string>>
	let os_map = {
		linux: [
			linux,
			# micro uses "linux64" as the os and arch combined.
			# https://github.com/zyedidia/micro/releases
			#linux64,
		],
		macos: [
			darwin,
			apple,
		],
		windows: [
			windows,
		],
	}
	let os_list = ($os_map | get ($nu.os-info.name))
	# FIXME: $in throws "Input type not supported."
	$input | where ($os_list | any {|os| $it.name =~ $os })
}

# filter-arch will filter out binaries that do not match the current archtecture
def filter-arch []: table<record> -> table<record> {
	let input: table = $in
	# Map the architecture to possible ARCH values in the release names.
	# arch_map: record<x86_64: list<string>, aarch64: list<string>, arm64: list<string>>
	let arch_map = {
		x86_64: [
			x86_64,
			amd64,
		],
		aarch64: [
			arm64,
		],
		arm64: [
			arm64,
		],
	}
	let arch_list = ($arch_map | get ($nu.os-info.arch))
	# FIXME: $in throws "Input type not supported."
	$input | where ($arch_list | any {|arch| $it.name =~ $arch })
}

# filter-content-type will filter out non-binary content types.
def filter-content-type []: table<record> -> table<record> {
	let input: table = $in
	# List of acceptable Content-Type values.
	let content_type_list: list<string> = [
		"application/octet-stream",
		"application/zip",
		"application/x-gtar",
		"application/x-xz",
		"application/gzip",
	]
	$input | where ($content_type_list | any {|ct| $it.content_type == $ct})
}

# filter-extension will filter out non-binary filenames such as .deb, .rpm, .sha256, .sha512, etc. by selecting only
# valid extensions.
def filter-extension []: table<record> -> table<record> {
	let input: table = $in
	# List of acceptable extensions
	let extension_list: list<string> = [
		"tar.gz",
		"tar.xz",
		"zip",
	]
	let filtered: table = (
		$input | where ($extension_list | any {|ext| $it.name | str ends-with $ext})
	)
	return $filtered
}

# has-flavor will return true if any of the assets have different flavor binaries.
def has-flavor []: table<record> -> bool {
	let input: table = $in
	let flavor_list = [
		"musl",
		"gnu"
	]
	let filtered: table = (
		$input | where ($flavor_list | any {|f| $it.name =~ $"\\b($f)\\b" })
	)
	return (not ($filtered | length) == 0)
}

# filter-flavor will filter records based on the binary flavor (musl, gnu, etc.) or the given name.
def filter-flavor [flavor: string = "musl"]: table<record> -> table<record> {
	let input: table = $in
	let filtered: table = (
		$input | where $it.name =~ $"\\b($flavor)\\b"
	)

	if ($filtered | length) == 0 {
		log error "Filtering by flavor resulted in 0 assets"
		print ($filtered)
		return $filtered
	} else if ($filtered | length) == 1 {
		return $filtered
	} else {
		log error "Filtering by flavor resulted in more than 1 asset"
		print ($filtered)
		return $filtered
	}
}

# download-compressed will filter the assets, download, decompress and install it.
def dl-compressed [
	--name (-n): string		# Binary name to install. Default: "repo" in "owner/repo"
	--filter (-f): string	# Filter the results if a single release can't be determined
]: table<record> -> table<record> {
	mut input: table<record: any> = $in

	if ($input | length) > 1 {
		# Compressed assets need to be filtered by extension.
		let filtered: table<record: any> = ($input | filter-extension)
		match ($filtered | length) {
			0 => {
				log error $"Filtering by extension resulted in 0 assets"
				return $filtered
			}
			1 => {
				log info $"Filtering by extension resulted in 1 asset"
				# No additional filtering needed
				$input = $filtered
			}
			_ => {
				log error $"Filtering by extension resulted in 2 or more assets"
				return $filtered
			}
		}
	}

	# $input has exactly 1 record
	let tmp_dir: string = ({ parent: $nu.temp-path, stem: $"package-(random uuid)" } | path join)
	mkdir $tmp_dir
	let files = ($input.browser_download_url.0
		| download-github-asset --dest-dir $tmp_dir --decompress true)
	log info $"Files: ($files)"

	let bin_dir = get-bin-dir
	log debug $"bin_dir: ($bin_dir)"
	install-binaries $bin_dir $files
	rm -r $tmp_dir

	return $input
}

# download-uncompressed will download the uncompressed file and install it.
def dl-uncompressed [
	--name (-n): string		# Binary name to install. Default: "repo" in "owner/repo"
	--filter (-f): string	# Filter the results if a single release can't be determined
]: table<record> -> table<record> {
	let input: table = $in

	if ($input | length) > 1 {
		log error $"Uncompressed assets has 2 or more assets"
		return $input
	}

	# $input has exactly 1 record
	let tmp_dir: string = ({ parent: $nu.temp-path, stem: $"package-(random uuid)" } | path join)
	log debug $"name: ($name)"
	let files = ($input.browser_download_url.0
		| download-github-asset --dest-dir $tmp_dir --remote-name $name --decompress false)
	log info $"Files: ($files)"

	let bin_dir = get-bin-dir
	log debug $"bin_dir: ($bin_dir)"
	install-binaries $bin_dir $files
	rm -r $tmp_dir

	return $input
}

# dl-gh will return the download URL for the given repo.
def dl-gh [
	repo: string			# GitHub repo name in owner/repo format
	--name (-n): string		# Binary name to install. Default: "repo" in "owner/repo"
	--filter (-f): string	# Filter the results if a single release can't be determined
]: nothing -> string {
	mut assets: table<record: any> = (get-github-assets $repo
		| filter-content-type
		| filter-os
		| filter-arch
	)
	#print ($assets)
	if ($assets | length) == 0 {
		log error $"Filtering by content type, OS and architecture resulted in 0 assets"
		return $assets
	}

	# Check if the asset names use flavors, i.e. musl, gnu, etc., and filter them
	mut flavor: table<record: any> = $assets
	if ($assets | has-flavor) {
		$flavor = ($assets | filter-flavor)
	}
	if ($flavor | length) == 0 {
		log error "Filtering on flavor resulted in 0 assets. Resetting to previous asset list"
		$flavor = $assets
	}
	$assets = $flavor
	print ($assets)

	mut bin_name: string = ($repo | split column '/' | get column2.0)
	if (not ($name | is-empty)) and ($name | str length) > 0 {
		$bin_name = $name
	}

	# The content_type uniqueness determines if the assets are compressed. If all of them are
	# "application/octet-stream", the assets are uncompressed.
	let ct_count = $assets | get content_type | uniq --count
	print ($ct_count)
	if ($ct_count | length) == 1 and ($ct_count.value.0 == "application/octet-stream") {
		log info "Uncompressed assets"
		let results = ($assets | dl-uncompressed --name $bin_name --filter $filter)
		#print ($results)
		return $results
	} else {
		log info "Compressed assets"
		# Compressed assets need to be filtered by extension.
		let results = ($assets | dl-compressed --name $bin_name --filter $filter)
		#print ($results)
		return $results
	}
	return
}

def main [
	repo: string			# GitHub repo name in owner/repo format
	--name (-n): string		# Binary name to install. Default: "repo" in "owner/repo"
	--filter (-f): string	# Filter the results if a single release can't be determined
]: nothing -> nothing {
	# Separator for REPL
	print "=============================="
	if not ($name | is-empty) {
		print $"Name: ($name)"
	}
	if not ($filter | is-empty) {
		print $"Filter: ($filter)"
	}
	print (dl-gh --name $name --filter $filter $repo)
}

# List of packages that do not work:
# alacritty/alacritty - https://github.com/alacritty/alacritty/blob/master/INSTALL.md#opensuse
#   Alacritty does not provide binaries for Linux
# zyedidia/micro - https://github.com/zyedidia/micro/releases
#   Micro mixes OS and ARCH in the release name, making detection of the real release very hard.
