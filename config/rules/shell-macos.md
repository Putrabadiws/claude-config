# macOS Shell Scripts

When creating `.sh` scripts, use macOS-compatible commands:

- macOS uses old bash without `mapfile` - use alternatives
- Prefer `zsh` syntax when possible
- Test with `/bin/bash` not `/usr/bin/env bash` if targeting system bash

## Java

- Machine-specific — each user configures their own JAVA_HOME and version aliases in `~/.claude/rules/shell-macos.md`
