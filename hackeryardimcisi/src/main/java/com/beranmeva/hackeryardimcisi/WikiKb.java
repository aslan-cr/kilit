package com.beranmeva.hackeryardimcisi;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
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

/**
 * Çevrimdışı Vikipedi bilgi tabanı (assets/kb/00.gz ... ff.gz).
 * Her parça gzip'li metindir; satır biçimi:
 *   anahtar \t Başlık \t metin      (madde)
 *   anahtar \t \t hedefAnahtar      (yönlendirme)
 * Parça numarası = FNV-1a(anahtar) & 0xFF. Anahtar = fold(başlık).
 * Android'e bağımlı değildir; araç tarafındaki tools/build-kb.py ile aynı kuralları kullanır.
 */
public final class WikiKb {

    public interface Opener { InputStream open(String name) throws Exception; }

    public static final class Hit {
        public final String title, text;
        Hit(String title, String text) { this.title = title; this.text = text; }
    }

    private final Opener opener;
    // Son kullanılan birkaç parça bellekte tutulur.
    private final LinkedHashMap<Integer, Map<String, String[]>> cache =
        new LinkedHashMap<Integer, Map<String, String[]>>(8, 0.75f, true) {
            @Override protected boolean removeEldestEntry(Map.Entry<Integer, Map<String, String[]>> e) { return size() > 6; }
        };

    public WikiKb(Opener opener) { this.opener = opener; }

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
        return h & 0xff;
    }

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

    /** Tam anahtarla bak; yönlendirmeyi bir kez izler. */
    public Hit get(String key) {
        if (key.isEmpty()) return null;
        String[] v = shard(shardOf(key)).get(key);
        if (v == null) return null;
        if (v[0].isEmpty()) {
            v = shard(shardOf(v[1])).get(v[1]);
            if (v == null || v[0].isEmpty()) return null;
        }
        return new Hit(v[0], v[1]);
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

    /** Serbest cümleden madde bul: en uzun sözcük öbeğinden başlar, son sözcüğün eklerini soyarak dener. */
    public Hit search(String query) {
        List<String> w = topicWords(query);
        if (w.isEmpty()) return null;
        if (w.size() > 8) w = w.subList(0, 8);
        int n = w.size();
        for (int len = Math.min(n, 5); len >= 1; len--) {
            // önce yazıldığı gibi, sonra son sözcüğün ekleri soyularak
            for (int pass = 0; pass < 2; pass++) {
                for (int i = 0; i + len <= n; i++) {
                    String head = len > 1 ? String.join(" ", w.subList(i, i + len - 1)) + " " : "";
                    String last = w.get(i + len - 1);
                    if (len == 1 && last.length() < 2) continue;
                    if (pass == 0) {
                        Hit h = get(head + last);
                        if (h != null) return h;
                    } else {
                        for (String st : stems(last)) {
                            Hit h = get(head + st);
                            if (h != null) return h;
                        }
                    }
                }
            }
        }
        return null;
    }
}
