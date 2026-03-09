# ~/Developer/zig/gameEngine/.env.zsh

alias ui='zig build ui --prominent-compile-errors'
alias test='zig build test --prominent-compile-errors'
alias run='zig build play --prominent-compile-errors'
alias release='zig build play --prominent-compile-errors -Doptimize=ReleaseFast'
alias small='zig build play --prominent-compile-errors -Doptimize=ReleaseSmall'
alias art='zig build zixelart --prominent-compile-errors'
alias clean='zig build clean'

# Project dirs
export ENGINE_ROOT=~/Developer/zig/gameEngine
