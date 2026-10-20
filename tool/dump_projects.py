#!/usr/bin/env python3
"""Выгрузка проектов студента и проверка, в какой раздел их положит приложение.

Запуск из корня проекта (нужен .env с FT_UID и FT_SECRET; секреты НЕ печатаются):

    python3 tool/dump_projects.py LOGIN            # живой запрос к API 42
    python3 tool/dump_projects.py LOGIN --deep     # + сверка с постраничным списком и /exams
    python3 tool/dump_projects.py --file user.json # тот же разбор по сохранённому ответу

Что печатается:
  1. курсы студента (cursus_users): id, название, slug, уровень, даты;
  2. ВСЕ проекты (не только завершённые) с полями: раздел по правилам приложения,
     slug, название, статус, cursus_ids, validated, оценка.

Режим --deep отвечает на вопрос «API вообще не отдаёт эти проекты или мы их теряем»:
  3. постраничный `/v2/users/LOGIN/projects_users` (page[size]=100) сравнивается со
     списком, который приходит внутри профиля; печатаются проекты, которых во
     вложенном списке нет;
  4. проект-кандидаты по словам exam/rush/bsq: slug, название, статус;
  5. проба `/v2/users/LOGIN/exams`: код ответа и сколько записей.

Правила разбиения (commonCoreSlugs, шаблоны) читаются прямо из
lib/models/project_category.dart, поэтому скрипт не расходится с приложением.
Зависимостей нет: только стандартная библиотека Python 3.
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

API = 'https://api.intra.42.fr'
# Cloudflare перед API режет дефолтный UA «Python-urllib/3.x» (403), поэтому
# представляемся сами. curl проходит именно потому, что у него другой UA.
HEADERS = {'User-Agent': 'swifty-companion-tool/1.0 (42 Barcelona student project)',
           'Accept': 'application/json'}
CATEGORY_DART = os.path.join('lib', 'models', 'project_category.dart')


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
    block = re.sub(r'//[^\n]*', '', block)  # без комментариев
    return set(re.findall(r"'([^']+)'", block))


def load_dart():
    """Префиксы, шаблоны RegExp и список slug берём из dart: скрипт не расходится с приложением."""
    with open(CATEGORY_DART, encoding='utf-8') as f:
        text = f.read()
    prefixes = re.findall(r"'([^']+)'", re.search(
        r'slugPrefixes\s*=\s*\[(.*?)\];', text, re.S).group(1))
    patterns = [re.compile(p) for p in re.findall(r"RegExp\(r'([^']+)'\)", text)]
    return prefixes, patterns


CORE = load_core_slugs()
PREFIXES, PATTERNS = load_dart()


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


def get_token():
    env = load_env()
    body = urllib.parse.urlencode({
        'grant_type': 'client_credentials',
        'client_id': env['FT_UID'],
        'client_secret': env['FT_SECRET'],
    }).encode()
    return http_json(urllib.request.Request(
        f'{API}/oauth/token', data=body, headers=HEADERS), 'получение токена')['access_token']


def api_get(token, path, what, fatal=True):
    return http_json(urllib.request.Request(
        f'{API}{path}', headers={**HEADERS, 'Authorization': f'Bearer {token}'}),
        what, fatal=fatal)


def fetch(login, token=None):
    token = token or get_token()
    return api_get(token, f'/v2/users/{urllib.parse.quote(login, safe="")}', f'профиль {login}')


def http_json(req, what, fatal=True):
    """JSON-ответ; при ошибке либо завершает скрипт (fatal), либо возвращает {'_error': текст}."""
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        # Тело ответа сервера секретов не содержит (мы их не эхо-печатаем),
        # но обрезаем, чтобы не засорять вывод HTML-страницей Cloudflare.
        body = e.read(400).decode('utf-8', 'replace').replace('\n', ' ')
        message = f'Ошибка HTTP {e.code} при операции «{what}»: {body}'
    except urllib.error.URLError as e:
        message = f'Сеть недоступна при операции «{what}»: {e.reason}'
    if fatal:
        sys.exit(message)
    return {'_error': message}


def deep_checks(login, token, data):
    """Где пропадают проекты: во вложенном списке, в постраничном или их нет в API вообще."""
    quoted = urllib.parse.quote(login, safe='')
    embedded = {(pu.get('project') or {}).get('slug') for pu in data.get('projects_users') or []}
    print(f'\n== deep: вложенный список в профиле: {len(data.get("projects_users") or [])} записей ==')

    paged, page = [], 1
    while page <= 20:  # предохранитель: 2000 записей хватит с запасом
        chunk = api_get(token, f'/v2/users/{quoted}/projects_users?page[size]=100&page[number]={page}',
                        f'projects_users, страница {page}', fatal=False)
        if isinstance(chunk, dict):
            print(chunk.get('_error', 'неожиданный ответ'))
            break
        paged.extend(chunk)
        if len(chunk) < 100:
            break
        page += 1
    print(f'== deep: постраничный /projects_users: {len(paged)} записей ==')
    extra = [pu for pu in paged if (pu.get('project') or {}).get('slug') not in embedded]
    print(f'только в постраничном (нет во вложенном): {len(extra)}')
    for pu in extra:
        p = pu.get('project') or {}
        print('  ', p.get('slug'), '|', p.get('name'), '|', pu.get('status'), '|', pu.get('cursus_ids'))

    print('\n== deep: кандидаты exam / rush / bsq среди ВСЕХ известных записей ==')
    seen = set()
    for pu in list(data.get('projects_users') or []) + paged:
        p = pu.get('project') or {}
        text = f"{p.get('slug')} {p.get('name')}".lower()
        key = (p.get('slug'), pu.get('status'))  # без id: во вложенном списке он может отсутствовать
        if key in seen or not re.search(r'exam|rush|bsq', text):
            continue
        seen.add(key)
        print('  ', p.get('slug'), '|', p.get('name'), '|', pu.get('status'),
              '|', pu.get('cursus_ids'), '|', pu.get('validated?'), '|', pu.get('final_mark'))
    if not seen:
        print('   (ни одной записи)')

    exams = api_get(token, f'/v2/users/{quoted}/exams', 'exams пользователя', fatal=False)
    print('\n== deep: /v2/users/LOGIN/exams ==')
    if isinstance(exams, dict) and '_error' in exams:
        print(exams['_error'])
    else:
        print(f'записей: {len(exams)}')
        for e in exams[:15]:
            print('  ', {k: e.get(k) for k in ('id', 'name', 'begin_at', 'end_at', 'project_id') if k in e})


def main():
    args = sys.argv[1:]
    deep = '--deep' in args
    args = [a for a in args if a != '--deep']
    token = None
    if len(args) == 2 and args[0] == '--file':
        if deep:
            sys.exit('--deep работает только с живым запросом (LOGIN), не с --file')
        with open(args[1], encoding='utf-8') as f:
            data = json.load(f)
    elif len(args) == 1 and not args[0].startswith('-'):
        token = get_token()
        data = fetch(args[0], token)
    else:
        sys.exit(__doc__)

    print('== курсы (cursus_users) ==')
    print('cursus_id | name | slug | level | begin | end')
    for cu in data.get('cursus_users') or []:
        c = cu.get('cursus') or {}
        print(' | '.join(str(x) for x in (
            cu.get('cursus_id'), c.get('name'), c.get('slug'), cu.get('level'),
            (cu.get('begin_at') or '')[:10], (cu.get('end_at') or '')[:10])))

    print('\n== проекты (все статусы) ==')
    print('раздел | slug | name | status | cursus_ids | validated | mark')
    rows = []
    for pu in data.get('projects_users') or []:
        p = pu.get('project') or {}
        rows.append((category(p.get('slug')), p.get('slug'), p.get('name'), pu.get('status'),
                     pu.get('cursus_ids'), pu.get('validated?'), pu.get('final_mark')))
    for r in sorted(rows, key=lambda r: (r[0], str(r[1]))):
        print(' | '.join(str(x) for x in r))

    if deep:
        deep_checks(args[0], token, data)


if __name__ == '__main__':
    main()
