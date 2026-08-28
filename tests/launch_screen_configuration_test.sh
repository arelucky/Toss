#!/usr/bin/env bash

set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
project_file="$project_root/Toss.xcodeproj/project.pbxproj"
info_plist="$project_root/Toss/Info.plist"
launch_color="$project_root/Toss/Assets.xcassets/LaunchScreenBackground.colorset/Contents.json"
launch_storyboard="$project_root/Toss/LaunchScreen.storyboard"

test -f "$launch_color"
test -f "$launch_storyboard"
test "$(plutil -extract UILaunchStoryboardName raw "$info_plist")" = "LaunchScreen"
rg -q '命运的一掷' "$launch_storyboard"
rg -q 'A toss of fate' "$launch_storyboard"
! rg -q 'INFOPLIST_KEY_UILaunchScreen_Generation = YES;' "$project_file"
