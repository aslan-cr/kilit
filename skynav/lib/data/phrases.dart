// Sokak ağzında, samimi 'kanki' tarzı hazır metinler. Saf Dart (Flutter bağımlılığı yok).

class Kanki {
  /// Listeden seed'e göre deterministik bir cümle seçer.
  static String pick(List<String> l, int seed) {
    if (l.isEmpty) return '';
    final n = l.length;
    return l[((seed % n) + n) % n];
  }

  // ---------------------------------------------------------------- hava

  static const List<String> normalKar = [
    'Normal kar yağıyor kanki, yollar beyaz ama gidilir, sakin sür.',
    'Kar tane tane iniyor, manzara süper ama lastiklerin yolunda olsun.',
    'Bugün normal bir kar günü kanki, kaymaya karşı biraz mesafe bırak.',
    'Kar yağışı orta şiddette kanki, çay demle, pencereden izle keyfini.',
    'Yerler hafif karlı, frenlerde acele etme, yavaş ve düzgün git.',
    'Kar düzgün yağıyor kanki, farları yak, camları temiz tut ki görüş net kalsın.',
    'Normal kış şartları işte kanki, sabırlı ol, yol bir süre sonra açılır.',
    'Kar güzel ama yolda beyaz bir tabaka oluşabilir, virajda gazı kes ve yumuşak dön.',
    'Kar yağarken yanında battaniye ve şarjlı telefon bulundur kanki, her ihtimale hazır ol.',
  ];

  static const List<String> mercimekKari = [
    'Mercimek kar yağıyor kanki, küçük tanecikler camda sekiyor.',
    'Bu kar sert ve tanecikli, yere çarpınca zıplıyor, görüşü biraz bozabilir.',
    'Mercimek kar birikmeden çabuk erir ama yolu bir anda kaygan yapabilir.',
    'Tanecikli kar yağışı var kanki, silecekleri kontrol et, suyunu doldur.',
    'Görüş biraz düşük, farları açık tut ve önündeki araçla aranı biraz aç.',
    'Mercimek kar çok sert değil ama camı kumlar gibi döver, yavaş git.',
    'Kar taneleri küçük ve sert kanki, gözlüğünü tak ki yüzüne vurmasın.',
    'Bu yağış hafif görünür ama yolda sürpriz yapabilir, direksiyonu sıkı tutma.',
    'Mercimek kar geçici olabilir kanki, bir sonraki saati takipte kal.',
  ];

  static const List<String> tipi = [
    'Tipi var kanki, görüş birkaç metreye düştü, yola çıkmak riskli.',
    'Tipi her an şiddetlenebilir, mümkünse yolculuğu ertele.',
    'Beyaz perde yolu kapatıyor kanki, yol kenarını ve çizgileri takip etmek zor.',
    'Rüzgar karı savuruyor, araç içinde kalmak daha güvenli, sakin kal.',
    'Tipide yolda kalırsan motoru uzun süre boşa çalıştırma, egzoz tıkanabilir.',
    'Tipi geçene kadar kenara çekip flaşörleri aç, önce güvenliği düşün kanki.',
    'Yolun ne kadar açık olduğunu görmek imkansız, hız yapmadan ilerlemeye bak.',
    'Acil durumda 112 aramayı unutma kanki, konumunu net bildir.',
    'Tipi sakinleşince gel, bu hava kimseyle şaka yapmaz kanki.',
  ];

  static const List<String> karlaKarisikYagmur = [
    'Kar ile yağmur karışık yağıyor kanki, yol hem ıslak hem kaygan.',
    'Yağmur kara karışınca yüzey buz gibi oluyor, frenlere sabır lazım.',
    'Kar eriyor ama altı donabilir, köprü ve virajlarda ekstra dikkat.',
    'Islak kar lastiğe yapışıyor kanki, şerit değiştirmeden düz git.',
    'Silecekleri açık tut, kar ve su karışımı camı çabuk kapatıyor.',
    'Karla karışık yağmurda takip mesafeni iki katına çıkar kanki.',
    'Bu hava sinsi, yüzey sıcak görünse de altında buz olabiliyor.',
    'Yavaş ve yumuşak sür, gaza ve frene sert basma.',
    'Yol ıslak görünse de tam kaygan olabilir, dikkatli ol kanki.',
  ];

