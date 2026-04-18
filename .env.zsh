# ~/Developer/zig/gameEngine/.env.zsh
alias build='zig build --error-style minimal --summary all'
alias ui='zig build ui --error-style minimal'
alias test='zig build test --error-style minimal'
alias run='zig build play --error-style minimal'
alias release='zig build play --error-style minimal -Doptimize=ReleaseFast'
alias small='zig build play --error-style minimal -Doptimize=ReleaseSmall'
alias art='zig build zixelart --error-style minimal'
alias clean='zig build clean'

# Project dirs
export ENGINE_ROOT=~/Developer/zig/gameEngine
