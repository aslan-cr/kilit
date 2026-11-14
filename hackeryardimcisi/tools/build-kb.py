#!/usr/bin/env python3
"""Şikru'nun çevrimdışı Vikipedi bilgi tabanını üretir (src/main/assets/kb/00.gz .. ff.gz).

Kaynak: Türkçe Vikipedi arama dizini dökümü (CC BY-SA 4.0)
  https://dumps.wikimedia.org/other/cirrus_search_index/<tarih>/index_name=trwiki_content/

Kullanım:
  bzcat trwiki_content-*.json.bz2 | python3 build-kb.py extract > maddeler.jsonl
  python3 build-kb.py build ../src/main/assets/kb 45 maddeler.jsonl     # 45 = MB bütçe (gzip'li)

Parça biçimi ve anahtar kuralları WikiKb.java ile aynı olmak zorundadır.
"""
import sys, json, re, gzip, os, io

WS = re.compile(r'\s+')
MAXLEN = 480   # madde başına en fazla karakter (cümle sonunda kesilir)

FOLD = {'I': 'i', 'İ': 'i', 'ı': 'i', 'î': 'i', 'Î': 'i', 'Ç': 'c', 'ç': 'c', 'Ğ': 'g', 'ğ': 'g', 'Ö': 'o', 'ö': 'o',
        'Ş': 's', 'ş': 's', 'Ü': 'u', 'ü': 'u', 'û': 'u', 'Û': 'u', 'â': 'a', 'Â': 'a'}


def fold(s):
    out = []
    for c in s:
        o = FOLD.get(c)
        if o is None:
            if c == '̇':
                continue
            if 'A' <= c <= 'Z':
                o = c.lower()
            elif 'a' <= c <= 'z' or '0' <= c <= '9':
                o = c
            elif 127 < ord(c) <= 0xFFFF and (c.isalpha() or c.isdecimal()):
                o = c.lower()
                if len(o) != 1:
                    o = c
            else:
                o = ' '
        out.append(o)
    return ' '.join(''.join(out).split())


def shard_of(key):
    h = 0x811c9dc5
    for b in key.encode('utf-8'):
        h = ((h ^ b) * 0x01000193) & 0xffffffff
    return h & 0xff


def trim(t):
    t = t.replace('\t', ' ')
    if len(t) <= MAXLEN:
        return t
    cut = t[:MAXLEN]
    # son cümle sonunda kes (çok kısa kalmayacaksa)
    m = max(cut.rfind('. '), cut.rfind('! '), cut.rfind('? '))
    if m >= 160:
        return cut[:m + 1]
    sp = cut.rfind(' ')
    return cut[:sp if sp > 0 else MAXLEN] + '…'


def extract():
    out = sys.stdout
    for line in sys.stdin:
        if line.startswith('{"index"'):
            continue
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get('namespace') != 0:
            continue
        if any('Anlam ayrımı' in c for c in (d.get('category') or [])):
            continue
        t = d.get('opening_text') or ''
        if len(t) < 40:
            t = d.get('text') or ''
        t = WS.sub(' ', t).strip()
        if len(t) < 40:
            continue
        red = [r['title'] for r in (d.get('redirect') or []) if r.get('namespace') == 0]
        out.write(json.dumps([d['title'], t[:1500], d.get('popularity_score') or 0,
                              d.get('incoming_links') or 0, red], ensure_ascii=False))
        out.write('\n')


def build(out_dir, budget_mb, files):
    arts = []
    for f in files:
        with open(f, encoding='utf-8') as fh:
            for line in fh:
                title, text, pop, links, red = json.loads(line)
                arts.append((pop, links, title, trim(text), red))
    # en çok okunanlar önce; eşitlikte en çok bağlantı alan
    arts.sort(key=lambda a: (-a[0], -a[1], a[2]))
    print('aday madde:', len(arts), file=sys.stderr)

    # Bütçeyi tutturmak için sıkışma oranını örnekten ölç.
    sample = '\n'.join(a[3] for a in arts[::50]).encode('utf-8')
    ratio = len(gzip.compress(sample, 9)) / max(1, len(sample))
    budget = budget_mb * 1024 * 1024
    shards = [dict() for _ in range(256)]
    used = 0
    n_art = n_red = 0
    owner = {}
    for pop, links, title, text, red in arts:
        key = fold(title)
        if not key or key in owner:
            continue
        cost = (len(key) + len(title.encode()) + len(text.encode()) + 3) * ratio
        if used + cost > budget:
            break
        used += cost
        owner[key] = True
        shards[shard_of(key)][key] = (title, text)
        n_art += 1
        for r in red:
            rk = fold(r)
            if not rk or rk == key or rk in owner:
                continue
            owner[rk] = True
            shards[shard_of(rk)][rk] = ('', key)
            used += (len(rk) + len(key) + 3) * ratio * 1.6
            n_red += 1
    os.makedirs(out_dir, exist_ok=True)
    total = 0
    for i, sh in enumerate(shards):
        buf = io.BytesIO()
        with gzip.GzipFile(fileobj=buf, mode='wb', compresslevel=9, mtime=0) as g:
            for k in sorted(sh):
                g.write(('%s\t%s\t%s\n' % (k, sh[k][0], sh[k][1])).encode('utf-8'))
        data = buf.getvalue()
        total += len(data)
        with open(os.path.join(out_dir, '%02x.gz' % i), 'wb') as o:
            o.write(data)
    print('madde: %d  yönlendirme: %d  boyut: %.1f MB' % (n_art, n_red, total / 1048576), file=sys.stderr)


if __name__ == '__main__':
    if len(sys.argv) >= 2 and sys.argv[1] == 'extract':
        extract()
    elif len(sys.argv) >= 5 and sys.argv[1] == 'build':
        build(sys.argv[2], float(sys.argv[3]), sys.argv[4:])
    else:
        sys.exit(__doc__)