  static const List<String> yagmur = [
    'Yağmur yağıyor kanki, yollar ıslak, fren mesafeni biraz aç.',
    'Islak yolda kayma olabilir, virajlarda gazı yavaşça kes.',
    'Yağmur iyi, ama silecekler sağlam mı bir kontrol et.',
    'Su birikintilerine dikkat, su kaymasına girmemek için hızı düşür.',
    'Farlarını yak, hem görüş hem görünürlük için iyi olur.',
    'Yağmur sürekli değil ama yol her an kayganlaşabilir, sabırlı sür.',
    'Kaldırım kenarından geçerken dikkat et kanki, ıslak zeminde yaya çıkabilir.',
    'Yağmurda tempo tutturmak güzel ama acele etme, sakin sür.',
    'Yağmurlu havada her şey yavaş olsun kanki, erken frenle ve geniş dön.',
  ];

  static const List<String> acik = [
    'Hava açık kanki, güneş yolu ısıtıyor, keyfini çıkar.',
    'Görüş mükemmel, yollar kuru, rahat sürüş zamanı.',
    'Gökyüzü berrak, mola verip manzaranın tadını çıkarabilirsin.',
    'Hava tertemiz kanki, uzaktaki dağlar bile net görünüyor.',
    'Açık havada bile rüzgar esebilir, direksiyonda dikkatli ol.',
    'Yollar kuru ve temiz, hızını kontrollü tut ve keyfini çıkar.',
    'Bugün güzel bir gün kanki, yolculukta güneş gözlüğünü unutma.',
    'Hava sıcak ama konforlu, su almayı unutma ve arada mola ver.',
    'Güneş de yıldızlar da keyifli, kendini rahat hisset kanki.',
  ];

  /// Açık gündüz (sıcaklıktan bağımsız, güneşe uygun).
  static const List<String> acikGunduz = [
    'Hava açık kanki, gökyüzü masmavi, keyfini çıkar.',
    'Gökyüzü berrak, uzaktaki dağlar bile net görünüyor.',
    'Bugün güzel bir gün kanki, güneş gözlüğünü yanına al.',
    'Pırıl pırıl bir gökyüzü var, dışarı çıkmak için iyi zaman.',
  ];

  /// Açık gece.
  static const List<String> acikGece = [
    'Gökyüzü açık kanki, yıldızlar seni bekliyor.',
    'Bulut yok, gece berrak; başını kaldır, yıldızlara bak.',
    'Açık bir gece kanki, hava serinler, üstünü sıkı tut.',
    'Gece tertemiz, Ay ve yıldızlar sahnede kanki.',
  ];

  static const List<String> bulutlu = [
    'Hava bulutlu kanki, güneş yok ama görüş fena değil.',
    'Gökyüzü kapalı, hava biraz serin, üstüne bir şey al.',
    'Bulutlar yoğun, yağış çıkabilir, planını buna göre yap.',
    'Bulutlu hava moralini bozmasın kanki, yol açık ve sakin.',
    'Işık az olabilir, farlarını kontrol et, özellikle akşam üstü.',
    'Bulutlu ama kuru bir gün, rahat sürebilirsin, yine de dikkat lazım.',
    'Gökyüzü gri, yüzeyde ince bir nem olabilir, hızını ayarla.',
    'Bulutların arasından güneş çıkabilir kanki, hava hızlı değişebilir.',
    'Yağış ihtimali var, yanında şemsiye ya da yağmurluk bulundur.',
  ];

  // ---------------------------------------------------------------- sis

  /// 0-14 arası sis yoğunluğu.
  static const List<String> _sisHafifYok = [
    'Sis yok denecek kadar kanki, rahat ol.',
    'Hava pırıl pırıl, sis derdi yok, keyfine bak.',
    'Görüş çok iyi kanki, yine de farlarını kontrol et.',
    'Ufukta bir sis izi bile yok, yol açık.',
    'Hava temiz, sisin adı bile geçmiyor bugün kanki.',
    'Görüş tam, rahat sürebilirsin, hızını yine de dengede tut.',
    'Sis ihtimali çok düşük, bu güzel bir haber kanki.',
    'Göz rahat, yol net, sadece bir bakış daha at.',
    'Sis falan yok, bu yol sana tatil gibi gelsin kanki.',
  ];

