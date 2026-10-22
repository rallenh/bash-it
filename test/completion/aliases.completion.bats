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
