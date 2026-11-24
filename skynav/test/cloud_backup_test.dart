import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynav/services/cloud_backup.dart';
import 'package:skynav/services/shared_state.dart';
import 'package:skynav/services/store.dart';

String cap(String t, String note) => jsonEncode({'t': t, 'place': 'Erzurum', 'temp': -3, 'note': note});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('birleştirme: cihazdaki kazanır, hiçbir şey silinmez, yeni gelenler sayılır', () {
    final local = {
      'places': {'Evim': '{"lat":1}', 'İş': '{"lat":2}'},
      'badges': ['first_lentil'],
      'capsules': [cap('2026-02-01T10:00:00', 'b')],
      'xp': {'xp_Gök & Ay': 3},
      'prefs': {'plain_lang': false},
      'sp': {'sn_brief_hour': 8},
      'selfcheck': [{'t': 2, 'pred': 'snow'}],
    };
    final cloud = {
      'places': {'Evim': '{"lat":9}', 'Anneannem': '{"lat":3}'},
      'badges': ['first_lentil', 'star_hunter'],
      'capsules': [cap('2026-01-01T10:00:00', 'a'), cap('2026-02-01T10:00:00', 'b')],
      'xp': {'xp_Gök & Ay': 7, 'xp_İklim': 2},
      'prefs': {'plain_lang': true, 'muted': true},
      'sp': {'sn_brief_hour': 6, 'sn_frost_off': true},
      'selfcheck': [{'t': 1, 'pred': 'rain'}, {'t': 2, 'pred': 'snow'}],
    };
    final (m, r) = CloudBackup.merge(local, cloud);
    expect((m['places'] as Map).keys.toSet(), {'Evim', 'İş', 'Anneannem'});
    expect((m['places'] as Map)['Evim'], '{"lat":1}'); // cihazdaki kazanır
    expect(m['badges'], ['first_lentil', 'star_hunter']);
    expect((m['capsules'] as List).length, 2);
    expect((jsonDecode((m['capsules'] as List).first as String) as Map)['note'], 'a'); // zamana göre sıralı
    expect((m['xp'] as Map)['xp_Gök & Ay'], 7);
    expect((m['xp'] as Map)['xp_İklim'], 2);
    expect((m['prefs'] as Map)['plain_lang'], false);
    expect((m['prefs'] as Map)['muted'], true);
    expect((m['sp'] as Map)['sn_brief_hour'], 8);
    expect((m['sp'] as Map)['sn_frost_off'], true);
    expect((m['selfcheck'] as List).map((e) => (e as Map)['t']).toList(), [1, 2]);
    expect((r.places, r.badges, r.capsules), (1, 1, 1));
    expect(r.text, 'Yedeğin geri geldi: 1 yer, 1 rozet, 1 kapsül.');
    // Boş bulut: değişiklik yok
    final (m2, r2) = CloudBackup.merge(local, const {});
    expect((m2['places'] as Map).length, 2);
    expect(r2.any, isFalse);
  });

  test('sil-yükle: yedek alınır, telefon sıfırlanır, aynı hesapla geri gelir', () async {
    final dir = await Directory.systemTemp.createTemp('skynav_backup');
    SharedPreferences.setMockInitialValues({'sn_brief_hour': 6, 'sn_sky_off': true});
    await SharedState.init();
    await Store.init(testPath: dir.path);
    await Store.places.put('Evim', '{"name":"Evim","lat":39.9,"lon":41.27}');
    await Store.places.put('Anneannem', '{"name":"Anneannem","lat":39.95,"lon":41.1}');
    await Store.put('badges', ['first_lentil']);
    await Store.put('capsules', [cap('2026-01-01T10:00:00', 'ilk kar')]);
    await Store.put('plain_lang', true);
    await Store.put('mixer_last', {'rain': .6, 'fire': .3});
    await Store.put('bias_c', .4);
    await Store.put('xp_İklim', 4);
    await Store.selfcheck.add({'t': 1, 'pred': 'snow', 'real': 'snow', 'temp': double.nan, 'wb': null});

    // Buluta giden metin JSON'a uygun olmalı (NaN yok)
    final backup = jsonEncode(CloudBackup.collect());
    expect(backup, contains('Anneannem'));
    expect(backup, isNot(contains('NaN')));

    // Uygulama silindi: yerel her şey boş
    await Hive.deleteFromDisk();
    await Hive.close();
    final dir2 = await Directory.systemTemp.createTemp('skynav_backup2');
    await (await SharedState.get()).clear();
    await Store.init(testPath: dir2.path);
    expect(Store.places.isEmpty, isTrue);

    // Aynı Gmail ile giriş → geri yükleme
    final (merged, r) = CloudBackup.merge(CloudBackup.collect(), (jsonDecode(backup) as Map).cast<String, dynamic>());
    await CloudBackup.apply(merged);
    expect(r.places, 2);
    expect(Store.places.keys.toSet(), {'Evim', 'Anneannem'});
    expect(Store.prefs.get('badges'), ['first_lentil']);
    expect((Store.prefs.get('capsules') as List).length, 1);
    expect(Store.prefs.get('plain_lang'), true);
    expect((Store.prefs.get('mixer_last') as Map)['rain'], .6);
    expect(Store.prefs.get('bias_c'), .4);
    expect(Store.prefs.get('xp_İklim'), 4);
    expect(Store.selfcheck.length, 1);
    final sp = await SharedState.get();
    expect(sp.getInt('sn_brief_hour'), 6);
    expect(sp.getBool('sn_sky_off'), true);
    expect(sp.getDouble('sn_bias'), .4); // arka plan görevi için

    // İkinci kez uygulamak çoğaltmaz
    final (again, r2) = CloudBackup.merge(CloudBackup.collect(), (jsonDecode(backup) as Map).cast<String, dynamic>());
    await CloudBackup.apply(again);
    expect(r2.any, isFalse);
    expect(Store.selfcheck.length, 1);
    await Hive.close();
  });
}
