#!/usr/bin/env python3
"""Şikru'nun çevrimdışı Vikipedi bilgi tabanını üretir (src/main/assets/kb/00.gz .. ff.gz).

Kaynak: Türkçe Vikipedi arama dizini dökümü (CC BY-SA 4.0)
  https://dumps.wikimedia.org/other/cirrus_search_index/<tarih>/index_name=trwiki_content/

Kullanım:
  bzcat trwiki_content-*.json.bz2 | python3 build-kb.py extract > maddeler.jsonl
  python3 build-kb.py build ../src/main/assets/kb 45 maddeler.jsonl     # 45 = MB bütçe (gzip'li)

Tam metin paketi (telefona sonradan inen, .github/workflows/vikipedi.yml üretir):
  bzcat <döküm>.json.bz2 | python3 build-kb.py extract-full > tam.jsonl
  python3 build-kb.py pack trwiki tam.jsonl        # trwiki-a.skb, trwiki-b.skb ... (her biri < 1,8 GB)

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


# ---------------------------------------------------------------------------
# Tam metin paketi (.skb): telefona sonradan indirilen büyük bilgi paketi.
# Biçim (büyük sonlu): "SKKB1\n" | u32 parça sayısı | u64 veri başlangıcı |
#   parça tablosu (u64 konum, u32 uzunluk) | gzip'li dizin blokları | veri blokları
# Dizin satırı: anahtar\tBaşlık\tblokKonumu\tblokUzunluğu\tblokİçiKonum\tuzunluk
#               anahtar\t\thedefAnahtar   (yönlendirme)
# Veri blokları ~64 KB'lık maddeler topluluğudur, ham deflate ile sıkıştırılır.
# Madde kaydı: giriş \x1f gövdenin geri kalanı (UTF-8). Okuyucu: PackKb (WikiKb.java).
# ---------------------------------------------------------------------------
import struct, zlib

PACK_SHARDS = 4096
BLOCK_RAW = 64 * 1024
FILE_CAP = 1800 * 1024 * 1024   # GitHub Release dosya sınırı 2 GB


def extract_full():
    """stdin: döküm satırları -> stdout: [başlık, giriş, tam metin, yönlendirmeler]"""
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
        if any(('Anlam ayrımı' in c) or ('Disambiguation pages' == c) for c in (d.get('category') or [])):
            continue
        t = WS.sub(' ', d.get('text') or '').strip()
        if len(t) < 40:
            continue
        o = WS.sub(' ', d.get('opening_text') or '').strip()
        red = [r['title'] for r in (d.get('redirect') or []) if r.get('namespace') == 0]
        out.write(json.dumps([d['title'], o, t, red, d.get('popularity_score') or 0], ensure_ascii=False))
        out.write('\n')


def pack_shard(key):
    h = 0x811c9dc5
    for b in key.encode('utf-8'):
        h = ((h ^ b) * 0x01000193) & 0xffffffff
    return h & (PACK_SHARDS - 1)


class PackWriter:
    def __init__(self, prefix):
        self.prefix = prefix
        self.n = 0
        self.names = []
        self._new()

    def _new(self):
        self.tmp = open(self.prefix + '.tmp', 'wb')
        self.pos = 0
        self.block = bytearray()
        self.pending = []      # (shard, key, title, off, ln) bu bloktakiler
        self.index = [[] for _ in range(PACK_SHARDS)]
        self.keys = set()
        self.count = 0

    def _flush_block(self):
        if not self.block:
            return
        c = zlib.compressobj(9, zlib.DEFLATED, -15)
        data = c.compress(bytes(self.block)) + c.flush()
        self.tmp.write(data)
        for sh, key, title, off, ln in self.pending:
            self.index[sh].append('%s\t%s\t%d\t%d\t%d\t%d' % (key, title, self.pos, len(data), off, ln))
        self.pos += len(data)
        self.block = bytearray()
        self.pending = []

    def add(self, title, intro, text, redirects):
        key = fold(title)
        if not key or key in self.keys:
            return
        title = title.replace('\t', ' ')
        if intro and text.startswith(intro):
            rest = text[len(intro):].strip()
        elif intro:
            rest = text
        else:
            rest = text
        rec = (intro.replace('\x1f', ' ') + '\x1f' + rest.replace('\x1f', ' ')).encode('utf-8')
        self.keys.add(key)
        self.pending.append((pack_shard(key), key, title, len(self.block), len(rec)))
        self.block += rec
        self.count += 1
        for r in redirects:
            rk = fold(r)
            if rk and rk not in self.keys:
                self.keys.add(rk)
                self.index[pack_shard(rk)].append('%s\t\t%s' % (rk, key))
        if len(self.block) >= BLOCK_RAW:
            self._flush_block()
            if self.pos >= FILE_CAP:
                self.close_file()
                self._new()

    def close_file(self):
        self._flush_block()
        self.tmp.close()
        if self.count == 0:
            os.remove(self.prefix + '.tmp')
            return
        blocks = []
        for lines in self.index:
            lines.sort()
            blocks.append(gzip.compress(('\n'.join(lines) + '\n').encode('utf-8'), 9, mtime=0))
        head = 6 + 4 + 8 + PACK_SHARDS * 12
        data_start = head + sum(len(b) for b in blocks)
        name = '%s-%c.skb' % (self.prefix, ord('a') + self.n)
        with open(name, 'wb') as o:
            o.write(b'SKKB1\n')
            o.write(struct.pack('>IQ', PACK_SHARDS, data_start))
            off = head
            for b in blocks:
                o.write(struct.pack('>QI', off, len(b)))
                off += len(b)
            for b in blocks:
                o.write(b)
            with open(self.prefix + '.tmp', 'rb') as t:
                while True:
                    chunk = t.read(1 << 24)
                    if not chunk:
                        break
                    o.write(chunk)
        os.remove(self.prefix + '.tmp')
        print('%s: %d madde, %.1f MB' % (name, self.count, os.path.getsize(name) / 1048576), file=sys.stderr)
        self.names.append(name)
        self.n += 1


def _rows(files):
    for f in files:
        op = gzip.open if f.endswith('.gz') else open
        with op(f, 'rt', encoding='utf-8') as fh:
            for line in fh:
                try:
                    row = json.loads(line)
                except Exception:
                    continue
                yield row[0], row[1], row[2], row[3], (row[4] if len(row) > 4 else 0)


def pack(prefix, files):
    # 1. tur: aynı anahtara düşen başlıklardan (".istanbul" / "İstanbul") en çok okunanı seç
    best = {}
    for title, _, _, _, pop in _rows(files):
        k = fold(title)
        if k and (k not in best or pop > best[k][0]):
            best[k] = (pop, title)
    owner = {k: v[1] for k, v in best.items()}
    best = None
    # 2. tur: yaz; yönlendirme adı başka bir maddenin başlığıysa o maddeye bırak
    w = PackWriter(prefix)
    for title, intro, text, red, _ in _rows(files):
        if owner.get(fold(title)) == title:
            w.add(title, intro, text, [r for r in red if fold(r) not in owner])
    w.close_file()


if __name__ == '__main__':
    if len(sys.argv) >= 2 and sys.argv[1] == 'extract':
        extract()
    elif len(sys.argv) >= 2 and sys.argv[1] == 'extract-full':
        extract_full()
    elif len(sys.argv) >= 4 and sys.argv[1] == 'pack':
        pack(sys.argv[2], sys.argv[3:])
    elif len(sys.argv) >= 5 and sys.argv[1] == 'build':
        build(sys.argv[2], float(sys.argv[3]), sys.argv[4:])
    else:
        sys.exit(__doc__)
