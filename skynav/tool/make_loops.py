#!/usr/bin/env python3
"""SkyNav doğa sesi döngüleri: orijinal CC0 kayıtlardan dikişsiz Ogg döngü üretir.

Kayıt içeriği değiştirilmez; yalnızca:
  1) 28 Hz altı uğultu süzülür,
  2) kaydın kendi baş/son kısılmaları (fade) kırpılır,
  3) son XF saniye ile ilk XF saniye eşit-güç geçişle bindirilir (dikişsiz döngü),
  4) ses −24 LUFS'a getirilir,
  5) tepeler GECİKMESİZ ve DAİRESEL bir limiter ile −1.5 dBTP altına çekilir
     (döngü sonu ile başı aynı kazançla işlenir; eski alimiter'in başa eklediği
     5 ms'lik sessizlik ve sınırdaki sıçrama böylece ortadan kalkar),
  6) Ogg Vorbis q3.

Kullanım: python3 tool/make_loops.py <orijinal_mp3_klasörü> <çıktı_klasörü>
Orijinaller: git show 4e71180~1:skynav/assets/audio/<ad>.mp3
"""
import json, os, subprocess, sys, tempfile
import numpy as np
from scipy.signal import resample_poly
from scipy.ndimage import minimum_filter1d, uniform_filter1d

SR = 48000
TARGET_LUFS = -24.0
THR_DBTP = -1.5
XF = 4.0  # sn
# Baş/son kırpma (sn): kayıtların kendi fade-in/fade-out bölümleri ölçülerek seçildi.
TRIM = {
    'campfire':     (0.05, 0.10),
    'forest_night': (0.80, 1.50),
    'rain_loop':    (1.00, 14.0),
    'waterfall':    (1.50, 15.0),
    'waves':        (0.05, 0.05),
}


def decode(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-af', 'highpass=f=28:poles=2',
                          '-ar', str(SR), '-ac', '2', '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def write_wav(path, y):
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(SR), '-ac', '2', '-i', '-',
                    '-c:a', 'pcm_f32le', path], input=y.astype(np.float32).tobytes(), check=True)


def lufs(y):
    with tempfile.NamedTemporaryFile(suffix='.wav') as t:
        write_wav(t.name, y)
        r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-i', t.name, '-af', 'ebur128=peak=true',
                            '-f', 'null', '-'], capture_output=True, text=True).stderr
    tail = r[r.rfind('Summary:'):]
    i = float(tail.split('I:')[1].split('LUFS')[0])
    tp = float(tail.split('Peak:')[1].split('dBFS')[0])
    return i, tp


def loop(x, xf):
    n = int(xf * SR)
    t = np.linspace(0, np.pi / 2, n, endpoint=False)[:, None]
    y = x[n:].copy()
    y[-n:] = x[-n:] * np.cos(t) + x[:n] * np.sin(t)
    return y


def true_peak_env(y):
    pad = 64
    z = np.concatenate([y[-pad:], y, y[:pad]])  # dairesel
    up = np.abs(resample_poly(z, 4, 1, axis=0)).max(axis=1)
    up = up[: (len(up) // 4) * 4].reshape(-1, 4).max(axis=1)[pad:pad + len(y)]
    return np.maximum(up, np.abs(y).max(axis=1))


def limit(y, thr_db):
    thr = 10 ** (thr_db / 20)
    r = np.minimum(1.0, thr / np.maximum(true_peak_env(y), 1e-9))
    w = int(0.015 * SR)
    g = minimum_filter1d(r, size=2 * w + 1, mode='wrap')
    g = uniform_filter1d(g, size=w, mode='wrap')  # g[n] <= r[n] her n için
    return y * g[:, None], float((1 - g).max())


def build(src, name, out_dir, q=3, thr_db=THR_DBTP):
    x = decode(src)
    h, t = TRIM[name]
    x = x[int(h * SR): len(x) - int(t * SR)]
    y0 = loop(x, XF)
    gain_db = 0.0
    for _ in range(4):
        y = y0 * 10 ** (gain_db / 20)
        y, red = limit(y, thr_db)
        i, _ = lufs(y)
        if abs(i - TARGET_LUFS) < 0.1:
            break
        gain_db += TARGET_LUFS - i
    out = os.path.join(out_dir, name + '.ogg')
    with tempfile.NamedTemporaryFile(suffix='.wav') as tw:
        write_wav(tw.name, y)
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', tw.name, '-c:a', 'libvorbis', '-q:a', str(q),
                        '-map_metadata', '-1', out], check=True)
    i, tp = lufs(decode_plain(out))
    if tp > -1.0 and thr_db > -4:  # Vorbis taşması: eşiği düşürüp yeniden dene
        return build(src, name, out_dir, q, thr_db - 0.5)
    return {'name': name, 'len_s': round(len(y) / SR, 2), 'gain_db': round(gain_db, 2), 'thr_db': thr_db,
            'max_reduction_db': round(-20 * np.log10(1 - red + 1e-12), 2), 'ogg_lufs': i, 'ogg_dbtp': tp}


def decode_plain(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)


if __name__ == '__main__':
    src_dir, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for name in TRIM:
        print(json.dumps(build(os.path.join(src_dir, name + '.mp3'), name, out_dir)))
