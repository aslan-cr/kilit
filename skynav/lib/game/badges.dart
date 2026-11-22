import '../services/notify_service.dart';
import '../services/store.dart';

class Badge {
  final String id, emoji, title, how;
  const Badge(this.id, this.emoji, this.title, this.how);
}

/// Hava durumu rozetleri. Kazanılanlar yerelde saklanır, kazanınca bildirim gösterilir.
class Badges {
  static const all = [
    Badge('first_lentil', '🔘', 'İlk Mercimek Karını Yakaladın', 'Mercimek karı varken gözlem butonuna bas.'),
    Badge('blizzard_nav', '🌨️', 'Tipide Bile Yolunu Buldun', 'Tipi ihtimali %40 üstündeyken bir rotayı bitir.'),
    Badge('calm_driver', '🧊', 'Buzlu Yolda Sakin Sürücü', 'Buzlanma riskinde 5 km+ rotayı kayma uyarısı almadan bitir.'),
    Badge('star_hunter', '⭐', 'Gece Yıldız Avcısı', 'Gece, yıldız netliği %60 üstündeyken bir takımyıldız hikâyesi dinle.'),
  ];
  static Set<String> get earned => ((Store.prefs.get('badges', defaultValue: <dynamic>[]) as List).cast<String>()).toSet();

  /// Yeni kazanıldıysa true.
  static Future<bool> award(String id) async {
    final e = earned;
    if (e.contains(id)) return false;
    e.add(id);
    await Store.put('badges', e.toList());
    final b = all.firstWhere((x) => x.id == id);
    await Notify.show('Yeni rozet ${b.emoji}', b.title);
    return true;
  }
}
