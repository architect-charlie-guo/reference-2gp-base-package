#!/bin/bash
set -e 
# Change default timezone of org
sf data update record --sobject Organization --where "Name='$2'" --values "TimeZoneSidKey='America/New_York'" --target-org $1

# Change timezone of default DX Scratch Org User
sf data update record --sobject User --where "Name='User User'" --values "TimeZoneSidKey='America/New_York'" --target-org $1
