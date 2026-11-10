#!/usr/bin/env python3
"""Dump a student's projects and check which section the app would put them in.

Run from the project root (needs .env with FT_UID and FT_SECRET; secrets are NOT printed):

    python3 tool/dump_projects.py LOGIN            # live request to the 42 API
    python3 tool/dump_projects.py LOGIN --deep     # + compare with the paged list and /exams
    python3 tool/dump_projects.py --file user.json # the same analysis of a saved response
    python3 tool/dump_projects.py --cursus         # ALL cursuses of the 42 network (GET /v2/cursus)

What is printed:
  1. the student's cursuses (cursus_users): id, name, slug, kind, level, dates
     (`kind` is None if the API does not embed it into cursus_users);
  2. ALL projects (not only completed ones) with the fields: section by the
     app's rules, slug, name, status, cursus_ids, validated, mark.
     The section is chosen like in lib/models/project_section.dart: FIRST by
     the cursus of the project (c-piscine-reloaded -> Reloaded, c-piscine or
     kind piscine / piscine_deprecated -> Piscina, any other cursus except
     42cursus -> "Cursus: <its name>"), and only then by the slug (Common Core
     / Outer Core).

The --deep mode answers the question "does the API not return these projects
at all, or do we lose them":
  3. the paged `/v2/users/LOGIN/projects_users` (page[size]=100) is compared
     with the list that comes inside the profile; projects that are missing
     from the nested list are printed;
  4. candidate projects by the words exam/rush/bsq: slug, name, status;
  5. a probe of `/v2/users/LOGIN/exams`: the response code and the number of records.

The --cursus mode does not need a login. It prints every cursus that exists
in the 42 network: id, name, slug and `kind` (if the API gives it). Use it to
see how the piscines of Outer Core (Mobile, Unity, Cybersecurity ...) are
called and whether they are separate cursuses, without a live student.

The splitting rules (commonCoreSlugs, patterns, cursus slugs) are read straight
from lib/models/*.dart, so the script does not drift from the app.
No dependencies: only the Python 3 standard library.
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

API = 'https://api.intra.42.fr'
# Cloudflare in front of the API cuts the default UA "Python-urllib/3.x" (403),
# so we introduce ourselves. curl gets through precisely because it has a
# different UA.
HEADERS = {'User-Agent': 'swifty-companion-tool/1.0 (42 Barcelona student project)',
           'Accept': 'application/json'}
CATEGORY_DART = os.path.join('lib', 'models', 'project_category.dart')
SECTION_DART = os.path.join('lib', 'models', 'project_section.dart')
CURSUS_DART = os.path.join('lib', 'models', 'cursus_progress.dart')


def load_env(path='.env'):
    env = {}
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def load_core_slugs():
    with open(CATEGORY_DART, encoding='utf-8') as f:
        text = f.read()
    block = re.search(r'commonCoreSlugs\s*=\s*\{(.*?)\};', text, re.S).group(1)
    block = re.sub(r'//[^\n]*', '', block)  # without comments
    return set(re.findall(r"'([^']+)'", block))


def load_dart():
    """Prefixes, RegExp patterns and the slug list are taken from Dart: the script does not drift from the app."""
    with open(CATEGORY_DART, encoding='utf-8') as f:
        text = f.read()
    prefixes = re.findall(r"'([^']+)'", re.search(
        r'slugPrefixes\s*=\s*\[(.*?)\];', text, re.S).group(1))
    patterns = [re.compile(p) for p in re.findall(r"RegExp\(r'([^']+)'\)", text)]
    return prefixes, patterns


def load_consts(path):
    """String constants `const String name = 'value';` from a Dart file."""
    with open(path, encoding='utf-8') as f:
        return dict(re.findall(r"const String (\w+) = '([^']+)';", f.read()))


CORE = load_core_slugs()
PREFIXES, PATTERNS = load_dart()
SECTION_CONSTS = load_consts(SECTION_DART)
PISCINE_SLUG = SECTION_CONSTS['piscineCursusSlug']
PISCINE_KINDS = {SECTION_CONSTS['piscineKind'], SECTION_CONSTS['piscineDeprecatedKind']}
RELOADED_SLUG = SECTION_CONSTS['piscineReloadedCursusSlug']
MAIN_SLUG = load_consts(CURSUS_DART)['mainCursusSlug']


def norm(slug):
    s = slug.strip().lower()
    for prefix in PREFIXES:
        if s.startswith(prefix):
            return s[len(prefix):]
    return s


def category(slug):
    if slug is None:
        return 'Outer'
    s = norm(slug)
    if 'piscine' in s and 'reloaded' in s:
        return 'Reloaded'
    if s.startswith('c-piscine') or s.startswith('piscine'):
        return 'Piscina'
    if s in CORE or any(p.search(s) for p in PATTERNS):
        return 'Common'
    return 'Outer'


def section(pu, cursuses):
    """The section of a projects_users record: first by cursus, then by slug.

    `cursuses` maps cursus_id -> (slug, name, kind) for the cursuses the student has.
    It is the same algorithm as `sectionOf` in lib/models/project_section.dart.
    """
    for cursus_id in pu.get('cursus_ids') or []:
        info = cursuses.get(cursus_id)
        if info is None:
            continue
        slug, name, kind = info
        slug = (slug or '').lower()
        kind = (kind or '').lower()
        if slug == MAIN_SLUG:
            continue
        if slug == RELOADED_SLUG:
            return 'Reloaded'
        if slug == PISCINE_SLUG or kind in PISCINE_KINDS:
            return 'Piscina'
        title = name or slug
        if title:
            return f'Cursus: {title}'
    return category((pu.get('project') or {}).get('slug'))


def get_token():
    env = load_env()
    body = urllib.parse.urlencode({
        'grant_type': 'client_credentials',
        'client_id': env['FT_UID'],
        'client_secret': env['FT_SECRET'],
    }).encode()
    return http_json(urllib.request.Request(
        f'{API}/oauth/token', data=body, headers=HEADERS), 'token request')['access_token']


def api_get(token, path, what, fatal=True):
    return http_json(urllib.request.Request(
        f'{API}{path}', headers={**HEADERS, 'Authorization': f'Bearer {token}'}),
        what, fatal=fatal)


def fetch(login, token=None):
    token = token or get_token()
    return api_get(token, f'/v2/users/{urllib.parse.quote(login, safe="")}', f'profile {login}')


def http_json(req, what, fatal=True):
    """A JSON response; on error it either ends the script (fatal) or returns {'_error': text}."""
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        # The server response body contains no secrets (we never echo them),
        # but we truncate it so an HTML page from Cloudflare does not clutter the output.
        body = e.read(400).decode('utf-8', 'replace').replace('\n', ' ')
        message = f'HTTP error {e.code} during "{what}": {body}'
    except urllib.error.URLError as e:
        message = f'Network unavailable during "{what}": {e.reason}'
    if fatal:
        sys.exit(message)
    return {'_error': message}


def deep_checks(login, token, data):
    """Where projects get lost: in the nested list, in the paged one, or they are not in the API at all."""
    quoted = urllib.parse.quote(login, safe='')
    embedded = {(pu.get('project') or {}).get('slug') for pu in data.get('projects_users') or []}
    print(f'\n== deep: nested list in the profile: {len(data.get("projects_users") or [])} records ==')

    paged, page = [], 1
    while page <= 20:  # a safety limit: 2000 records is plenty
        chunk = api_get(token, f'/v2/users/{quoted}/projects_users?page[size]=100&page[number]={page}',
                        f'projects_users, page {page}', fatal=False)
        if isinstance(chunk, dict):
            print(chunk.get('_error', 'unexpected response'))
            break
        paged.extend(chunk)
        if len(chunk) < 100:
            break
        page += 1
    print(f'== deep: paged /projects_users: {len(paged)} records ==')
    extra = [pu for pu in paged if (pu.get('project') or {}).get('slug') not in embedded]
    print(f'only in the paged list (missing from the nested one): {len(extra)}')
    for pu in extra:
        p = pu.get('project') or {}
        print('  ', p.get('slug'), '|', p.get('name'), '|', pu.get('status'), '|', pu.get('cursus_ids'))

    print('\n== deep: exam / rush / bsq candidates among ALL known records ==')
    seen = set()
    for pu in list(data.get('projects_users') or []) + paged:
        p = pu.get('project') or {}
        text = f"{p.get('slug')} {p.get('name')}".lower()
        key = (p.get('slug'), pu.get('status'))  # no id: it may be missing in the nested list
        if key in seen or not re.search(r'exam|rush|bsq', text):
            continue
        seen.add(key)
        print('  ', p.get('slug'), '|', p.get('name'), '|', pu.get('status'),
              '|', pu.get('cursus_ids'), '|', pu.get('validated?'), '|', pu.get('final_mark'))
    if not seen:
        print('   (no records)')

    exams = api_get(token, f'/v2/users/{quoted}/exams', 'exams of the user', fatal=False)
    print('\n== deep: /v2/users/LOGIN/exams ==')
    if isinstance(exams, dict) and '_error' in exams:
        print(exams['_error'])
    else:
        print(f'records: {len(exams)}')
        for e in exams[:15]:
            print('  ', {k: e.get(k) for k in ('id', 'name', 'begin_at', 'end_at', 'project_id') if k in e})


def list_cursuses():
    """GET /v2/cursus (all pages): every cursus of the 42 network."""
    token = get_token()
    cursuses, page = [], 1
    while page <= 20:  # a safety limit: 2000 cursuses is plenty
        chunk = api_get(token, f'/v2/cursus?page[size]=100&page[number]={page}',
                        f'cursus, page {page}')
        if not isinstance(chunk, list):
            sys.exit('unexpected response of /v2/cursus')
        cursuses.extend(chunk)
        if len(chunk) < 100:
            break
        page += 1
    print(f'== all cursuses of the 42 network: {len(cursuses)} ==')
    print('id | name | slug | kind')
    for c in sorted(cursuses, key=lambda c: c.get('id') or 0):
        print(' | '.join(str(c.get(k)) for k in ('id', 'name', 'slug', 'kind')))


def main():
    args = sys.argv[1:]
    deep = '--deep' in args
    args = [a for a in args if a != '--deep']
    token = None
    if args == ['--cursus']:
        list_cursuses()
        return
    if len(args) == 2 and args[0] == '--file':
        if deep:
            sys.exit('--deep works only with a live request (LOGIN), not with --file')
        with open(args[1], encoding='utf-8') as f:
            data = json.load(f)
    elif len(args) == 1 and not args[0].startswith('-'):
        token = get_token()
        data = fetch(args[0], token)
    else:
        sys.exit(__doc__)

    print('== cursuses (cursus_users) ==')
    print('cursus_id | name | slug | kind | level | begin | end')
    for cu in data.get('cursus_users') or []:
        c = cu.get('cursus') or {}
        print(' | '.join(str(x) for x in (
            cu.get('cursus_id'), c.get('name'), c.get('slug'), c.get('kind'), cu.get('level'),
            (cu.get('begin_at') or '')[:10], (cu.get('end_at') or '')[:10])))

    by_id = {}
    for cu in data.get('cursus_users') or []:
        c = cu.get('cursus') or {}
        cursus_id = cu.get('cursus_id') if cu.get('cursus_id') is not None else c.get('id')
        if cursus_id is not None:
            by_id[cursus_id] = (c.get('slug'), c.get('name'), c.get('kind'))

    print('\n== projects (all statuses) ==')
    print('section | slug | name | status | cursus_ids | validated | mark')
    rows = []
    for pu in data.get('projects_users') or []:
        p = pu.get('project') or {}
        rows.append((section(pu, by_id), p.get('slug'), p.get('name'), pu.get('status'),
                     pu.get('cursus_ids'), pu.get('validated?'), pu.get('final_mark')))
    for r in sorted(rows, key=lambda r: (r[0], str(r[1]))):
        print(' | '.join(str(x) for x in r))

    if deep:
        deep_checks(args[0], token, data)


if __name__ == '__main__':
    main()
