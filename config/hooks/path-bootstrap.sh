#!/bin/bash
# Shared PATH bootstrap for hook scripts
# Source this at the top of each hook: source "$(dirname "$0")/path-bootstrap.sh"
# Ensures tools are discoverable in non-interactive shells (Windows PS, cmd)

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # Git Bash builtins (sed, grep, head, etc.)
    [ -d "/usr/bin" ] && PATH="/usr/bin:$PATH"
    # Git itself
    [ -d "/c/Program Files/Git/cmd" ] && PATH="/c/Program Files/Git/cmd:$PATH"
    # Common tool locations (jq, kubectl, helm, etc.)
    [ -d "$LOCALAPPDATA/Microsoft/WinGet/Links" ] && PATH="$LOCALAPPDATA/Microsoft/WinGet/Links:$PATH"
    [ -d "$HOME/bin" ] && PATH="$HOME/bin:$PATH"
    [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
    # Chocolatey
    [ -d "/c/ProgramData/chocolatey/bin" ] && PATH="/c/ProgramData/chocolatey/bin:$PATH"
    ;;
  Darwin)
    # Homebrew (Apple Silicon + Intel)
    [ -d "/opt/homebrew/bin" ] && PATH="/opt/homebrew/bin:$PATH"
    [ -d "/usr/local/bin" ] && PATH="/usr/local/bin:$PATH"
    ;;
  Linux)
    [ -d "/home/linuxbrew/.linuxbrew/bin" ] && PATH="/home/linuxbrew/.linuxbrew/bin:$PATH"
    [ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
    ;;
esac

export PATH
