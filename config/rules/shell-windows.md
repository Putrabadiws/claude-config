# Windows (MINGW64/Git Bash) Shell Scripts

When creating `.sh` scripts, use MINGW64-compatible commands:

- Shell runs under Git Bash (MINGW64) on Windows
- No `zsh` available - use `bash` only
- Use `start` instead of `open` to open files/URLs
- Use `nslookup` instead of `dig`/`kdig`
- Use `where` instead of `whereis`
- Use `ipconfig` instead of `ifconfig`
- No `brew` - use `winget` or `choco` for package management
- Paths use `/c/Users/...` format in Git Bash (auto-converted from `C:\Users\...`)
- Use `command -v` to check tool availability before using
