#!/usr/bin/env python3
"""Выгрузка проектов студента и проверка, в какой раздел их положит приложение.

Запуск из корня проекта (нужен .env с FT_UID и FT_SECRET; секреты НЕ печатаются):

    python3 tool/dump_projects.py LOGIN            # живой запрос к API 42
    python3 tool/dump_projects.py --file user.json # тот же разбор по сохранённому ответу

Что печатается:
  1. курсы студента (cursus_users): id, название, slug, уровень, даты;
  2. ВСЕ проекты (не только завершённые) с полями: раздел по правилам приложения,
     slug, название, статус, cursus_ids, validated, оценка.

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


CORE = load_core_slugs()


def norm(slug):
    s = slug.strip().lower()
    return s[len('42cursus-'):] if s.startswith('42cursus-') else s


def category(slug):
    if slug is None:
        return 'Outer'
    s = norm(slug)
    if 'piscine' in s and 'reloaded' in s:
        return 'Reloaded'
    if s.startswith('c-piscine') or s.startswith('piscine'):
        return 'Piscina'
    if s in CORE or re.fullmatch(r'cpp-module-\d{2}', s) or re.fullmatch(r'exam-rank-\d{2}', s):
        return 'Common'
    return 'Outer'


def fetch(login):
    env = load_env()
    body = urllib.parse.urlencode({
        'grant_type': 'client_credentials',
        'client_id': env['FT_UID'],
        'client_secret': env['FT_SECRET'],
    }).encode()
    token = http_json(urllib.request.Request(
        f'{API}/oauth/token', data=body, headers=HEADERS), 'получение токена')['access_token']
    return http_json(urllib.request.Request(
        f'{API}/v2/users/{urllib.parse.quote(login, safe="")}',
        headers={**HEADERS, 'Authorization': f'Bearer {token}'}), f'профиль {login}')


def http_json(req, what):
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        # Тело ответа сервера секретов не содержит (мы их не эхо-печатаем),
        # но обрезаем, чтобы не засорять вывод HTML-страницей Cloudflare.
        body = e.read(400).decode('utf-8', 'replace').replace('\n', ' ')
        sys.exit(f'Ошибка HTTP {e.code} при операции «{what}»: {body}')
    except urllib.error.URLError as e:
        sys.exit(f'Сеть недоступна при операции «{what}»: {e.reason}')


def main():
    args = sys.argv[1:]
    if len(args) == 2 and args[0] == '--file':
        with open(args[1], encoding='utf-8') as f:
            data = json.load(f)
    elif len(args) == 1 and not args[0].startswith('-'):
        data = fetch(args[0])
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


if __name__ == '__main__':
    main()