  /// 15-29 arası.
  static const List<String> _sisHafif = [
    'Eh işte biraz sisli kanki, ağzın nemlendi',
    'Hafif bir sis var kanki, uzağı biraz bulanık görünüyor.',
    'Sis ince bir perde gibi, farları yakmayı düşün.',
    'Görüş hâlâ iyi ama uzak mesafeler biraz silik kanki.',
    'Hafif sis yüzünü ıslatıyor, camı da nemlendiriyor.',
    'Sis çok yoğun değil ama virajlarda dikkatli olmak lazım.',
    'Sis hafif kanki, bir de rüzgar varsa daha da inceliyor.',
    'Yolun ufak bir bölümünde sis kalınlaşabilir, hızını ayarla.',
    'Biraz sisli, sakin git, önündekine de yer bırak kanki.',
  ];

  /// 30-49 arası.
  static const List<String> _sisOrta = [
    'Sis orta seviyede kanki, görüş biraz düştü, hız düşür.',
    'Uzağı görmek zorlaşıyor, farlarını yak ve takip mesafeni aç.',
    'Sis kalınlaşıyor, şeritleri takip etmeye dikkat et.',
    'Orta yoğunlukta sis var, düz yolda bile temkinli sür.',
    'Görüş azalıyor kanki, önündeki araca çok yaklaşma.',
    'Sisli havada sürüş yorucu olur, molalarını ihmal etme.',
    'Bu sis seni yavaşlatacak, acelen varsa biraz pay bırak.',
    'Sisli bölgelerde sis lambası işe yarar ama düşük ışığı kullan.',
    'Sis yoğunlaşıyor kanki, ani fren ve sert manevra yerine sakin ilerle.',
  ];

  /// 50-69 arası.
  static const List<String> _sisYogun = [
    'Sis epey yoğun kanki, görüş sınırlı, dikkatli sür.',
    'Görüş belirgin şekilde düştü, hızını ciddi biçimde düşür.',
    'Sis yüzünden yol kenarı ve şeritler zor seçiliyor, odaklan.',
    'Sisin içinde kalmak yorucu, gerekirse güvenli bir yerde mola ver.',
    'Ön aracın farlarını takip ederek ilerle ama aşırı yaklaşma.',
    'Yoğun siste sollama yapma kanki, manevra alanın yok.',
    'Sisli havada uzun far kullanma kanki, ışık sise çarpıp geri döner, kısa far daha iyi.',
    'Sis yoğunlaştıkça tempo düşmeli, hem kendini hem diğerlerini koru.',
    'Sisin içinde kalmak riskli, mümkünse ilerleyen sisi bekle.',
  ];

  /// 70-84 arası.
  static const List<String> _sisCokYogun = [
    'Sis çok yoğun kanki, görüş birkaç on metreye indi.',
    'Yol neredeyse kayboluyor, ilerlemek yerine güvenli bir noktaya çekil.',
    'Bu seviyede sürmek ciddi risk, mümkünse dur ve bekle kanki.',
    'Tehlike flaşörünü yak, güvenli bir yere çekilip sis geçene kadar bekle.',
    'Ön ve arkadaki araçlar seni göremiyor olabilir, dikkatli ol.',
    'Sis içinde hız yapmak hayatı tehlikeye atar kanki, yavaş ol.',
    'Görüş çok düşük, yolda kalmamak için çekilmek en mantıklı seçenek.',
    'Bu sisle devam etmek yerine durup beklemek akıllıca olur kanki.',
    'Sis bu kadar kalınken yola devam etmek bence iyi bir fikir değil kanki.',
  ];

  /// 85-100 arası.
  static const List<String> _sisAsiri = [
    'Göz gözü görmüyor kanki, ne oluyor?!',
    'Sis her şeyi yutmuş, yolu görmek neredeyse imkansız.',
    'Bu yoğunlukta sürmek çok tehlikeli, derhal güvenli bir yere çekil.',
    'Tehlike flaşörünü yak, güvenli bir yere yavaşça çekil ve dur.',
    'Kendini ve yanındakileri korumak için yolda kalma, uygun yere çık.',
    'Durursan egzoz borusunun tıkanmadığından emin ol kanki, karbon monoksit riski var.',
    'Acil bir durum olursa 112 aranabilir, konumunu net bildirmeyi unutma.',
    'Görüş sıfıra yakın, bu sürüş değil kanki, ilk fırsatta güvenli yere çekil.',
    'Sis geçmeden yola çıkma kanki, bu hava pazarlık kabul etmez.',
  ];

  /// 6 kademeli sis metinleri: 0-14, 15-29, 30-49, 50-69, 70-84, 85-100.
  static const List<List<String>> _sisKademeleri = [
    _sisHafifYok,
    _sisHafif,
    _sisOrta,
    _sisYogun,
    _sisCokYogun,
    _sisAsiri,
  ];

