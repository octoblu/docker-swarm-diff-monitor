#!/bin/bash

SCRIPT_NAME='setup'

matches_debug() {
  if [ -z "$DEBUG" ]; then
    return 1
  fi
  if [[ $SCRIPT_NAME == "$DEBUG" ]]; then
    return 0
  fi
  return 1
}

debug() {
  local cyan='\033[0;36m'
  local no_color='\033[0;0m'
  local message="$@"
  matches_debug || return 0
  (>&2 echo -e "[${cyan}${SCRIPT_NAME}${no_color}]: $message")
}

script_directory(){
  local source="${BASH_SOURCE[0]}"
  local dir=""

  while [ -h "$source" ]; do # resolve $source until the file is no longer a symlink
    dir="$( cd -P "$( dirname "$source" )" && pwd )"
    source="$(readlink "$source")"
    [[ $source != /* ]] && source="$dir/$source" # if $source was a relative symlink, we need to resolve it relative to the path where the symlink file was located
  done

  dir="$( cd -P "$( dirname "$source" )" && pwd )"

  echo "$dir"
}

assert_required_params() {
  local github_token="$1"
  local github_repo="$2"
  local stack_path="$3"

  if [ -n "$github_token" ] && [ -n "$github_repo" ] && [ -n "$stack_path" ]; then
    return 0
  fi

  usage

  if [ -z "$github_token" ]; then
    echo "Missing <github-token> argument"
  fi

  if [ -z "$github_repo" ]; then
    echo "Missing <github-repo> argument"
  fi

  if [ -z "$stack_path" ]; then
    echo "Missing <stack-path> argument"
  fi

  exit 1
}

usage(){
  echo "USAGE: ${SCRIPT_NAME} <github-token> <github-repo> <stack-path>"
  echo ''
  echo 'Description: ...'
  echo ''
  echo 'Arguments:'
  echo '  -h, --help       print this help text'
  echo '  -v, --version    print the version'
  echo ''
  echo 'Environment:'
  echo '  DEBUG            print debug output'
  echo ''
}

version(){
  local directory
  directory="$(script_directory)"

  if [ -f "$directory/VERSION" ]; then
    cat "$directory/VERSION"
  else
    echo "unknown-version"
  fi
}

setup() {
  local github_token="$1"
  local github_repo="$2"
  local stack_path="$3"

  git clone --quiet --depth=1 "https://$github_token@github.com/$github_repo" repository > /dev/null \
  && ln -s "$(pwd)/repository/$stack_path" /workdir
}

main() {
  local github_token github_repo stack_path

  # Define args up here
  while [ "$1" != "" ]; do
    local param="$1"
    # local value="$2"
    case "$param" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --version)
        version
        exit 0
        ;;
      # Arg with value
      # -x | --example)
      #   example="$value"
      #   shift
      #   ;;
      # Arg without value
      # -e | --example-flag)
      #   example_flag='true'
      #   ;;
      *)
        if [ "${param::1}" == '-' ]; then
          echo "ERROR: unknown parameter \"$param\""
          usage
          exit 1
        fi
        # Set main arguments
        if [ -z "$github_token" ]; then
          github_token="$param"
        elif [ -z "$github_repo" ]; then
          github_repo="$param"
        elif [ -z "$stack_path" ]; then
          stack_path="$param"
        fi
        ;;
    esac
    shift
  done

  assert_required_params "$github_token" "$github_repo" "$stack_path"
  setup "$github_token" "$github_repo" "$stack_path"
}

main "$@"
