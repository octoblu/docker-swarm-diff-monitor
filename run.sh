#!/bin/bash

SCRIPT_NAME='run'

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
  local report_url="$4"

  if [ -n "$github_token" ] && [ -n "$github_repo" ] && [ -n "$stack_path" ] && [ -n "$report_url" ]; then
    return 0
  fi

  usage

  if [ -z "$github_token" ]; then
    echo "Missing GITHUB_TOKEN environment variable"
  fi

  if [ -z "$github_repo" ]; then
    echo "Missing GITHUB_REPO environment variable"
  fi

  if [ -z "$stack_path" ]; then
    echo "Missing STACK_PATH environment variable"
  fi

  if [ -z "$report_url" ]; then
    echo "Missing REPORT_URL environment variable"
  fi

  exit 1
}

usage(){
  echo "USAGE: ${SCRIPT_NAME}"
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

connect_to_machine() {
  local machine_id found_machine_code

  if [ ! -d "docker-machine/machines" ]; then
    errecho "Missing docker-machine directory"
    return 1
  fi

  machine_id="$(get_machine_id)"
  found_machine_code="$?"

  if [ -z "$machine_id" ]; then
    errecho "Unable to find machine"
    return 1
  fi

  if [ "$found_machine_code" != "0" ]; then
    errecho "$machine_id: Unable to connect to a machine"
    return 1
  fi

  eval "$(docker-machine --storage-path './docker-machine' env --shell=bash "$machine_id")"
}

errecho() {
  local message="$@"
  (>&2 echo -e "$message")
}

get_machine_ids(){
  find "docker-machine/machines" -iname "*-*-*-*" -maxdepth 1 -mindepth 1 -type d
}

get_manager_machine_ids(){
  find "docker-machine/machines" -iname "*-*-manager-*" -maxdepth 1 -mindepth 1 -type d
}

get_machine_id() {
  local machine_id
  local machines

  update_cert_permissions || return 1

  machines=$(get_manager_machine_ids)
  for machine_dir in $machines; do
    machine_id="$(basename "$machine_dir")"
    validate_machine_id "$machine_id"
    if [ "$?" == "0" ]; then
      echo "$machine_id"
      return 0
    else
      errecho "Machine '${machine_id}' was unreachable. Trying another one."
    fi
    n=$[$n+1]
  done
  return 1
}

get_expires(){
  local now_seconds expires_seconds expires
  now_seconds="$(date --utc +"%s")"
  let 'expires_seconds = now_seconds + 300'

  date --iso-8601=seconds --utc --date="@$expires_seconds"
}

report() {
  local error exit_code expires output report_url success
  report_url="$1"
  exit_code="$2"
  output="$3"
  success="true"

  expires="$(get_expires)"
  error="$(echo -n "$output" | json-escape)"

  if [ "$exit_code" != "0" ]; then
    success="false"
  fi

  curl "$report_url" \
    --fail \
    --silent \
    -X POST \
    -H 'Content-Type: application/json' \
    -d "{\"success\": $success, \"expires\": \"$expires\", \"error\": {\"message\": $error}}"
  > /dev/null
}

run(){
  local report_url="$1"

  while true; do
    local output exit_code
    output="$(env MACHINE_STORAGE_PATH="/workdir/docker-machine" docker-swarm-diff)"
    exit_code="$?"

    report "$report_url" "$exit_code" "$output" || exit 1
    sleep 60
  done
}

update_cert_permissions() {
  for machine_dir in $(get_machine_ids); do
    local machine_private_key
    machine_private_key="$machine_dir/id_rsa"
    if [ -f "$machine_private_key" ]; then
      chmod 600 "$machine_private_key"
    fi
  done
}

validate_machine_id() {
  local machine_id="$1"
  docker-machine --storage-path './docker-machine' config "$machine_id" 2>&1 | grep -i 'error' && return 1
  return 0
}

main() {
  local github_token="$GITHUB_TOKEN"
  local github_repo="$GITHUB_REPO"
  local stack_path="$STACK_PATH"
  local report_url="$REPORT_URL"

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
        # if [ -z "$main_arg" ]; then
        #   main_arg="$param"
        # elif [ -z "$main_arg_2"]; then
        #   main_arg_2="$param"
        # fi
        ;;
    esac
    shift
  done

  assert_required_params "$github_token" "$github_repo" "$stack_path" "$report_url"

  ./setup.sh "$github_token" "$github_repo" "$stack_path" \
  && pushd "/workdir" > /dev/null \
  && connect_to_machine \
  && run "$report_url"
}

main "$@"
