# ~/Developer/zig/gameEngine/.env.zsh
alias build='zig build --error-style minimal --summary all'
alias ui='zig build ui --error-style minimal'
alias test='zig build test --error-style minimal'
alias run='zig build play --error-style minimal'
alias release='zig build play --error-style minimal -Doptimize=ReleaseFast'
alias small='zig build play --error-style minimal -Doptimize=ReleaseSmall'
alias art='zig build zixelart --error-style minimal'
alias level='zig build sceneEdit --error-style minimal'
alias clean='zig build clean'

# NOTE: --fuzz (continuous mode) is broken in Zig 0.16.0 (builtin.StackTrace type mismatch bug).
# These run a single deterministic seed pass instead — still catches panics and failed assertions.
# Re-enable --fuzz when Zig patches test_runner.zig.
alias test-full='zig build test --error-style minimal && zig build fuzz-lexer & zig build fuzz-parser & zig build fuzz-font & zig build fuzz-math & wait'

# Project dirs
export ENGINE_ROOT=~/Developer/zig/gameEngine
