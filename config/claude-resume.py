"""Print resume commands for the 10 most recent Claude Code sessions."""
import os, json, glob, sys, shutil, re
from datetime import datetime, timezone

MAX_SESSIONS = 10
MAX_AGE_HOURS = 24
term_width = shutil.get_terminal_size().columns

sessions = glob.glob(os.path.expanduser('~/.claude/projects/*//*.jsonl'))
if not sessions:
    sys.exit(0)

now = datetime.now(timezone.utc)
results = []

def oneliner(s):
    s = re.sub(r'\*\*(.+?)\*\*', r'\1', s)
    s = re.sub(r'\*(.+?)\*', r'\1', s)
    s = re.sub(r'`{1,3}[^`]*`{1,3}', lambda m: m.group().strip('`'), s)
    s = re.sub(r'^#{1,6}\s+', '', s, flags=re.MULTILINE)
    s = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()

def extract_text(c):
    if isinstance(c, str) and c.strip():
        return oneliner(c.replace('\n', ' '))
    if isinstance(c, list):
        for item in c:
            if isinstance(item, dict) and item.get('type') == 'text' and item['text'].strip():
                return oneliner(item['text'].replace('\n', ' '))
    return ''

for sf in sessions:
    try:
        mtime = os.path.getmtime(sf)
        age = now - datetime.fromtimestamp(mtime, tz=timezone.utc)
        if age.total_seconds() > MAX_AGE_HOURS * 3600:
            continue

        sid = cwd = slug = last_ts = first_msg = first_response = entrypoint = ''
        with open(sf) as f:
            for line in f:
                d = json.loads(line)
                if not sid: sid = d.get('sessionId', '')
                if not cwd: cwd = d.get('cwd', '')
                if not slug and d.get('slug'): slug = d['slug']
                if not entrypoint: entrypoint = d.get('entrypoint', '')
                if sid and cwd and entrypoint:
                    break

        if not sid or not cwd:
            continue
        # Skip background SDK sessions (memory consolidation, summarization hooks).
        # They run from /private/tmp with entrypoint=sdk-cli and aren't useful to resume interactively.
        if entrypoint and entrypoint != 'cli':
            continue

        with open(sf) as f:
            for line in f:
                d = json.loads(line)
                if not slug and d.get('slug'): slug = d['slug']
                if not first_msg and d.get('type') == 'user':
                    first_msg = extract_text(d.get('message', {}).get('content', ''))
                elif not first_response and d.get('type') == 'assistant':
                    first_response = extract_text(d.get('message', {}).get('content', ''))
                if first_msg and first_response and slug:
                    break

        with open(sf) as f:
            f.seek(0, 2)
            fsize = f.tell()
            f.seek(max(0, fsize - 8192))
            tail = f.readlines()
            for line in reversed(tail):
                try:
                    d = json.loads(line)
                    ts = d.get('timestamp', '')
                    if ts:
                        last_ts = ts
                        break
                except:
                    pass

        results.append((sid, cwd, slug, last_ts, mtime, first_msg, first_response))
    except:
        pass

if not results:
    sys.exit(0)

results.sort(key=lambda x: x[4], reverse=True)
results = results[:MAX_SESSIONS]

DIM = '\033[2m'
ITALIC = '\033[3m'
YELLOW = '\033[33m'
GREEN = '\033[32m'
MAGENTA = '\033[35m'
CYAN = '\033[36m'
WHITE = '\033[1;37m'
RESET = '\033[0m'

def truncate(s, max_w):
    if len(s) > max_w:
        return s[:max_w - 3] + '...'
    return s

def format_age(last_ts):
    if not last_ts:
        return '?'
    try:
        dt = datetime.fromisoformat(last_ts.replace('Z', '+00:00')).astimezone()
        age = now - dt.astimezone(timezone.utc)
        if age.days > 0:
            ago = f"{age.days}d ago"
        elif age.seconds >= 3600:
            ago = f"{age.seconds // 3600}h ago"
        else:
            ago = f"{age.seconds // 60}m ago"
        return dt.strftime('%m-%d %H:%M') + f' ({ago})'
    except:
        return last_ts[:16]

bar = f"{DIM}{'─' * min(55, term_width)}{RESET}"
max_content = term_width - 8

print(bar)
print(f"  {WHITE}Recent sessions{RESET}  {DIM}(last 24h){RESET}")
print()
for i, (sid, cwd, slug, last_ts, _, first_msg, first_response) in enumerate(results):
    ts_str = format_age(last_ts)
    if slug:
        name_str = f"{MAGENTA}{slug}{RESET}"
    else:
        name_str = f"{DIM}{ITALIC}(unnamed){RESET}"

    print(f"  {name_str}  {DIM}{ts_str}{RESET}")
    if first_msg:
        print(f"    {CYAN}>{RESET} {DIM}{truncate(first_msg, max_content)}{RESET}")
    if first_response:
        print(f"    {GREEN}>{RESET} {DIM}{truncate(first_response, max_content)}{RESET}")
    print(f"    {GREEN}cd {cwd} && claude --resume {sid}{RESET}")
    if i < len(results) - 1:
        print()

print(bar)
