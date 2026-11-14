package com.beranmeva.hackeryardimcisi;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.RandomAccessFile;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.zip.GZIPInputStream;
import java.util.zip.Inflater;

/**
 * Çevrimdışı Vikipedi bilgi tabanı. İki tür kaynak okur:
 *  - AssetSource: uygulamaya gömülü küçük taban (assets/kb/00.gz ... ff.gz), yalnızca madde girişleri.
 *    Satır: anahtar \t Başlık \t metin   |  anahtar \t \t hedefAnahtar (yönlendirme)
 *  - PackSource: telefona sonradan indirilen tam metin paketi (.skb), biçimi tools/build-kb.py içinde.
 * Anahtar = fold(başlık), parça = FNV-1a(anahtar) & (parçaSayısı-1).
 * Android'e bağımlı değildir.
 */
public final class WikiKb {

    public interface Opener { InputStream open(String name) throws Exception; }

    /** Bir kaynaktaki kayıt: madde (title dolu) ya da yönlendirme (target dolu). */
    static final class Entry {
        final String title, target;
        final Source src;
        final long blockPos; final int blockLen, off, len;
        final String text; // gömülü tabanda metin doğrudan burada
        Entry(String title, String target, Source src, String text, long bp, int bl, int off, int len) {
            this.title = title; this.target = target; this.src = src; this.text = text;
            this.blockPos = bp; this.blockLen = bl; this.off = off; this.len = len;
        }
    }

    public interface Source {
        Entry get(String key);
        /** [giriş, tam metin(veya null)] */
        String[] body(Entry e) throws Exception;
        String label();
        void close();
    }

    public static final class Hit {
        public final String title, intro, full, answer, source;
        Hit(String title, String intro, String full, String answer, String source) {
            this.title = title; this.intro = intro; this.full = full; this.answer = answer; this.source = source;
        }
        /** Ekranda gösterilecek kısa cevap: soruya uyan cümle varsa o, yoksa giriş. */
        public String text() { return answer != null ? answer : intro; }
    }

    private final List<Source> sources;

    public WikiKb(List<Source> sources) { this.sources = sources; }

    public void close() { for (Source s : sources) s.close(); }

    // ------------------------------------------------------------------ gömülü taban
    public static final class AssetSource implements Source {
        private final Opener opener;
        private final LinkedHashMap<Integer, Map<String, String[]>> cache =
            new LinkedHashMap<Integer, Map<String, String[]>>(8, 0.75f, true) {
                @Override protected boolean removeEldestEntry(Map.Entry<Integer, Map<String, String[]>> e) { return size() > 6; }
            };
        public AssetSource(Opener opener) { this.opener = opener; }

