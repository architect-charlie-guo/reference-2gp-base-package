#!/bin/bash

###############################################################
# 
# resetScratchOrg.sh [-a <scratch_org_alias>] [--alias <scratch_org_alias>]
#                    [-d <duration in days>]  [--duration <duration in days>]
#                    [-c] [--clean]
#                    [--default]
#                    [-h] [--help]
# 
###############################################################

usage () {
  echo ""
  echo 'Usage: resetScratchOrg.sh [-a <scratch_org_alias>] [--alias <scratch_org_alias>]'
  echo '                          [-d <duration in days>] [--duration <duration in days>]'
  echo '                          [-c] [--clean]'
  echo '                          [--default]'
  echo '                          [-h] [--help]'
  exit 0
}

exit_if_next_arg_is_invalid () {
  [[ -z "$1" ]] && usage
  [[ "$1" =~ ^\- ]] && usage
}

scratch_def_file=config/rpbp-enterprise-project-scratch-def.json
scratch_org_name=reference-project-base-package
clean_run=false
duration='2'
org_alias=''
set_to_default=''


# alter GIT configuration to use ".githooks" directory for this project.
git config core.hooksPath .githooks

# Clean up and prune the local GIT repo to remove stale branches that have been removed form GitHub
git remote prune origin 2> /dev/null

while [[ $# -gt 0 ]]; do
  case "$1" in
    '-a'|'--alias')
      shift
      exit_if_next_arg_is_invalid "$1"
      org_alias="$1"
      echo "Setting org alias to be ${org_alias}"
      shift
      ;;
    '-d'|'--duration')
      shift
      exit_if_next_arg_is_invalid "$1"
      duration="$1"
      echo "Setting scratch org duration to be $duration days."
      shift
      ;;
    '-c'|'--clean')
      clean_run=true
      echo "Starting build from the beginning."
      shift
      ;;
    '--default')
      set_to_default=true
      shift
      ;;
    '-h'|'--help')
      usage
      ;;
    *)
      echo "ERROR: Incorrect flag specified '$1'"
      usage
      ;;
  esac
done

# Verify the org alias
if [ -z "${org_alias}" ]
  then
    echo "Please provide the username / org alias using the '--alias' flag."
    usage
    exit 1
fi

temp_dir=temp
progress_marker_filename=_buildprogressmarker_$org_alias

# Does the temp directory exist?
if [ ! -d "$temp_dir" ]
  then
    mkdir "$temp_dir"
fi 

# Is this a clean run?
if [[ "${clean_run}" = true ]]
  then
    rm -r "$temp_dir/$progress_marker_filename"
fi 

# Does the progressmarker file exist?
if [ ! -f "$temp_dir/$progress_marker_filename" ]
  then
    echo 0 > "$temp_dir/$progress_marker_filename"
fi 

progress_marker_value=$(<"$temp_dir/$progress_marker_filename")
# echo "progress_marker_value A == $progress_marker_value"

if [ -z "$progress_marker_value" ]
  then
    progress_marker_value=0
fi
# echo "progress_marker_value B == $progress_marker_value"

# Delete any previous scratch org with same alias
if [ 10 -gt "$progress_marker_value" ]
  then
    sf org delete scratch --no-prompt --target-org "${org_alias}"
    echo 10 > "$temp_dir/$progress_marker_filename"
    progress_marker_value=10
fi
# echo "progress_marker_value C == $progress_marker_value"

# exit script when any command fails.  From here forward, if there is a failure, we want the script to fail
set -e 

# Create new scratch org
if [ 20 -gt "$progress_marker_value" ]
  then
    sf org create scratch --wait 30 --duration-days "${duration}" --definition-file "${scratch_def_file}" --alias "${org_alias}"
    echo 20 > "$temp_dir/$progress_marker_filename"
    progress_marker_value=20
fi
# echo "progress_marker_value D == $progress_marker_value"

if [[ "${set_to_default}" = true ]]
  then
    echo "Setting ${org_alias} as the default username"
    sf config set target-org "${org_alias}"
fi

# Set scratch org and scratch default user to EST timezone. Also purge sample data.
if [ 30 -gt "$progress_marker_value" ]
  then
    ./bin/performAdjustmentsOnScratchOrg.sh "${org_alias}" "${scratch_org_name}"
    echo 30 > "$temp_dir/$progress_marker_filename"
    progress_marker_value=30
fi
# echo "progress_marker_value == $progress_marker_value"

# Install all dependencies
if [ 40 -gt "$progress_marker_value" ]
  then
    sf toolbox package dependencies install --wait 90 --targetusername "${org_alias}"
    echo 40 > "$temp_dir/$progress_marker_filename"
    progress_marker_value=40
fi
# echo "progress_marker_value == $progress_marker_value"

# Push source code to org.
if [ 50 -gt "$progress_marker_value" ]
  then
    sf project deploy start --ignore-conflicts --target-org "${org_alias}"
    echo 50 > "$temp_dir/$progress_marker_filename"
    progress_marker_value=50
fi
# echo "progress_marker_value == $progress_marker_value"

# Assign current user the RPBP Read Write permission set group
if [ 70 -gt "$progress_marker_value" ]
  then
    sf apex run --file scripts/assignUserCurrentAdminToRPBPReadWritePermSet.apex --target-org "${org_alias}"
    echo 70 > "$temp_dir/$progress_marker_filename"
    progress_marker_value=70
fi
# echo "progress_marker_value == $progress_marker_value"

# Push source code to org.
# if [ 85 -gt "$progress_marker_value" ]
#   then
#     ./bin/loadData.sh --target-org "${org_alias}" 
#     echo 85 > "$temp_dir/$progress_marker_filename"
#     progress_marker_value=85
# fi
# echo "progress_marker_value == $progress_marker_value"

# Open the org
if [ 99 -gt "$progress_marker_value" ]
  then
    sf org open --path lightning/app/c__RPBP_Ref --target-org "${org_alias}"
    echo ""
    echo "Scratch org ${org_alias} is ready"
    echo ""
    echo 99 > "$temp_dir/$progress_marker_filename"
    progress_marker_value=99
fi
# echo "progress_marker_value == $progress_marker_value"

# remove marker file
rm "$temp_dir/$progress_marker_filename"
