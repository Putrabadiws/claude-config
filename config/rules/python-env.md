# Python Environment

- Never use system pip (`pip install` / `pip3 install`) — macOS blocks it
- Always use shared venv at `<workspace>/py/venv`
- Create if missing: `python3 -m venv <workspace>/py/venv`
- Install: `<workspace>/py/venv/bin/pip install <pkg>`
- Run: `<workspace>/py/venv/bin/python3 <script>`
