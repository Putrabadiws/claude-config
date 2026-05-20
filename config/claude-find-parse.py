import sys, json, re

MAX_RESPONSE_LINES = 15

def oneliner(s):
    """Strip markdown to single line for compact fields."""
    s = re.sub(r'\*\*(.+?)\*\*', r'\1', s)
    s = re.sub(r'\*(.+?)\*', r'\1', s)
    s = re.sub(r'`{1,3}[^`]*`{1,3}', lambda m: m.group().strip('`'), s)
    s = re.sub(r'^#{1,6}\s+', '', s, flags=re.MULTILINE)
    s = re.sub(r'\[([^\]]+)\]\([^)]+\)', r'\1', s)
    s = re.sub(r'\s+', ' ', s)
    return s.strip()


def strip_ansi(s):
    return re.sub(r'\033\[[0-9;]*m', '', s)


def format_response(s):
    """Strip ANSI, keep raw markdown, truncate if needed."""
    s = strip_ansi(s)
    s = re.sub(r'\n{3,}', '\n\n', s)
    lines = s.split('\n')

    # trim trailing empty lines
    while lines and not lines[-1].strip():
        lines.pop()

    # first 5 + ... + last 5 if over 15 lines
    if len(lines) > MAX_RESPONSE_LINES:
        tail = lines[-5:]
        lines = lines[:5]
        lines.append('...')
        lines.extend(tail)

    return '\n'.join(lines)


def extract_text_oneline(c):
    if isinstance(c, str) and c.strip():
        return oneliner(c.replace('\n', ' '))[:1000]
    if isinstance(c, list):
        for item in c:
            if isinstance(item, dict) and item.get('type') == 'text' and item['text'].strip():
                return oneliner(item['text'].replace('\n', ' '))[:1000]
    return ''


def extract_raw_text(c):
    """Get raw text content preserving newlines."""
    if isinstance(c, str) and c.strip():
        return c.strip()
    if isinstance(c, list):
        for item in c:
            if isinstance(item, dict) and item.get('type') == 'text' and item['text'].strip():
                return item['text'].strip()
    return ''


f = sys.argv[1]
mode = sys.argv[2] if len(sys.argv) > 2 else 'info'

if mode == 'info':
    with open(f) as fh:
        lines = fh.readlines()
    sid = cwd = slug = first_ts = last_ts = first_msg = last_prompt = branch = ''
    user_count = 0
    for l in lines:
        d = json.loads(l)
        if not sid: sid = d.get('sessionId', '')
        if not cwd: cwd = d.get('cwd', '')
        if not slug and d.get('slug'): slug = d['slug']
        if not branch and d.get('gitBranch'): branch = d['gitBranch']
        ts = d.get('timestamp', '')
        if ts and not first_ts: first_ts = ts
        if ts: last_ts = ts
        if d.get('type') == 'user':
            user_count += 1
            t = extract_text_oneline(d.get('message', {}).get('content', ''))
            if t: last_prompt = t
            if not first_msg and t: first_msg = t
    print(sid)
    print(cwd)
    print(slug)
    print(first_ts[:16])
    print(last_ts[:16])
    print(user_count)
    print(first_msg)
    print(branch)
    print(last_prompt)

elif mode == 'response':
    with open(f) as fh:
        lines = fh.readlines()
    last_response = ''
    for l in lines:
        d = json.loads(l)
        if d.get('type') == 'assistant':
            c = d.get('message', {}).get('content', '')
            t = extract_raw_text(c)
            if t: last_response = t
    if last_response:
        print(format_response(last_response))

elif mode == 'match':
    for l in sys.stdin:
        try:
            d = json.loads(l)
            if d.get('type') == 'user':
                c = d.get('message', {}).get('content', '')
                t = extract_text_oneline(c)
                if t: print(t)
        except:
            pass