  /// Sis yoğunluğu 0-100 arası; 6 kademeden birini seed ile seçer.
  static String sisKademeli(double density0to100, int seed) {
    final d = density0to100.clamp(0.0, 100.0).toDouble();
    final int idx = d < 15
        ? 0
        : d < 30
            ? 1
            : d < 50
                ? 2
                : d < 70
                    ? 3
                    : d < 85
                        ? 4
                        : 5;
    return pick(_sisKademeleri[idx], seed);
  }

  // ---------------------------------------------------------------- yıldız / dağ

  static const String yildizKapali =
      'Yıldız Görünümü: %0 (Gökyüzü kapalı, bugün yıldız yok kanki)';

  static const List<String> _yildizDusuk = [
    'Yıldızlar bulutların arkasında kalmış kanki, zor seçiliyor.',
    'Gökyüzü loş, sadece birkaç parlak nokta görünüyor.',
    'Yıldızlar silik, gökyüzü tam açılmamış kanki.',
    'Bulutlar yer yer açılıyor ama çoğu yıldız saklanıyor.',
    'Yıldız avı biraz zor bugün, sabırlı bak.',
    'Gökyüzü yarı yarıya kapalı gibi, parlak olanları seçebilirsin.',
    'Yıldız gözlemi için çok ideal değil ama bir şeyler görünür.',
    'Hava nemli, yıldızlar puslu görünüyor kanki.',
    'Biraz sabırla gökyüzü açılabilir, belki birkaç ışık daha çıkar.',
  ];

  static const List<String> _yildizOrta = [
    'Yıldızlar güzel görünüyor kanki, birkaç parlak nokta net.',
    'Gökyüzü orta düzeyde açık, takımyıldızlar seçilebiliyor.',
    'Bulutlar dağılmış, yıldız şöleni başlıyor kanki.',
    'Çoğu yıldız görünüyor ama Samanyolu biraz silik olabilir.',
    'Gökyüzü yeterince açık, uzaktaki parlaklar da seçilebiliyor.',
    'Yıldızlar sakin ve net, bir mola verip bakmaya değer.',
    'Hava iyi, birkaç bulut var ama gökyüzü büyük ölçüde açık.',
    'Yıldızlar hoş bir ışık saçıyor kanki, keyfini çıkar.',
    'Gökyüzü kısmen temiz, en parlak yıldızlar rahatça görünür.',
  ];

  static const List<String> _yildizYuksek = [
    'Gökyüzü tertemiz kanki, yıldız şov resmen!',
    'Yıldızlar pırıl pırıl, Samanyolu bile net görünüyor.',
    'Bulut yok denecek kadar az, gökyüzü berrak ve geniş.',
    'Yıldız gözlemi için harika bir gece kanki, sakin bak.',
    'Gökyüzü dupduru, uzak yıldızlar bile net seçiliyor.',
    'Tertemiz bir gece, manzarayı ve yıldızları tam keyfiyle izle.',
    'Her yer yıldız dolu kanki, kafanı kaldır ve bak.',
    'Hava çok net, gökyüzü sanki yıldızla boyanmış gibi.',
    'Bu gece yıldızlar kendini gösteriyor, kaçırma kanki.',
  ];

  /// Yıldız görünürlüğü 0-100 (berraklık); metni yüzdeyle birlikte döner.
  static String yildizAcik(double clarity) {
    final c = clarity.clamp(0.0, 100.0).toDouble();
    final List<String> l = c < 40
        ? _yildizDusuk
        : c < 75
            ? _yildizOrta
            : _yildizYuksek;
    return 'Yıldız Görünümü: %${c.round()} (${pick(l, c.round())})';
  }

  static const List<String> _dagDusuk = [
    'Dağ etkisi zayıf kanki, hava büyük ölçüde düz gidiyor.',
    'Dağların hava üzerindeki etkisi az, sürpriz beklemene gerek yok.',
    'Yamaçlar fazla etkilenmiyor, hava genel olarak sakin.',
    'Dağlar bu hesapta pek rol oynamıyor kanki, düzlük hakim.',
    'Dağ kaynaklı yağış beklenmiyor, sadece genel hava şartları var.',
    'Dağ etkisi neredeyse yok kanki, yol düzlüğünde sakin sür.',
    'Yamaçlarda ekstra bir hareket görünmüyor, rahat ol.',
    'Dağlar havayı çok zorlamıyor, normal şartlarda ilerle.',
    'Dağ desteği düşük olduğu için tahminler genel hava durumuna yakın.',
  ];

