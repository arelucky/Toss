#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
project_file="$project_root/Toss.xcodeproj/project.pbxproj"
info_plist="$project_root/Toss/Info.plist"
launch_color="$project_root/Toss/Assets.xcassets/LaunchScreenBackground.colorset/Contents.json"

test -f "$launch_color"
test "$(plutil -extract UILaunchScreen.UIColorName raw "$info_plist")" = "LaunchScreenBackground"
! rg -q 'INFOPLIST_KEY_UILaunchScreen_Generation = YES;' "$project_file"