        private synchronized Map<String, String[]> shard(int n) {
            Map<String, String[]> m = cache.get(n);
            if (m != null) return m;
            m = new HashMap<>();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(
                    new GZIPInputStream(opener.open(String.format("kb/%02x.gz", n)), 1 << 16), StandardCharsets.UTF_8), 1 << 16)) {
                String line;
                while ((line = r.readLine()) != null) {
                    int a = line.indexOf('\t');
                    if (a < 0) continue;
                    int b = line.indexOf('\t', a + 1);
                    if (b < 0) continue;
                    m.put(line.substring(0, a), new String[] { line.substring(a + 1, b), line.substring(b + 1) });
                }
            } catch (Exception e) {
                // parça yoksa/bozuksa boş say
            }
            cache.put(n, m);
            return m;
        }

        @Override public Entry get(String key) {
            String[] v = shard(shardOf(key) & 0xff).get(key);
            if (v == null) return null;
            if (v[0].isEmpty()) return new Entry(null, v[1], this, null, 0, 0, 0, 0);
            return new Entry(v[0], null, this, v[1], 0, 0, 0, 0);
        }
        @Override public String[] body(Entry e) { return new String[] { e.text, null }; }
        @Override public String label() { return "off"; }
        @Override public void close() {}
    }

    // ------------------------------------------------------------------ tam metin paketi
    public static final class PackSource implements Source {
        private final RandomAccessFile f;
        private final int shards;
        private final long dataStart;
        private final long[] off;
        private final int[] len;
        private final String label;
        private final LinkedHashMap<Integer, Map<String, String>> cache =
            new LinkedHashMap<Integer, Map<String, String>>(64, 0.75f, true) {
                @Override protected boolean removeEldestEntry(Map.Entry<Integer, Map<String, String>> e) { return size() > 48; }
            };

        public PackSource(File file, String label) throws Exception {
            this.label = label;
            f = new RandomAccessFile(file, "r");
            byte[] magic = new byte[6];
            f.readFully(magic);
            if (!new String(magic, StandardCharsets.US_ASCII).equals("SKKB1\n")) { f.close(); throw new Exception("bozuk paket"); }
            shards = f.readInt();
            dataStart = f.readLong();
            if (shards <= 0 || shards > (1 << 20) || (shards & (shards - 1)) != 0) { f.close(); throw new Exception("bozuk paket"); }
            byte[] tab = new byte[shards * 12];
            f.readFully(tab);
            off = new long[shards];
            len = new int[shards];
            java.nio.ByteBuffer bb = java.nio.ByteBuffer.wrap(tab);
            for (int i = 0; i < shards; i++) { off[i] = bb.getLong(); len[i] = bb.getInt(); }
        }

        private synchronized byte[] read(long pos, int n) throws Exception {
            byte[] b = new byte[n];
            f.seek(pos);
            f.readFully(b);
            return b;
        }

        private Map<String, String> shard(int n) {
            synchronized (cache) {
                Map<String, String> m = cache.get(n);
                if (m != null) return m;
            }
            Map<String, String> m = new HashMap<>();
            try (BufferedReader r = new BufferedReader(new InputStreamReader(
                    new GZIPInputStream(new java.io.ByteArrayInputStream(read(off[n], len[n]))), StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) {
                    int a = line.indexOf('\t');
                    if (a > 0) m.put(line.substring(0, a), line.substring(a + 1));
                }
            } catch (Exception e) { /* boş say */ }
            synchronized (cache) { cache.put(n, m); }
            return m;
        }

        @Override public Entry get(String key) {
            String v = shard(shardOf(key) & (shards - 1)).get(key);
            if (v == null) return null;
            String[] p = v.split("\t", -1);
            if (p.length == 2 && p[0].isEmpty()) return new Entry(null, p[1], this, null, 0, 0, 0, 0);
            if (p.length != 5) return null;
            try {
                return new Entry(p[0], null, this, null, Long.parseLong(p[1]), Integer.parseInt(p[2]),
                    Integer.parseInt(p[3]), Integer.parseInt(p[4]));
            } catch (NumberFormatException e) { return null; }
        }

        @Override public String[] body(Entry e) throws Exception {
            byte[] comp = read(dataStart + e.blockPos, e.blockLen);
            Inflater inf = new Inflater(true);
            try {
                inf.setInput(comp);
                byte[] out = new byte[e.off + e.len];
                int n = 0;
                while (n < out.length && !inf.finished()) {
                    int k = inf.inflate(out, n, out.length - n);
                    if (k == 0 && (inf.needsInput() || inf.needsDictionary())) break;
                    n += k;
                }
                if (n < out.length) throw new Exception("kısa blok");
                String rec = new String(out, e.off, e.len, StandardCharsets.UTF_8);
                int sep = rec.indexOf('\u001f');
                String intro = sep >= 0 ? rec.substring(0, sep) : "";
                String rest = sep >= 0 ? rec.substring(sep + 1) : rec;
                String full = intro.isEmpty() ? rest : (rest.isEmpty() ? intro : intro + " " + rest);
                if (intro.isEmpty()) intro = firstSentences(full, 2);
                return new String[] { intro, full };
            } finally {
                inf.end();
            }
        }
        @Override public String label() { return label; }
        @Override public void close() { try { f.close(); } catch (Exception ignored) {} }
    }

    // ------------------------------------------------------------------ ortak kurallar
    /** Küçük harf + Türkçe harfleri sadeleştir + harf/rakam dışını boşluk yap. */
    public static String fold(String s) {
        StringBuilder b = new StringBuilder(s.length());
        boolean sp = true;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            char o;
            switch (c) {
                case 'I': case 'İ': case 'ı': case 'î': case 'Î': o = 'i'; break;
                case 'Ç': case 'ç': o = 'c'; break;
                case 'Ğ': case 'ğ': o = 'g'; break;
                case 'Ö': case 'ö': o = 'o'; break;
                case 'Ş': case 'ş': o = 's'; break;
                case 'Ü': case 'ü': case 'û': case 'Û': o = 'u'; break;
                case 'â': case 'Â': o = 'a'; break;
                case '̇': continue; // "İ" küçültülünce kalan birleşen nokta
                default:
                    if (c >= 'A' && c <= 'Z') o = (char) (c + 32);
                    else if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) o = c;
                    else if (c > 127 && Character.isLetterOrDigit(c)) o = Character.toLowerCase(c);
                    else o = ' ';
            }
            if (o == ' ') { if (!sp) { b.append(' '); sp = true; } }
            else { b.append(o); sp = false; }
        }
        int n = b.length();
        if (n > 0 && b.charAt(n - 1) == ' ') b.setLength(n - 1);
        return b.toString();
    }

    static int shardOf(String key) {
        int h = 0x811c9dc5;
        for (byte x : key.getBytes(StandardCharsets.UTF_8)) { h ^= (x & 0xff); h *= 0x01000193; }
        return h;
    }

    // Soru kalıpları ve dolgu sözcükleri (fold edilmiş hâlleriyle); konu aranırken atılır.
    private static final Set<String> STOP = new HashSet<>(Arrays.asList((
        "wiki viki vikipedi vikipedia wikipedia ara arat bul bilgi ver verir verin misin anlat anlatir acikla soyle soyler goster "
        + "nedir kimdir ne kim kimin kime kimi nerede neresi neresidir nereye nereden nerde nasil neden niye nicin hangi hangisi "
        + "kac kaci kadar zaman demek demektir denir anlami anlama gelir hakkinda ile ilgili konusunda olan olarak "
        + "mi mu midir mudur bir bu su o ve veya ya da de ki icin gibi daha en cok az bana bize sana lutfen sikru "
        + "var yok dir tir oldu olur olmus oluyor yapar yapilir eder edilir bilir biliyor musun misiniz sence peki acaba hadi "
        + "tane yil yilinda tarihinde kimler nelerdir neler").split(" ")));

    // Türkçe çekim ekleri (uzundan kısaya denenir).
    private static final String[] SUF = {
        "lerinden", "larindan", "lerinin", "larinin", "lerinde", "larinda", "lerine", "larina", "sinden", "sindan",
        "lerden", "lardan", "sinin", "sunun", "sinde", "sunda", "leri", "lari", "nden", "ndan", "nin", "nun", "nde", "nda",
        "den", "dan", "ten", "tan", "ler", "lar", "sin", "sun", "yla", "yle", "dir", "tir", "dur", "tur", "si", "su", "yi", "yu",
        "ye", "ya", "de", "da", "te", "ta", "in", "un", "ni", "nu", "ne", "na", "le", "la", "li", "lu", "i", "u", "e", "a", "n", "m"
    };

    /** Sözcüğün olası kök biçimleri (kendisi dahil değil), yakından uzağa. */
    static List<String> stems(String w) {
        LinkedHashSet<String> out = new LinkedHashSet<>();
        // kök çok kısalmasın: "başkanı" → "başkan" olur ama "bask" olmaz
        int min = w.length() <= 4 ? 2 : (w.length() * 6 + 9) / 10;
        List<String> level = new ArrayList<>();
        level.add(w);
        for (int round = 0; round < 2; round++) {
            List<String> next = new ArrayList<>();
            for (String x : level) {
                for (String s : SUF) {
                    if (x.length() - s.length() < min || !x.endsWith(s)) continue;
                    String st = x.substring(0, x.length() - s.length());
                    if (out.add(st)) next.add(st);
                    // yumuşama: kitab-ı → kitap, ağac-ı → ağaç(agac), köpeğ-i → köpek, kanad-ı → kanat
                    char last = st.charAt(st.length() - 1);
                    char hard = last == 'b' ? 'p' : last == 'g' ? 'k' : last == 'd' ? 't' : 0;
                    if (hard != 0) out.add(st.substring(0, st.length() - 1) + hard);
                }
            }
            level = next;
        }
        out.remove(w);
        return new ArrayList<>(out);
    }

    /** Sorudan dolgu sözcüklerini atıp konu sözcüklerini döndürür. */
    public static List<String> topicWords(String query) {
        List<String> out = new ArrayList<>();
        for (String w : fold(query).split(" ")) if (!w.isEmpty() && !STOP.contains(w)) out.add(w);
        return out;
    }

    /** Anahtarı tüm kaynaklarda arar (sıra önemli), yönlendirmeyi bir kez izler. */
    private Entry find(String key) {
        if (key.isEmpty()) return null;
        for (Source s : sources) {
            Entry e = s.get(key);
            if (e == null) continue;
            if (e.title != null) return e;
            for (Source t : sources) {
                Entry r = t.get(e.target);
                if (r != null && r.title != null) return r;
            }
        }
        return null;
    }

    private Hit hit(Entry e, List<String> rest, boolean num) {
        try {
            String[] b = e.src.body(e);
            String intro = clip(b[0], 600);
            String full = b[1] != null ? b[1] : b[0];
            return new Hit(e.title, intro, b[1], answer(full, rest, intro, num), e.src.label());
        } catch (Exception ex) {
            return null;
        }
    }

    /** Türkçe küçük harf, harf/rakam dışı boşluk; fold() ile aynı sözcük sınırları (harfler sadeleşmez). */
    static String lowerTr(String s) {
        StringBuilder b = new StringBuilder(s.length());
        boolean sp = true;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            char o;
            if (c == 'I') o = 'ı';
            else if (c == 'İ') o = 'i';
            else if (c == '\u0307') continue;
            else if (Character.isLetterOrDigit(c)) o = Character.toLowerCase(c);
            else o = ' ';
            if (o == ' ') { if (!sp) { b.append(' '); sp = true; } }
            else { b.append(o); sp = false; }
        }
        int n = b.length();
        if (n > 0 && b.charAt(n - 1) == ' ') b.setLength(n - 1);
        return b.toString();
    }

    /** Sorudaki sözcüklerin harfleri sadeleşmemiş hâli (topicWords ile aynı sırada). */
    static List<String> rawTopicWords(String query) {
        String[] f = fold(query).split(" "), r = lowerTr(query).split(" ");
        List<String> out = new ArrayList<>();
        if (f.length != r.length) return null;
        for (int i = 0; i < f.length; i++) if (!f[i].isEmpty() && !STOP.contains(f[i])) out.add(r[i]);
        return out;
    }

    /**
     * Serbest cümleden madde bul: en uzun sözcük öbeğinden başlar; her uzunlukta hem yazıldığı gibi hem de
     * son sözcüğün ekleri soyularak dener. Adayların içinden harfleri birebir tutan (ayın → Ay, Ayin değil;
     * derece → Derece, Dereçe değil) olan seçilir.
     */
    public Hit search(String query) {
        List<String> w = topicWords(query);
        if (w.isEmpty()) return null;
        List<String> raw = rawTopicWords(query);
        if (raw != null && raw.size() != w.size()) raw = null;
        if (w.size() > 8) { w = w.subList(0, 8); if (raw != null) raw = raw.subList(0, 8); }
        int n = w.size();
        for (int len = Math.min(n, 5); len >= 1; len--) {
            Entry best = null;
            int bestRank = Integer.MAX_VALUE, bestI = 0;
            for (int pass = 0; pass < 2; pass++) {
                for (int i = 0; i + len <= n; i++) {
                    String head = len > 1 ? String.join(" ", w.subList(i, i + len - 1)) + " " : "";
                    String last = w.get(i + len - 1);
                    if (len == 1 && last.length() < 2) continue;
                    String phrase = raw == null ? null : String.join(" ", raw.subList(i, i + len));
                    List<String> cands = pass == 0 ? java.util.Collections.singletonList(last) : stems(last);
                    for (String c : cands) {
                        Entry e = find(head + c);
                        if (e == null) continue;
                        // harfler birebir tutuyorsa (başlık sorudaki sözcüğün başı) öncelikli
                        boolean strict = phrase != null && phrase.startsWith(lowerTr(e.title)) && !lowerTr(e.title).isEmpty();
                        int rank = (strict ? 0 : 2) + pass;
                        if (rank < bestRank) { bestRank = rank; best = e; bestI = i; }
                        if (rank == 0) break;
                    }
                }
            }
            if (best != null) {
                List<String> rest = new ArrayList<>(w.subList(0, bestI));
                rest.addAll(w.subList(bestI + len, n));
                Hit h = hit(best, rest, wantsNumber(query));
                if (h != null) return h;
            }
        }
        return null;
    }

    /** Çevrimiçi okunan bir madde için de aynı cevap seçimi. */
    public static Hit online(String title, String full, String query) {
        String ft = fold(title);
        List<String> rest = new ArrayList<>();
        for (String x : topicWords(query)) {
            boolean inTitle = (" " + ft + " ").contains(" " + x + " ");
            if (!inTitle) for (String st : stems(x)) if ((" " + ft + " ").contains(" " + st + " ")) { inTitle = true; break; }
            if (!inTitle) rest.add(x);
        }
        String intro = clip(firstSentences(full, 3), 600);
        return new Hit(title, intro, full, answer(full, rest, intro, wantsNumber(query)), "on");
    }

    // ------------------------------------------------------------------ cevap seçimi
    private static final java.util.regex.Pattern SENT =
        java.util.regex.Pattern.compile("(?<=[.!?])\\s+(?=[\\p{Lu}0-9\"“'(])");

    static String firstSentences(String t, int k) {
        String[] s = SENT.split(t, k + 1);
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < Math.min(k, s.length); i++) { if (b.length() > 0) b.append(' '); b.append(s[i]); }
        return b.toString();
    }

    static String clip(String t, int max) {
        if (t == null) return "";
        if (t.length() <= max) return t;
        String cut = t.substring(0, max);
        int m = Math.max(cut.lastIndexOf(". "), Math.max(cut.lastIndexOf("! "), cut.lastIndexOf("? ")));
        if (m >= max / 3) return cut.substring(0, m + 1);
        int sp = cut.lastIndexOf(' ');
        return cut.substring(0, sp > 0 ? sp : max) + "…";
    }

    /**
     * Sorunun başlık dışında kalan sözcüklerini (ör. "başkenti", "nüfusu") madde metninde arar,
     * en çok sözcüğü içeren cümleyi döndürür. Uygun cümle yoksa ya da cümle zaten girişteyse null.
     */
    private static final java.util.regex.Pattern NUMQ =
        java.util.regex.Pattern.compile("(^| )(kac|kaci|kacinci|ne kadar|ne zaman|hangi yil|yilinda|tarihinde|nufusu|uzunlugu|yuksekligi|sicakligi|buyuklugu|uzakligi)( |$)");
    static final java.util.regex.Pattern DIGIT = java.util.regex.Pattern.compile("[0-9]");

    /** "kaç", "ne zaman", "nüfusu"... gibi sorularda sayı içeren cümle tercih edilir. */
    static boolean wantsNumber(String query) { return NUMQ.matcher(fold(query)).find(); }

    static String answer(String full, List<String> words, String intro, boolean num) {
        if (full == null || words.isEmpty()) return null;
        List<String[]> pats = new ArrayList<>();
        for (String w : words) {
            if (w.length() < 3) continue;
            List<String> p = new ArrayList<>();
            p.add(w);
            for (String s : stems(w)) if (s.length() >= 4) p.add(s);
            pats.add(p.toArray(new String[0]));
        }
        if (pats.isEmpty()) return null;
        String[] sent = SENT.split(full.length() > 400000 ? full.substring(0, 400000) : full);
        int best = -1, bestScore = 0;
        for (int i = 0; i < sent.length; i++) {
            String s = sent[i];
            if (s.length() < 15 || s.length() > 700) continue;
            String fs = " " + fold(s) + " ";
            int sc = 0;
            for (String[] p : pats) {
                for (String x : p) if (fs.contains(" " + x)) { sc += 2; break; }
            }
            if (sc > 0 && num && DIGIT.matcher(s).find()) sc++;
            if (sc > bestScore) { bestScore = sc; best = i; }
        }
        if (best < 0) return null;
        String a = sent[best];
        if (a.length() < 90 && best + 1 < sent.length && sent[best + 1].length() < 300) a = a + " " + sent[best + 1];
        if (intro != null && intro.contains(sent[best])) return null;
        return a;
    }
}
