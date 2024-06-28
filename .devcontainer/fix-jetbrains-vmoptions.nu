#!/usr/bin/env nu

let xms = 4096
let xmx = 4096
let jetbrains_path = "/workspaces/.codespaces/shared/editors/jetbrains"
let vmoptions_glob = "/workspaces/.codespaces/shared/editors/jetbrains/**/bin/*.vmoptions"

# Given a path, get a list of vmoptions as a record.
def get-file-contents ($path_glob: string): nothing -> record {
	mut rec = {}
	for path in (glob $path_glob) {
		let contents = open $path
		$rec = ($rec | merge {$path:$contents})
	}
	return $rec
}

# Modify the Xms and Xmx options in the VMoptions.
def modify-vmoptions (
	$xms: number,	# Xms option in the vmoptions, in (m)egabytes
	$xmx: number,	# Xmx option in the vmoptions, in (m)egabytes
): record -> record {
	let input = ($in | transpose path contents)
	mut rec = {}

	for vmoptions in $input {
		let contents = $vmoptions.contents
			| lines
			| str replace --regex '^-Xms[0-9]+m' $"-Xms($xms)m"
			| str replace --regex '^-Xmx[0-9]+m' $"-Xmx($xmx)m"
			| to text
		$rec = ($rec | merge {$vmoptions.path:$contents})
	}
	return $rec
}

# Snapshot the current version to be used when fixing. It seems only the first two lines are saved, not all lines.
let contents = (get-file-contents $vmoptions_glob)
let fixed_contents = ($contents | modify-vmoptions $xms $xmx)
#print $"Printing fixed contents"
#print $fixed_contents

watch $jetbrains_path --glob=**/*.vmoptions --debounce-ms 1000 {|op, path, new_path|
	print $"\nOperation ($op): Changed path: ($path)"

	# This closure is executed after the debounce delay.
	# Debounce cannot be used to debounce changes in the watch closure.
	# Check if the Xms/Xmx options need to change.
	# xm_check will be true if either value is correct.
	let xm_check = (open $path | lines | where {|it|
	    ($it | str contains $"Xms($xms)") or ($it | str contains $"Xmx($xmx)")
	})
	if ($xm_check | length) == 0 {
		# Both values are incorrect.
		let modified = (ls -la $path | get modified.0)
		print $"Last modified: ($modified)"
		$fixed_contents | get $path | save --force $path
		print $"Fixed contents of ($path)"
	}
}

# Here's the initial contents of pycharm64.vmoptions
# /workspaces/.codespaces/shared/editors/jetbrains/pycharm-2023.1.1/bin/pycharm64.vmoptions
# -Xms128m
# -Xmx750m
# -XX:ReservedCodeCacheSize=512m
# -XX:+UseG1GC
# -XX:SoftRefLRUPolicyMSPerMB=50
# -XX:CICompilerCount=2
# -XX:+HeapDumpOnOutOfMemoryError
# -XX:-OmitStackTraceInFastThrow
# -XX:+IgnoreUnrecognizedVMOptions
# -XX:CompileCommand=exclude,com/intellij/openapi/vfs/impl/FilePartNodeRoot,trieDescend
# -ea
# -Dsun.io.useCanonCaches=false
# -Dsun.java2d.metal=true
# -Djbr.catch.SIGABRT=true
# -Djdk.http.auth.tunneling.disabledSchemes=""
# -Djdk.attach.allowAttachSelf=true
# -Djdk.module.illegalAccess.silent=true
# -Dkotlinx.coroutines.debug=off
# -Dsun.tools.attach.tmp.only=true