  static const List<String> _dagOrta = [
    'Dağlar havayı bir miktar yukarı itiyor, yağışı biraz artırabilir.',
    'Dağ etkisi orta düzeyde kanki, yamaçlarda hava biraz değişebilir.',
    'Yamaç kesimlerinde yağış biraz daha belirgin olabilir.',
    'Dağlar hava akımını kısmen yönlendiriyor, tepelerde dikkat et.',
    'Dağ kaynaklı bulut oluşumu olabilir kanki, manzara değişken olur.',
    'Yüksek kesimlerde hava daha soğuk olabilir, buna göre giyin.',
    'Dağlar havayı hafif zorluyor, yamaçlarda ani değişim görülebilir.',
    'Tepe bölgelerinde hava hızlı değişebilir kanki, planını esnek tut.',
    'Dağ etkisi var ama kontrollü, yine de yamaçlara dikkat et.',
  ];

  static const List<String> _dagYuksek = [
    'Dağlar havayı zorluyor kanki, yamaçlarda yağış ve kar birikimi belirgin olabilir.',
    'Dağ etkisi güçlü, tepelerde hava çok hızlı değişebilir.',
    'Yamaçlarda kar birikimi artabilir kanki, yolda ekstra dikkat lazım.',
    'Dağ kaynaklı yoğun bulut ve yağış ihtimali yüksek, planını buna göre yap.',
    'Yüksek kesimlerde görüş ve sıcaklık ani değişebilir kanki.',
    'Dağlar hava akımını sert şekilde yukarı itiyor, rüzgar da sertleşebilir.',
    'Tepe ve yamaç kesimleri en çok etkilenecek yerler kanki.',
    'Dağ bölgesinde yol durumu hızlı değişebilir, güncel durumu takip et.',
    'Bu kadar güçlü dağ etkisinde dağ yolunu tercih etmeden önce iyi düşün kanki.',
  ];

  /// Dağ desteği 0-100; metni yüzdeyle birlikte döner.
  static String dagDestegi(double pct) {
    final p = pct.clamp(0.0, 100.0).toDouble();
    final List<String> l = p < 34
        ? _dagDusuk
        : p < 67
            ? _dagOrta
            : _dagYuksek;
    return 'Dağ Desteği: %${p.round()} (${pick(l, p.round())})';
  }

  // ---------------------------------------------------------------- uyarılar

  static const List<String> tipiUyari = [
    'Tipi uyarısı kanki, rüzgar ve kar birlikte görüşü kapatabilir.',
    'Tipi bölgesine girme planın varsa lütfen bir daha düşün.',
    'Yolda tipi başlarsa hemen güvenli bir yere çekil ve bekle.',
    'Tipi sürücüleri şaşırtır kanki, yol kenarını tamamen kaybedebilirsin.',
    'Bu uyarı ciddi, zorunlu olmadıkça yola çıkma.',
    'Tipi sırasında kar kalınlaşıp yolu kapatabilir, bunu gözden kaçırma.',
    'Rüzgar kuvvetliyken savrulan kar yüzünden görüş saniyeler içinde değişir.',
    'Yolun kapanma ihtimali var kanki, yol durumunu kontrol etmeden ilerleme.',
    'Tipi bitene kadar sabırlı ol, sakin kalmak en büyük güvenlik kanki.',
  ];

  static const List<String> yazSicak = [
    'Hava çok sıcak kanki, bol su iç ve gölgede dinlen.',
    'Yaz sıcağı yorucu olabilir, aracın klimasını kontrol et.',
    'Araç içi çabuk ısınır, çocuk ve hayvanları kapalı araçta bırakma.',
    'Öğle saatlerinde güneş çok kuvvetli, şapka ve güneş kremi şart kanki.',
    'Sıcakta dikkatli sür, lastik basıncı da sıcakla değişebilir.',
    'Uzun yolda kısa molalar ver, bedenini dinlendir kanki.',
    'Sıcak hava motoru zorlayabilir, soğutma suyunu kontrol et.',
    'Bu sıcağı tek başına göğüslemeye çalışma, yanında su bulundur.',
    'Sıcak bir gün kanki, serinlemek için bol su ve gölge şart.',
  ];

