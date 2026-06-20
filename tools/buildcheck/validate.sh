#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}

"$script_dir/with-clean-shell.sh" xcrun swift test --package-path PromptHubSkillKit
"$script_dir/with-clean-shell.sh" xcrun swift test --package-path PromptHubCLI
"$script_dir/with-clean-shell.sh" xcodebuild test -project prompthub.xcodeproj -scheme prompthub -destination 'platform=macOS' -only-testing:prompthubTests/PromptHubBridgeTests
"$script_dir/with-clean-shell.sh" xcodebuild test -project prompthub.xcodeproj -scheme prompthub -destination 'platform=macOS' -only-testing:prompthubTests/CLIParityTests
"$script_dir/with-clean-shell.sh" xcodebuild test -project prompthub.xcodeproj -scheme prompthub -destination 'platform=macOS' -only-testing:prompthubTests/SkillCLIServiceTests