// 88 resmî takımyıldız. Merkez RA/Dec yaklaşıktır (derece, J2000).
// lines: brightStars içindeki yıldız ADLARI çiftleri; yalnızca en belirgin
// ~25 takımyıldız için tanımlıdır, diğerleri boştur.
// Hikâyeler sesli anlatım için kısa ve akıcı Türkçe metinlerdir.

class Constellation {
  const Constellation(
    this.latin,
    this.abbr,
    this.nameTr,
    this.story,
    this.raDeg,
    this.decDeg,
    this.lines,
  );

  final String latin;
  final String abbr;
  final String nameTr;
  final String story;
  final double raDeg;
  final double decDeg;
  final List<List<String>> lines;
}

const List<Constellation> constellations = [
  Constellation(
    'Andromeda', 'And', 'Andromeda',
    'Etiyopya Kraliçesi Kassiopeia, güzelliğiyle övününce deniz tanrısının öfkesini çeker. Kızı Andromeda, canavara yem olsun diye bir kayaya zincirlenir. Perseus onu kurtarır ve ikisi evlenir; tanrılar da onları göklerde yan yana anar.',
    1.5, 36.0,
    [['Alpheratz', 'Mirach'], ['Mirach', 'Almach']],
  ),
  Constellation(
    'Antlia', 'Ant', 'Pompa',
    'On sekizinci yüzyılda Lacaille tarafından tanımlanan bu takımyıldız, hava pompasını simgeler. Parlak yıldızı olmayan sade bir figürdür. Bilimin deneyle gelişen yönünü göğe taşıyan modern bir adlandırmadır.',
    152.0, -33.0, [],
  ),
  Constellation(
    'Apus', 'Aps', 'Cennet Kuşu',
    'Eski anlatılara göre ayakları olmayan cennet kuşları, ömürlerini havada süzülerek geçirirdi. Güney Kutbu yakınında yer alan bu takımyıldız, bu efsaneden adını alır. Gökyüzünün en soğuk ve sessiz köşelerinden biridir.',
    243.0, -75.0, [],
  ),
  Constellation(
    'Aquarius', 'Aqr', 'Kova',
    'Yunan mitolojisinde Troya prensi Ganymedes, tanrılara su taşıyan sakî olmak üzere göğe alınmıştır. Kovasından dökülen su, kışın yağmur ve sel mevsimiyle ilişkilendirilmiştir. Eski uygarlıklar bu takımyıldızı su ve bereketle özdeşleştirmiştir.',
    337.0, -10.0,
    [['Sadalsuud', 'Sadalmelik'], ['Sadalmelik', 'Skat']],
  ),
  Constellation(
    'Aquila', 'Aql', 'Kartal',
    'Kartal, Zeus\'un sadık kuşu olarak bilinir ve Ganymedes\'i Olimpos\'a taşıdığı anlatılır. Zeus, kartalın bu hizmetini onurlandırmak için onu göklere yerleştirmiştir. Altair, kartalın kalbi gibi parlar ve yaz gecelerinin köşe taşlarından biridir.',
    297.0, 3.0,
    [['Altair', 'Tarazed'], ['Altair', 'Alshain']],
  ),
  Constellation(
    'Ara', 'Ara', 'Sunak',
    'Yunan efsanesine göre Titanlarla yapılan savaştan önce tanrılar bu kutsal sunakta yemin etmiştir. Sunaktan yükselen dumanın tanrılara ulaştığına inanılırdı. Güney Samanyolu\'nun parlak alanında, sunağın dumanını andıran bir figür olarak yer alır.',
    258.0, -56.0, [],
  ),
  Constellation(
    'Aries', 'Ari', 'Koç',
    'Altın yünlü koç, ölümden kaçan Frixos ve kız kardeşi Helle\'yi sırtında taşıyan efsanevi bir hayvandır. Helle denize düşünce Frixos, Kolkhis\'e kadar güvenle ulaşmıştır. Koçun altın yünü, daha sonra Argonotların peşine düştüğü hazine olarak anılır.',
    40.0, 20.0,
    [['Hamal', 'Sheratan']],
  ),
  Constellation(
    'Auriga', 'Aur', 'Arabacı',
    'Arabacı, bazı rivayetlerde Erihtonios\'u arabasında taşıyan efsanevi bir kraldır. Elindeki keçi ve yavruları Capella yıldızı ile simgelenir. Kış gecelerinde Orion\'un yakınında parlak bir ilgi odağı olur.',
    85.0, 42.0,
    [['Capella', 'Menkalinan'], ['Capella', 'Elnath']],
  ),
  Constellation(
    'Boötes', 'Boo', 'Çoban',
    'Çoban, Büyük Ayı\'yı koruyan bekçi olarak anlatılır. Bazı rivayetlerde Likaon\'un oğlu Arkas\'tır ve annesi Kallisto ile birlikte göğe alınmıştır. Arcturus, adını "ayının bekçisi" anlamına gelen bu takımyıldızın parlak yıldızından alır.',
    218.0, 30.0,
    [['Arcturus', 'Izar'], ['Arcturus', 'Seginus'], ['Arcturus', 'Muphrid'], ['Seginus', 'Nekkar'], ['Izar', 'Nekkar']],
  ),
  Constellation(
    'Caelum', 'Cae', 'Oyma Aleti',
    'On sekizinci yüzyılda Lacaille tarafından tanımlanan bu takımyıldız, oyma ve gravür aletlerini simgeler. Sönük yıldızları olan dağınık bir alan kaplar. Bilim ve sanatın araçlarının göğe yansıtılması fikrinden doğmuştur.',
    70.0, -39.0, [],
  ),
  Constellation(
    'Camelopardalis', 'Cam', 'Zürafa',
    'Zürafa, on yedinci yüzyılda Plancius tarafından tanımlanmış, uzak diyarların yaratıklarına ithafen adlandırılmış bir takımyıldızdır. Kuzey göğünde sönük yıldızlardan oluşan geniş bir alanı kaplar. Yıl boyunca kuzey gökyüzünde görülebilir.',
    80.0, 75.0, [],
  ),
  Constellation(
    'Cancer', 'Cnc', 'Yengeç',
    'Herakles, Hidra ile savaşırken Hera\'nın gönderdiği yengeç onu ısırmaya çalışmıştır. Herakles yengeci ezince Hera, sadık hizmetini onurlandırmak için onu göklere yerleştirmiştir. Yaz başlangıcında görülen bu takımyıldız, Yengeç Dönencesi\'nin adını taşır.',
    130.0, 20.0, [],
  ),
  Constellation(
    'Canes Venatici', 'CVn', 'Av Köpekleri',
    'Av Köpekleri, Çoban\'ın yanında duran iki avcı köpeğidir. Asterion ve Chara adlı bu köpekler, Büyük Ayı\'yı kovalar gibi görünür. Cor Caroli, bu takımyıldızın en parlak yıldızıdır ve sevimli bir ikili gibi parlar.',
    190.0, 38.0, [],
  ),
  Constellation(
    'Canis Major', 'CMa', 'Büyük Köpek',
    'Büyük Köpek, avcı Orion\'un sadık avcı köpeğidir. Gökyüzünün en parlak yıldızı Sirius bu köpeğin ağzında parlar. Antik Mısır\'da Sirius\'un şafak vakti doğuşu, Nil\'in taşkın mevsiminin başlangıcını haber verirdi.',
    105.0, -20.0,
    [['Sirius', 'Mirzam'], ['Sirius', 'Wezen'], ['Wezen', 'Adhara'], ['Adhara', 'Aludra'], ['Sirius', 'Furud']],
  ),
  Constellation(
    'Canis Minor', 'CMi', 'Küçük Köpek',
    'Küçük Köpek, Orion\'un avında ona eşlik eden ikinci köpektir. Procyon adı "köpekten önce" anlamına gelir; çünkü Sirius\'tan önce doğar. Gökyüzünde iki parlak yıldızdan oluşan sade bir çizgi gibi görünür.',
    115.0, 6.0,
    [['Procyon', 'Gomeisa']],
  ),
  Constellation(
    'Capricornus', 'Cap', 'Oğlak',
    'Pan, Typhon korkusuyla tanrılar kaçarken Nil\'e atlamış ve bedeninin alt kısmı balığa dönüşmüştür. Yarı keçi, yarı balık olan bu yaratık, cesaretinin anısına göklere yerleştirilmiştir. Güneş\'in kış dönemindeki yolunda yer alır.',
    312.0, -18.0,
    [['Deneb Algedi', 'Nashira']],
  ),
  Constellation(
    'Carina', 'Car', 'Karina',
    'Karina, Jason ve Argonotların yolculuğunda kullandığı Argo gemisinin bir parçasıdır. On sekizinci yüzyılda Argo bölündüğünde ayrı bir takımyıldız oldu. Canopus, gökyüzünün en parlak yıldızlarından biridir ve seyircilere yolu gösterir.',
    120.0, -62.0,
    [['Canopus', 'Avior'], ['Miaplacidus', 'Avior']],
  ),
  Constellation(
    'Cassiopeia', 'Cas', 'Kassiopeia',
    'Kassiopeia, Etiyopya Kraliçesi\'dir ve güzelliğiyle Nereidler\'den üstün olduğunu söyler. Bu gurur, tanrıların öfkesini çekip kızı Andromeda\'nın kurban edilmesine yol açmıştır. Göklerde tahtında oturan bir figür olarak görünür ve bazen baş aşağı döner.',
    15.0, 62.0,
    [['Caph', 'Schedar'], ['Schedar', 'Navi'], ['Navi', 'Ruchbah'], ['Ruchbah', 'Segin']],
  ),
  Constellation(
    'Centaurus', 'Cen', 'Kentaurus',
    'Kentaurus, yarı at yarı insan olan Kentaurlar\'dan biridir ve bazı rivayetlerde bilge Kheiron olarak anılır. Herakles\'in okuyla yaralanan Kheiron, ölümsüzlüğünü Prometheus için bırakmıştır. Güney göğünde Güney Haçı\'nın yanında parlayan Rigil Kentaurus ile tanınır.',
    200.0, -47.0,
    [['Rigil Kentaurus', 'Hadar'], ['Hadar', 'Menkent']],
  ),
  Constellation(
    'Cepheus', 'Cep', 'Sefe',
    'Sefe, Etiyopya Kralı, Kassiopeia\'nın kocası ve Andromeda\'nın babasıdır. Kızının kurtarılmasına ve kraliyet ailesinin trajik kaderine tanık olmuştur. Kuzey göğünde, ailesiyle birlikte Kassiopeia ve Andromeda\'nın komşusu olarak durur.',
    330.0, 72.0,
    [['Alderamin', 'Errai']],
  ),
  Constellation(
    'Cetus', 'Cet', 'Balina',
    'Poseidon, Etiyopya\'yı cezalandırmak için bir deniz canavarı gönderir ve bu canavar Andromeda\'yı yutmak üzeredir. Perseus, canavarı öldürerek kızı kurtarır. Mira, bu takımyıldızda değişken parlaklığıyla ünlü bir yıldızdır.',
    25.0, -8.0,
    [['Diphda', 'Menkar'], ['Menkar', 'Mira']],
  ),
  Constellation(
    'Chamaeleon', 'Cha', 'Bukalemun',
    'Bukalemun, on altıncı yüzyılda Hollandalı gezginlerin Güney Gökyüzü\'nde gördüğü renk değiştiren kertenkeleye adını verdi. Güney Kutbu yakınında yer alır ve sönük yıldızlarla belirir. Adı, göğün değişen görünümünü çağrıştırır.',
    170.0, -79.0, [],
  ),
  Constellation(
    'Circinus', 'Cir', 'Pergel',
    'Pergel, on sekizinci yüzyılda Lacaille tarafından tanımlanan, çember çizmeye yarayan aleti simgeler. Güney göğünde Centaurus\'un yakınında küçük bir şekil oluşturur. Geometrinin ve ölçmenin göğe yansıtılmış hâlidir.',
    220.0, -65.0, [],
  ),
  Constellation(
    'Columba', 'Col', 'Güvercin',
    'Güvercin, on altıncı yüzyılda Nuh\'un gemisinden salınan ve kara bulduğunu müjdeleyen güvercine ithafen adlandırılmıştır. Büyük Köpek\'in ayaklarının altında sakin bir yerde durur. Sönük yıldızlardan oluşan sade bir figürdür.',
    85.0, -35.0, [],
  ),
  Constellation(
    'Coma Berenices', 'Com', 'Berenice\'nin Saçı',
    'Mısır Kraliçesi Berenice, kocası Üçüncü Ptolemaios\'un savaştan dönüşü için saçını tanrılara adamıştır. Saç bir süre sonra kaybolunca, tanrıların onu göğe yerleştirdiği söylenir. Kuzey göğünde dağınık ve sönük yıldızlardan oluşan bir kümedir.',
    190.0, 22.0, [],
  ),
  Constellation(
    'Corona Australis', 'CrA', 'Güney Tacı',
    'Güney Tacı, Dionysos\'un Ariadne ile evliliğinde kullandığı ya da Kentaurlara verilen tacın göğe yansıtılmış biçimidir. Yay takımyıldızının ayakları önünde yer alır. Parlak yıldızı olmayan küçük bir yay şeklinde görünür.',
    275.0, -43.0, [],
  ),
  Constellation(
    'Corona Borealis', 'CrB', 'Kuzey Tacı',
    'Kuzey Tacı, Dionysos\'un Ariadne için göğe fırlattığı evlilik tacıdır. Taç, yıldızlardan oluşan yarım bir çember olarak kalmıştır. Alphecca, bu tacın en parlak yıldızıdır ve iki sevgilinin birlikteliğini simgeler.',
    237.0, 31.0,
    [],
  ),
  Constellation(
    'Corvus', 'Crv', 'Karga',
    'Karga, Apollon\'a su getirmekle görevlendirilmişti ama yolda oyalanıp yılan getirmiştir. Apollon kuşu cezalandırmış ve göğe yerleştirirken Krater ve Hidra ile birlikte kalmasını emretmiştir. Bu nedenle Karga, Krater ve Hidra yan yana görünür.',
    187.0, -18.0,
    [['Algorab', 'Kraz'], ['Kraz', 'Minkar'], ['Minkar', 'Gienah Corvi'], ['Gienah Corvi', 'Algorab']],
  ),
  Constellation(
    'Crater', 'Crt', 'Kadeh',
    'Kadeh, Apollon\'un karga ile birlikte gönderdiği su dolu kâsedir. Karganın kâseden içmek için oyalanması Apollon\'u kızdırmış ve ikisini de göklere yerleştirmiştir. Hidra\'nın sırtında duran kadeh, bu hikâyenin sessiz tanığıdır.',
    167.0, -16.0, [],
  ),
  Constellation(
    'Crux', 'Cru', 'Güney Haçı',
    'Güney Haçı, Centaurus\'un içinde yer alan en küçük takımyıldızdır. Acrux ve Gacrux, haçın uzun ekseni olarak parlar. Güney yarımkürede yolcular için güneyi gösteren bir yol işaretidir.',
    187.0, -60.0,
    [['Acrux', 'Gacrux']],
  ),
  Constellation(
    'Cygnus', 'Cyg', 'Kuğu',
    'Zeus, Leda ile birlikte olmak için kuğu kılığına girmiştir. Rivayete göre bu birliktelikten doğan çocuklar kuğu biçiminde göğe yerleştirilmiştir. Deneb, kuğunun kuyruğunda parlar ve Samanyolu üzerinde uçan bir kuş gibi görünür.',
    310.0, 42.0,
    [['Deneb', 'Sadr'], ['Sadr', 'Albireo'], ['Sadr', 'Gienah']],
  ),
  Constellation(
    'Delphinus', 'Del', 'Yunus',
    'Yunus, Poseidon\'un gelini Amfitrite\'yi evlenmesi için ikna eden yunustur. Bu hizmeti için Poseidon onu göklere yerleştirmiştir. Küçük ve parlak yıldızlardan oluşan sevimli bir şekil çizer.',
    310.0, 12.0, [],
  ),
  Constellation(
    'Dorado', 'Dor', 'Kılıçbalığı',
    'Kılıçbalığı, on altıncı yüzyılda Hollandalı gezginlerin güney denizlerinde gördüğü balığın adını taşır. Büyük Macellan Bulutu bu takımyıldızın içinde yer alır. Güney yarımkürenin yaz gecelerinde görülebilen bir figürdür.',
    75.0, -62.0, [],
  ),
  Constellation(
    'Draco', 'Dra', 'Ejderha',
    'Ejderha, Hesperides\'in altın elmalarını koruyan devasa yılandır ve Herakles tarafından öldürülmüştür. Hera, sadık koruyucusunu onurlandırmak için onu göklere yerleştirmiştir. Büyük Ayı ile Küçük Ayı arasına kıvrılır ve Thuban, eski çağlarda kutup yıldızıydı.',
    227.0, 67.0,
    [['Eltanin', 'Rastaban'], ['Thuban', 'Eltanin']],
  ),
  Constellation(
    'Equuleus', 'Equ', 'Küçük At',
    'Küçük At, Pegasus\'un kardeşi olarak anlatılır ve Zeus\'un bir armağanıdır. Göklerde Pegasus\'a eşlik eder ve birlikte yolculuğa çıkar. Sönük yıldızları küçük bir dörtgen oluşturur.',
    320.0, 8.0, [],
  ),
  Constellation(
    'Eridanus', 'Eri', 'Eridanus',
    'Eridanus, Phaethon\'un güneş arabasıyla düştüğü efsanevi nehirdir. Tanrılar, nehrin sonsuza kadar akması için onu göklere yerleştirmiştir. Achernar, bu uzun ve kıvrımlı nehrin sonunda parlar.',
    50.0, -30.0,
    [['Acamar', 'Zaurak']],
  ),
  Constellation(
    'Fornax', 'For', 'Fırın',
    'Fırın, on sekizinci yüzyılda Lacaille tarafından ateşin ve laboratuvar fırınının simgesi olarak tanımlanmıştır. Bilimsel deneyin ve sıcaklığın göğe yansıtılmış biçimidir. Sönük yıldızlardan oluşan sade bir figürdür.',
    45.0, -30.0, [],
  ),
  Constellation(
    'Gemini', 'Gem', 'İkizler',
    'İkizler, Zeus\'un Leda ile birlikteliğinden doğan Kastor ve Polideukes\'tir. Kastor ölümlü, Polideukes ölümsüzdür ve ikisi birbirine bağlı kalmak için göklere yerleştirilmiştir. Castor ve Pollux, gökyüzünde kardeşlik sembolü olarak parlar.',
    105.0, 22.0,
    [['Castor', 'Pollux'], ['Pollux', 'Alhena'], ['Castor', 'Mebsuta'], ['Mebsuta', 'Tejat'], ['Tejat', 'Propus']],
  ),
  Constellation(
    'Grus', 'Gru', 'Turna',
    'Turna, Kirke\'nin büyüsüyle domuzlara dönüşen Odysseus\'un yoldaşlarından biridir. Plutarkhos\'un anlatısında Gryllus adlı bir adam, insan olmaya geri dönmeyi reddetmiş ve turna olarak kalmayı seçmiştir. Güney göğünde parlak Alnair ile tanınır.',
    330.0, -45.0, [],
  ),
  Constellation(
    'Hercules', 'Her', 'Herkül',
    'Herkül, Zeus ile Alkmene\'nin oğlu olan ve on iki görevi tamamlayan büyük kahramandır. Hera\'nın kıskançlığına rağmen cesaretiyle tanrılar tarafından onurlandırılmış ve göğe yerleştirilmiştir. Gökyüzünde çömelmiş, dev bir savaşçı olarak görünür.',
    255.0, 30.0,
    [['Rasalgethi', 'Kornephoros']],
  ),
  Constellation(
    'Horologium', 'Hor', 'Saat',
    'Saat, on sekizinci yüzyılda Lacaille tarafından zamanın ölçülmesini simgelemek için tanımlanmıştır. Güney göğünde sönük yıldızlardan oluşan bir figürdür. Bilimsel zaman ölçümünün göğe taşınmış hâlidir.',
    55.0, -55.0, [],
  ),
  Constellation(
    'Hydra', 'Hya', 'Hidra',
    'Hidra, Herakles\'in ikinci görevinde yenmeye çalıştığı çok başlı yılandır; her kesilen başın yerine yenisi çıkardı. Hera\'nın gönderdiği yengeç de bu savaşa katılmıştır. Gökyüzündeki en uzun takımyıldız olarak uzanır ve Alphard, bu yılanın kalbi sayılır.',
    174.0, -14.0, [],
  ),
  Constellation(
    'Hydrus', 'Hyi', 'Su Yılanı',
    'Su Yılanı, on altıncı yüzyılda Hollandalı gezginler tarafından Güney Gökyüzü\'nde tanımlanmıştır. Güney Kutbu\'na yakın duran bu küçük yılan, su yaşamının göksel bir simgesidir. Büyük Macellan Bulutu\'na komşudur.',
    30.0, -70.0, [],
  ),
  Constellation(
    'Indus', 'Ind', 'Hintli',
    'Hintli, on altıncı yüzyılda Hollandalı gezginler tarafından Hindistan halkının simgesi olarak tanımlanmıştır. Hint Okyanusu ve Hindistan\'a yapılan uzun seyahatlere gönderme yapar. Güney göğünde sönük bir figür olarak yer alır.',
    320.0, -60.0, [],
  ),
  Constellation(
    'Lacerta', 'Lac', 'Kertenkele',
    'Kertenkele, on yedinci yüzyılda Hevelius tarafından tanımlanmış, Cassiopeia ile Cygnus arasında yer alan sönük bir figürdür. Adı, eski gökbilimcilerin yeni figürler çizme geleneğini yansıtır. Karanlık gecelerde kuzey göğünde görülebilir.',
    335.0, 46.0, [],
  ),
  Constellation(
    'Leo', 'Leo', 'Aslan',
    'Aslan, Herakles\'in ilk görevinde öldürdüğü Nemea Aslanı\'dır. Derisi kılıçla delinemeyen bu canavarı Herakles boğarak yenmiştir. Regulus, Aslan\'ın kalbi gibi parlar ve gökyüzünün ilkbahar yıldızlarındandır.',
    160.0, 13.0,
    [['Regulus', 'Algieba'], ['Algieba', 'Zosma'], ['Zosma', 'Denebola']],
  ),
  Constellation(
    'Leo Minor', 'LMi', 'Küçük Aslan',
    'Küçük Aslan, on yedinci yüzyılda Hevelius tarafından tanımlanan, Aslan\'ın küçük kardeşidir. Sönük yıldızlarıyla Büyük Ayı ile Aslan arasında sessiz bir köprü gibi durur. Adı, Aslan\'ın gölgesi gibi düşünülür.',
    160.0, 36.0, [],
  ),
  Constellation(
    'Lepus', 'Lep', 'Tavşan',
    'Tavşan, Orion\'un önünde kaçan ve avcının peşinden koştuğu av hayvanıdır. Yunan rivayetine göre Orion\'un ayakları altında sürekli kovalanır. Arneb ve Nihal, bu tavşanın parlak yıldızlarındandır.',
    82.0, -21.0,
    [['Arneb', 'Nihal']],
  ),
  Constellation(
    'Libra', 'Lib', 'Terazi',
    'Terazi, adalet tanrıçası Astraea\'nın tartısıyla ilişkilendirilir ve eşitlik kavramını simgeler. Eski uygarlıklarda Akrep\'in kıskaçları olarak düşünülmüştür. Zubenelgenubi ve Zubeneschamali, terazinin iki kefesini oluşturur.',
    228.0, -15.0,
    [['Zubenelgenubi', 'Zubeneschamali']],
  ),
  Constellation(
    'Lupus', 'Lup', 'Kurt',
    'Kurt, Kentaur\'un yanında taşıdığı av olarak tasvir edilir. Av ile avcının bir arada anılması, gökyüzünde bu iki figürü birlikte düşündürür. Güney göğünde sönük yıldızlarla belirir.',
    225.0, -43.0, [],
  ),
  Constellation(
    'Lynx', 'Lyn', 'Vaşak',
    'Vaşak, on yedinci yüzyılda Hevelius tarafından tanımlanmış, keskin gözleriyle ünlü bir hayvandır. Büyük Ayı ile İkizler arasında sönük yıldızlardan oluşan bir figür olarak yer alır. Gece görüşünün ve dikkatin sembolü sayılır.',
    120.0, 45.0, [],
  ),
  Constellation(
    'Lyra', 'Lyr', 'Lir',
    'Lir, Hermes\'in yaptığı ve Apollon\'a verdiği efsanevi çalgıdır. Orfeus, bu liri çalarak Hades\'in yeraltı tanrılarını etkiler ve eşi Eurydike\'yi geri istemiştir. Vega, Lir\'in en parlak yıldızıdır ve yaz göğünün köşe taşlarından biridir.',
    282.0, 38.0,
    [['Vega', 'Sheliak'], ['Sheliak', 'Sulafat'], ['Sulafat', 'Vega']],
  ),
  Constellation(
    'Mensa', 'Men', 'Masa Dağı',
    'Masa Dağı, on sekizinci yüzyılda Lacaille tarafından Güney Afrika\'daki Masa Dağı\'na ithafen adlandırılmıştır. Güney Kutbu yakınında yer alan sönük bir takımyıldızdır. Adı, dünyadaki düz tepeli bir dağın göğe yansıtılmasıdır.',
    85.0, -78.0, [],
  ),
  Constellation(
    'Microscopium', 'Mic', 'Mikroskop',
    'Mikroskop, on sekizinci yüzyılda Lacaille tarafından bilimsel mikroskobu simgelemek için tanımlanmıştır. Sönük yıldızlarla gökyüzünde zor görülür. Görünmeyeni görünür kılan bu aletin göksel bir yansımasıdır.',
    315.0, -36.0, [],
  ),
  Constellation(
    'Monoceros', 'Mon', 'Tek Boynuz',
    'Tek Boynuz, on yedinci yüzyılda Plancius tarafından tanımlanan efsanevi tek boynuzlu atı simgeler. Orion ile Büyük Köpek arasında Samanyolu\'nda dağılmış sönük yıldızlardan oluşur. Eski efsanelerde saf ve yakalanması zor bir yaratık olarak anlatılır.',
    105.0, 0.0, [],
  ),
  Constellation(
    'Musca', 'Mus', 'Sinek',
    'Sinek, on altıncı yüzyılda Hollandalı gezginler tarafından Güney Gökyüzü\'nde tanımlanan küçük bir böceği simgeler. Güney Kutbu yakınında sönük yıldızlarla belirir. Gökyüzündeki en küçük canlı imgelerden biridir.',
    190.0, -70.0, [],
  ),
  Constellation(
    'Norma', 'Nor', 'Gönye',
    'Gönye, on sekizinci yüzyılda Lacaille tarafından mühendislik ve ölçümde kullanılan açı aletini simgeler. Güney göğünde Akrep ve Kentaur arasında yer alır. Ölçmenin ve düzgünlüğün göğe yansıtılmış hâlidir.',
    245.0, -50.0, [],
  ),
  Constellation(
    'Octans', 'Oct', 'Oktant',
    'Oktant, on sekizinci yüzyılda Lacaille tarafından Güney Kutbu\'nun çevresinde tanımlanan navigasyon aletidir. Güney Kutbu\'na en yakın takımyıldız olarak bilinir. Denizcilikle ilişkilendirilen sönük bir figürdür.',
    320.0, -85.0, [],
  ),
  Constellation(
    'Ophiuchus', 'Oph', 'Yılancı',
    'Yılancı, tıp tanrısı Asklepios\'u temsil eder ve elindeki yılan, şifa bilgisinin simgesidir. Asklepios ölüleri diriltmeye başlayınca Zeus onu yıldırımla öldürmüş ve göğe yerleştirmiştir. Yılan, Yılancı\'nın iki yanına uzanan Serpens ile birlikte görünür.',
    258.0, -8.0,
    [['Rasalhague', 'Cebalrai'], ['Cebalrai', 'Yed Prior'], ['Sabik', 'Yed Prior']],
  ),
  Constellation(
    'Orion', 'Ori', 'Avcı',
    'Orion, Poseidon\'un oğlu ve Artemis\'in yakın dostu olan güçlü bir avcıdır. Rivayete göre bir akrep tarafından öldürülmüş ve Artemis\'in isteğiyle göğe yerleştirilmiştir. Kış gökyüzünün en tanınmış figürüdür; üç yıldızlı kemeri her gece kolayca fark edilir.',
    83.0, 2.0,
    [['Betelgeuse', 'Bellatrix'], ['Betelgeuse', 'Alnitak'], ['Bellatrix', 'Mintaka'], ['Mintaka', 'Alnilam'], ['Alnilam', 'Alnitak'], ['Mintaka', 'Rigel'], ['Alnitak', 'Saiph']],
  ),
  Constellation(
    'Pavo', 'Pav', 'Tavus Kuşu',
    'Tavus Kuşu, Hera\'nın kutsal kuşudur ve kuyruğu, Argos\'un gözleriyle süslenmiştir. Rivayete göre Hera, Argos\'un gözlerini bu kuşun tüylerine yerleştirmiştir. Güney göğünde parlak Peacock yıldızı ile tanınır.',
    300.0, -65.0, [],
  ),
  Constellation(
    'Pegasus', 'Peg', 'Pegasus',
    'Pegasus, Medusa\'nın kesik boynundan fışkıran kanatlı attır. Bellerophon\'un Kimaira\'yı yenmesine yardım etmiş ve Olympos\'a uçmaya kalkınca Zeus onu göğe yerleştirmiştir. Büyük Kare, ilkbahar ve sonbahar gecelerinin en belirgin şekillerinden biridir.',
    340.0, 20.0,
    [['Markab', 'Scheat'], ['Scheat', 'Alpheratz'], ['Alpheratz', 'Algenib'], ['Algenib', 'Markab']],
  ),
  Constellation(
    'Perseus', 'Per', 'Perseus',
    'Perseus, Zeus ile Danae\'nin oğlu olan kahramandır. Medusa\'nın başını keserek Andromeda\'yı deniz canavarından kurtarmış ve Medusa\'nın kanından Pegasus doğmuştur. Algol, Medusa\'nın gözü olarak bilinir ve gece gökyüzünde değişken parlaklığıyla dikkat çeker.',
    52.0, 45.0,
    [['Mirfak', 'Algol']],
  ),
  Constellation(
    'Phoenix', 'Phe', 'Anka Kuşu',
    'Anka Kuşu, Mısır efsanelerinde kendini yakıp küllerinden yeniden doğan ölümsüz kuştur. On yedinci yüzyılda Lacaille tarafından göğe yerleştirilmiştir. Ankaa, bu takımyıldızın en parlak yıldızı ve yeniden doğuşun göksel simgesidir.',
    20.0, -50.0, [],
  ),
  Constellation(
    'Pictor', 'Pic', 'Ressam Sehpası',
    'Ressam Sehpası, on sekizinci yüzyılda Lacaille tarafından tuvali ve sanatı simgelemek için tanımlanmıştır. Güney göğünde sönük yıldızlardan oluşan bir figür olarak durur. Sanatın göğe yansıtılması fikrini taşır.',
    85.0, -50.0, [],
  ),
  Constellation(
    'Pisces', 'Psc', 'Balıklar',
    'Balıklar, Afrodit ve oğlu Eros\'un Typhon\'dan kaçarken nehre atlayıp balığa dönüşmesiyle anılır. İki balık, dönüşümlerinin anısı olarak bir iple bağlanmıştır. Gökyüzünde Koç ile Kova arasında uzun bir kuşak gibi uzanır.',
    15.0, 15.0, [],
  ),
  Constellation(
    'Piscis Austrinus', 'PsA', 'Güney Balığı',
    'Güney Balığı, Yunan mitolojisinde Derin Su\'dan çıkıp okyanusta yüzen büyük balıktır. Fomalhaut, bu balığın ağzında parlayan tek ve en parlak yıldızdır. Güney göğünde denizle ilişkilendirilen yalnız bir yıldızdır.',
    340.0, -32.0,
    [],
  ),
  Constellation(
    'Puppis', 'Pup', 'Gemi Pupası',
    'Gemi Pupası, Argo gemisinin arka kısmını temsil eder ve Jason\'ın yolculuğunu anımsatır. On sekizinci yüzyılda Argo bölündüğünde Karina, Pusula ve Yelken ile birlikte ayrı takımyıldızlar oldu. Naos, bu pupanın en parlak yıldızıdır.',
    115.0, -35.0, [],
  ),
  Constellation(
    'Pyxis', 'Pyx', 'Pusula',
    'Pusula, on sekizinci yüzyılda Lacaille tarafından Argo gemisinin pusulasını simgelemek için tanımlanmıştır. Denizcilerin yön bulma çabasını göğe taşır. Sönük yıldızlardan oluşan küçük bir figürdür.',
    135.0, -27.0, [],
  ),
  Constellation(
    'Reticulum', 'Ret', 'Ağ',
    'Ağ, on sekizinci yüzyılda Lacaille tarafından teleskopta görülen ağ benzeri bir yapıyı simgelemek için tanımlanmıştır. Güney göğünde sönük yıldızlardan oluşan küçük bir figürdür. Gözlemin ayrıntılarını temsil eden bir ağı andırır.',
    62.0, -62.0, [],
  ),
  Constellation(
    'Sagitta', 'Sge', 'Ok',
    'Ok, Yunan mitolojisinde Herakles\'in Aietes\'in kuşlarını vurmak için kullandığı ya da Apollon\'un yayından çıkan bir ok olarak anlatılır. Kartal ile Yay arasında dar bir ok gibi uzanır. Gökyüzündeki en küçük takımyıldızlardan biridir.',
    298.0, 19.0, [],
  ),
  Constellation(
    'Sagittarius', 'Sgr', 'Yay',
    'Yay, okçuluk becerisiyle bilinen Kentaur Kheiron\'la ilişkilendirilir. Zeus, okçuyu yıldızların arasında göğe yerleştirmiştir. Samanyolu\'nun merkezine yakın bu takımyıldız, bir çaydanlık şekliyle tanınır.',
    280.0, -27.0,
    [['Kaus Australis', 'Kaus Media'], ['Kaus Media', 'Kaus Borealis'], ['Kaus Australis', 'Nunki'], ['Nunki', 'Ascella']],
  ),
  Constellation(
    'Scorpius', 'Sco', 'Akrep',
    'Akrep, Orion\'u öldüren ve Artemis\'in isteğiyle göğe yerleştirilen akrep olarak anlatılır. Orion ile Akrep gökyüzünde birbirinden uzak durur ve avcı akrepten kaçar. Antares, akrebin kalbi gibi kızıl parlar.',
    255.0, -30.0,
    [['Dschubba', 'Graffias'], ['Graffias', 'Antares'], ['Antares', 'Sargas'], ['Sargas', 'Shaula'], ['Shaula', 'Lesath']],
  ),
  Constellation(
    'Sculptor', 'Scl', 'Heykeltıraş',
    'Heykeltıraş, on sekizinci yüzyılda Lacaille tarafından heykel atölyesini simgelemek için tanımlanmıştır. Güney göğünde sönük yıldızlardan oluşan bir figürdür. Sanatın ve yaratmanın göğe yansıtılmış hâlidir.',
    15.0, -32.0, [],
  ),
  Constellation(
    'Scutum', 'Sct', 'Kalkan',
    'Kalkan, on yedinci yüzyılda Hevelius tarafından Polonya Kralı Sobieski\'nin kalkanı olarak tanımlanmıştır. Samanyolu\'nun parlak bölgesinde, Yay ile Kartal arasında yer alır. Koruma ve savunmanın göksel simgesidir.',
    278.0, -10.0, [],
  ),
  Constellation(
    'Serpens', 'Ser', 'Yılan',
    'Yılan, Yılancı\'nın tuttuğu ve Asklepios\'un şifa bilgisinde kullanılan kutsal yılandır. Takımyıldız, Yılancı\'nın iki yanında baş ve kuyruk olmak üzere iki parçaya ayrılmıştır. Gökyüzünde yılanın kıvrımları Yılancı\'nın elleri arasında görünür.',
    233.0, 8.0, [],
  ),
  Constellation(
    'Sextans', 'Sex', 'Sekstant',
    'Sekstant, on yedinci yüzyılda Hevelius tarafından gökyüzü ölçümünde kullanılan açı aletini simgelemek için tanımlanmıştır. Aslan\'ın altında, güney göğünde sönük yıldızlarla belirir. Gözlem ve ölçüm sanatının göğe yansıtılmış hâlidir.',
    152.0, -4.0, [],
  ),
  Constellation(
    'Taurus', 'Tau', 'Boğa',
    'Boğa, Zeus\'un Avrupa\'yı kaçırmak için aldığı kılıktır. Avrupa\'yı sırtında Girit\'e taşıyan boğa, göğe yerleştirilmiştir. Pleiades ve Hyades kümeleri ile belirgindir; Aldebaran ise boğanın kırmızı gözü gibi parlar.',
    65.0, 18.0,
    [['Aldebaran', 'Ain'], ['Ain', 'Alcyone'], ['Aldebaran', 'Elnath']],
  ),
  Constellation(
    'Telescopium', 'Tel', 'Teleskop',
    'Teleskop, on sekizinci yüzyılda Lacaille tarafından gözlem aletini simgelemek için tanımlanmıştır. Güney göğünde sönük yıldızlardan oluşur. Yıldızları incelemek için kullanılan aletin göksel bir simgesidir.',
    280.0, -50.0, [],
  ),
  Constellation(
    'Triangulum', 'Tri', 'Üçgen',
    'Üçgen, Yunan geleneğinde Nil Nehri\'nin deltasını ya da Sicilya\'nın şeklini çağrıştırır. Andromeda\'nın yakınında küçük ama belirgin bir üçgen oluşturur. Eski gökbilimcilerin en eski figürlerinden biri olarak bilinir.',
    30.0, 33.0, [],
  ),
  Constellation(
    'Triangulum Australe', 'TrA', 'Güney Üçgeni',
    'Güney Üçgeni, Üçgen\'in güney kardeşi olarak on altıncı yüzyılda tanımlanmıştır. Atria yıldızı ile belirgin bir üçgen oluşturur. Güney Kutbu\'nun yakınında sönük ama net bir şekil sergiler.',
    240.0, -66.0, [],
  ),
  Constellation(
    'Tucana', 'Tuc', 'Tukan',
    'Tukan, on altıncı yüzyılda Hollandalı gezginler tarafından Güney Amerika\'nın tukanına ithafen tanımlanmıştır. Büyük Macellan Bulutu bu takımyıldızın içinde yer alır. Güney Gökyüzü\'nün egzotik kuşlarından biridir.',
    0.0, -66.0, [],
  ),
  Constellation(
    'Ursa Major', 'UMa', 'Büyük Ayı',
    'Kallisto, Zeus ile olan ilişkisi yüzünden Hera tarafından ayıya dönüştürülmüştür. Zeus, ayıyı ve oğlu Arkas\'ı göğe yerleştirmiştir. Kepçe biçimindeki yıldızları, kuzey gökyüzünde en tanınan şekillerden biridir.',
    165.0, 55.0,
    [['Dubhe', 'Merak'], ['Merak', 'Phecda'], ['Phecda', 'Megrez'], ['Megrez', 'Dubhe'], ['Megrez', 'Alioth'], ['Alioth', 'Mizar'], ['Mizar', 'Alkaid']],
  ),
  Constellation(
    'Ursa Minor', 'UMi', 'Küçük Ayı',
    'Küçük Ayı, Kallisto\'nun ya da Arkas\'ın küçük ayı yavrusu olarak anlatılır. Kuzey Kutup Yıldızı Polaris, bu takımyıldızın kuyruk ucunda yer alır. Denizciler yüzyıllar boyunca yönlerini bulmak için bu takımyıldızı kullanmıştır.',
    225.0, 75.0,
    [['Polaris', 'Kochab'], ['Kochab', 'Pherkad']],
  ),
  Constellation(
    'Vela', 'Vel', 'Yelken',
    'Yelken, on sekizinci yüzyılda Argo gemisinin yelkenini simgelemek için tanımlanmıştır. Jason ve Argonotların seyir yaptığı geminin yelkeni olarak düşünülür. Güney göğünde Pusula ve Karina arasında sönük ama belirgin bir figürdür.',
    135.0, -47.0,
    [['Regor', 'Suhail']],
  ),
  Constellation(
    'Virgo', 'Vir', 'Başak',
    'Başak, adalet tanrıçası Astraea\'yı ya da Demeter\'in kızı Persefone\'yi simgeler. Tanrıça dünyayı terk ettiğinde göğe yerleştiği anlatılır. Spica, Başak\'ın elinde tuttuğu başak sapıdır ve hasat mevsiminin göksel işaretidir.',
    195.0, -4.0,
    [['Spica', 'Vindemiatrix'], ['Spica', 'Porrima'], ['Porrima', 'Heze'], ['Vindemiatrix', 'Zavijava']],
  ),
  Constellation(
    'Volans', 'Vol', 'Uçan Balık',
    'Uçan Balık, on altıncı yüzyılda Hollandalı gezginler tarafından Güney Gökyüzü\'nde tanımlanmıştır. Okyanus üzerinde havalanan balık efsanelerini çağrıştırır. Güney Kutbu\'na yakın sönük yıldızlardan oluşur.',
    130.0, -70.0, [],
  ),
  Constellation(
    'Vulpecula', 'Vul', 'Tilki',
    'Tilki, on yedinci yüzyılda Hevelius tarafından Kaz ile Kartal arasında tanımlanmış sönük bir takımyıldızdır. Adını hızlı ve kurnaz bir hayvandan alır. Samanyolu\'nun dar bir bölgesinde, yaz gecelerinde görülebilir.',
    296.0, 24.0, [],
  ),
];