  static const List<String> asiriSicak = [
    'Aşırı sıcak uyarısı kanki, bu hava ciddi sağlık riski taşıyabilir.',
    'Sıcaklık çok yüksek, mümkünse öğle saatlerinde yola çıkma.',
    'Aşırı sıcakta susuzluk ve güneş çarpması çok hızlı gelebilir, su al.',
    'Araç içi sıcaklık hızla yükselir, asla içeride kimseyi bırakma.',
    'Lastikler ve motor sıcaktan zorlanabilir, aracı mola aralarında kontrol et.',
    'Yolculuğu erteleyebiliyorsan erteleyelim kanki, bu sıcak ciddi.',
    'Baş dönmesi ya da bulantı hissedersen hemen serin bir yere geç.',
    'Aşırı sıcakta gölge ve su her şeyden önemli, bunları ihmal etme.',
    'Bu hava yolda sürprizler çıkarabilir kanki, dikkatli ve bol suyla ilerle.',
  ];

  static const List<String> donmaUyari = [
    'Donma uyarısı var kanki, yollarda buz oluşabilir.',
    'Sıcaklık sıfırın altında, köprü ve gölgeli yerlerde buz tehlikesi yüksek.',
    'Sabah erken saatlerde yol donmuş olabilir, yavaş ve dikkatli sür.',
    'Donma yüzünden yüzey görünmeden kayabilir, fren mesafeni uzat.',
    'Kış lastiği ve yakıt deposu kontrolü şart kanki.',
    'Donmuş yolda ani frene basma, direksiyonu sabit tut ve yavaşça yavaşla.',
    'Cam buzlanmış olabilir, sürmeden önce camları iyice temizle.',
    'Donma riski olan saatlerde ani manevralardan kaçın kanki.',
    'Soğukta akü zayıflayabilir, aracı çalıştırmadan önce kontrol et.',
  ];

  static const List<String> kayganYolUyari = [
    'Yavaş git kanki, kaygan bu buzda! Yol cam gibi kayıyor...',
    'Kanki yolda kayma hissedildi, direksiyonu yumuşak tut ve gazdan ayağını çek!',
    'Frene sert basma kanki, tekerlekler kilitlenir, yavaşça yavaşla.',
    'Yol kaygan, virajlara hızlı girme, dönüşleri yumuşak yap.',
    'Önündeki aracın arasına fazla yaklaşma, kaygan yolda durma mesafesi uzar.',
    'Savrulursan direksiyonu sakin şekilde kaymanın yönüne çevir ve gaza basma.',
    'Sollama yapma kanki, kaygan yolda manevra alanın çok dar.',
    'Kaygan yolda sabır en iyi sürücü arkadaşın, acele etme.',
    'Kayma olduğunda panik yapma kanki, gazı kes, direksiyonu düz tut ve yavaşla.',
  ];

  static const List<String> yolBuzlu = [
    'Yol buzlu kanki, görünmez bir buz tabakası olabilir.',
    'Gölgeli ve köprü üstü kısımlar en çok buz tutar, orada ekstra dikkat.',
    'Buzlu yolda fren mesafesi çok uzar, öne çıkma.',
    'Yolda buz varsa zincir ya da kış lastiği şart kanki.',
    'Buzda gaz ve fren yumuşak olmalı, sert hareketler kaymaya sebep olur.',
    'Buz tutmuş yol her an kayabilir, hızını ciddi düşür.',
    'Kanki, buzlu zeminde sürüş tam bir sabır işi, acele etme.',
    'Yol kenarında buzlar birikmiş olabilir, dikkatli ilerle.',
    'Buzlu yollarda mola verip yolu kontrol etmek güvenli bir seçenek kanki.',
  ];

  // ---------------------------------------------------------------- izinler / tek cümleler

  static const String offlineNotu = 'Şu an son kaydedilen veriye bakıyorsun';

  static const String konumIzinYok =
      'Konum izni vermediğin için otomatik konum çalışmıyor, istersen elle şehir seçebilirsin.';

  static const String bildirimIzinYok =
      'Bildirim iznin kapalı kanki, önemli uyarıları kaçırmamak için açmayı düşünebilirsin.';

  static const String kameraIzinYok =
      'Kamera iznin yok kanki, bu özellik için izin vermen gerekiyor.';

  static const String mikrofonIzinYok =
      'Mikrofon iznin yok kanki, sesli özellik için izin vermen gerekiyor.';
}
