# shellcheck shell=bats

load "${MAIN_BASH_IT_DIR?}/test/test_helper.bash"

function local_setup_file() {
	setup_libs "helpers"
	# Load something, anything...
	load ../../completion/available/capistrano.completion
}

@test "alias-completion: See that aliases with double quotes and brackets do not break the plugin" {
	alias gtest="git log --graph --pretty=format:'%C(bold)%h%Creset%C(magenta)%d%Creset %s %C(yellow)<%an> %C(cyan)(%cr)%Creset' --abbrev-commit --date=relative"
	run load "${BASH_IT?}/completion/available/aliases.completion.bash"

	assert_success
}

@test "alias-completion: See that aliases with single quotes and brackets do not break the plugin" {
	alias gtest='git log --graph --pretty=format:"%C(bold)%h%Creset%C(magenta)%d%Creset %s %C(yellow)<%an> %C(cyan)(%cr)%Creset" --abbrev-commit --date=relative'
	run load "${BASH_IT?}/completion/available/aliases.completion.bash"

	assert_success
}

@test "alias-completion: See that having aliased rm command does not output unnecessary output" {
	alias rm='rm -v'
	run load "${BASH_IT?}/completion/available/aliases.completion.bash"

	assert_output ""
}

# A -D handler that performs completion instead of loading it (like
# argcomplete's global hook) must never be called at load time.
@test "alias-completion: does not call a non-loader default (-D) completion handler" {
	function _bats_fake_global_hook() {
		echo "$1" >> "${BATS_TEST_TMPDIR?}/hook-called"
		return 124
	}
	complete -D -F _bats_fake_global_hook
	alias bats-fake-alias='bats-fake-command-without-completion --flag'
	run load "${BASH_IT?}/completion/available/aliases.completion.bash"

	assert_success
	assert_file_not_exist "${BATS_TEST_TMPDIR?}/hook-called"
}

@test "alias-completion: falls back to bash-completion's loader when -D holds something else" {
	function _bats_fake_global_hook() {
		echo "$1" >> "${BATS_TEST_TMPDIR?}/hook-called"
		return 124
	}
	function _comp_complete_load() {
		echo "$1" >> "${BATS_TEST_TMPDIR?}/loader-called"
		return 1
	}
	complete -D -F _bats_fake_global_hook
	alias bats-fake-alias='bats-fake-command-without-completion --flag'
	run load "${BASH_IT?}/completion/available/aliases.completion.bash"

	assert_success
	assert_file_not_exist "${BATS_TEST_TMPDIR?}/hook-called"
	assert_file_contains "${BATS_TEST_TMPDIR?}/loader-called" '^bats-fake-command-without-completion$'
}

@test "alias-completion: still calls bash-completion's loader when it is the -D handler" {
	function _comp_complete_load() {
		echo "$1" >> "${BATS_TEST_TMPDIR?}/loader-called"
		return 1
	}
	complete -D -F _comp_complete_load
	alias bats-fake-alias='bats-fake-command-without-completion --flag'
	run load "${BASH_IT?}/completion/available/aliases.completion.bash"

	assert_success
	assert_file_contains "${BATS_TEST_TMPDIR?}/loader-called" '^bats-fake-command-without-completion$'
}

@test "alias-completion: wrapper passes the last alias word as the preceding word" {
	function _alias_test_complete() {
		printf '%s\n' "cmd=$1" "cur=$2" "prev=$3" "line=$COMP_LINE" "words=${COMP_WORDS[*]}" "cword=$COMP_CWORD"
	}
	function atest_cmd() { :; }
	complete -F _alias_test_complete atest_cmd
	alias atest="atest_cmd config use-context"
	# The init callback ends a 'read -d ""' at EOF (status 1); bash 3.2 propagates
	# that through bats' errexit, so load without it and check the result below.
	set +e
	load "${BASH_IT?}/completion/available/aliases.completion.bash"
	set -e
	declare -F _alias_completion::atest

	COMP_LINE="atest mi"
	COMP_POINT=${#COMP_LINE}
	# shellcheck disable=SC2030 # each test sets its own COMP_WORDS
	COMP_WORDS=(atest mi)
	COMP_CWORD=1
	run _alias_completion::atest atest mi atest

	assert_success
	assert_line "cmd=atest_cmd"
	assert_line "cur=mi"
	assert_line "prev=use-context"
	assert_line "line=atest_cmd config use-context mi"
	assert_line "words=atest_cmd config use-context mi"
	assert_line "cword=3"
}

# Regression test for #2254: a `'` in an alias definition used to produce an
# unsourceable wrapper function, aborting the whole completion load.
@test "alias-completion: alias containing a single quote gets a working wrapper" {
	# shellcheck disable=SC2031 # reads the COMP_WORDS this test sets below, not the other test's
	function _probe_complete() { printf '%s\n' "${COMP_WORDS[@]}" > "${BATS_TEST_TMPDIR?}/words"; }
	complete -F _probe_complete probecmd
	alias quoted="probecmd --msg=it's"
	alias plain="probecmd --verbose"

	# The init callback ends a 'read -d ""' at EOF (status 1); see the test above.
	set +e
	load "${BASH_IT?}/completion/available/aliases.completion.bash"
	set -e

	# The quoted alias must not take the unquoted one down with it.
	run complete -p plain quoted
	assert_success
	assert_line "complete -F _alias_completion::plain plain"
	assert_line "complete -F _alias_completion::quoted quoted"

	# The wrapper must be callable and forward the expanded command to the original completion.
	COMP_WORDS=(quoted arg) COMP_CWORD=1 COMP_LINE="quoted arg" COMP_POINT=3
	_alias_completion::quoted quoted arg quoted
	run cat "${BATS_TEST_TMPDIR}/words"
	assert_line --index 0 "probecmd"
	assert_line --index 2 "arg"
}
