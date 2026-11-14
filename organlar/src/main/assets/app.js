/* İnsan Vücudu Atlası — arayüz ve 3B görüntüleyici.
   Arayüz/sahne mantığı, ashemag/human-atlas (MIT) projesinden three r128 + düz JS'e uyarlanmıştır.
   Anatomi verisi: BodyParts3D (CC BY 4.0), bkz. ATTRIBUTION.md */
(function(){
"use strict";
var T=window.THREE;
function $(id){return document.getElementById(id)}
function fmt(n){return Number(n).toLocaleString("tr-TR")}
function showError(msg){$("loading").hidden=true;$("errTxt").textContent=msg;$("errBox").hidden=false}
if(!T){showError("3D kitaplığı (three.min.js) yüklenemedi. Uygulamayı güncelle ve tekrar dene.");return}

/* ------------------------------------------------------------------ veri */
var SYSTEMS=[
 {id:"skeletal",name:"İskelet",color:"#e2d9ba",description:"Kemikler vücudun taşıyıcı çatısını oluşturur, organları korur ve kaslara tutunma noktası sağlar. İç dokuları ayrıca mineral depolar ve kan hücresi üretir."},
 {id:"muscular",name:"Kaslar",color:"#a85b50",description:"İskelet kasları, tutundukları yerleri çekerek hareket üretir. Tendonlarla birlikte eklemleri oynatır, duruşu dengeler ve ısı üretir."},
 {id:"cardiac",name:"Kalp",color:"#b96760",description:"Kalp, dört odacıklı kaslı bir pompadır. Kapakçıkları kanı akciğer ve vücut dolaşımı boyunca tek yönde ilerletir."},
 {id:"sensory",name:"Duyu organları",color:"#b0c8ce",description:"Bu yapılar görme, işitme ve denge gibi özel duyulara katkı sağlar. Özelleşmiş dokuları uyaranları algılar ve sinir sistemiyle birlikte bilgiyi iletir."},
 {id:"arterial",name:"Atardamarlar",color:"#c05245",description:"Kalp, kanı dolaşıma pompalar. Atardamarlar kanı kalpten uzağa, dokulara; akciğer dolaşımında ise akciğerlere taşır."},
 {id:"venous",name:"Toplardamarlar",color:"#527c9f",description:"Toplardamarlar kanı kalbe geri getirir. Yüzeysel ve derin ağlar dokulardan kan toplar; akciğer toplardamarları oksijenli kanı akciğerlerden kalbe taşır."},
 {id:"nervous",name:"Sinir sistemi",color:"#d8b565",description:"Beyin, omurilik ve çevresel sinirler sinyalleri taşır ve işler. Duyuyu, hareketi, koordinasyonu ve vücut işlevlerinin otomatik düzenlenmesini destekler."},
 {id:"respiratory",name:"Solunum",color:"#b98991",description:"Hava yolları havayı akciğerlere iletir; oksijen ve karbondioksit burada hava ile kan arasında geçiş yapar. Soluk alıp verme, solunum kaslarının oluşturduğu basınç değişimine bağlıdır."},
 {id:"digestive",name:"Sindirim",color:"#b8916b",description:"Sindirim borusu besinleri parçalar, besin ve suyu emer, atığı ilerletir. Yardımcı organlar safra ve sindirim enzimleri sağlar."},
 {id:"urinary",name:"İdrar yolları",color:"#b47961",description:"Böbrekler kanı süzer; sıvı, elektrolit ve asit-baz dengesini düzenler. İdrar, üreterlerle mesaneye iner ve üretradan dışarı atılır."},
 {id:"lymphatic",name:"Lenf sistemi",color:"#879f7c",description:"Lenf damarları dokulardaki fazla sıvıyı dolaşıma geri taşır. Lenf düğümleri ve diğer lenfoid organlar bağışıklık denetimine ve yanıtlarına katkı sağlar."},
 {id:"endocrine",name:"Hormon bezleri",color:"#c5a09a",description:"Hormon bezleri kana hormon salgılayarak metabolizma, büyüme, stres yanıtı ve üreme gibi süreçleri eşgüdümler."},
 {id:"reproductive",name:"Üreme",color:"#bda098",description:"Burada gösterilen erkek üreme yapıları sperm üretimine, olgunlaşmasına ve taşınmasına ve cinsiyet hormonlarının üretimine katkı sağlar."},
 {id:"integumentary",name:"Vücut yüzeyi",color:"#ba9b7d",description:"Vücut yüzeyi dış anatomik başvuruyu sağlar. Deri sistemi koruyucu bir engel oluşturur, duyuya ve ısı düzenlemesine katkıda bulunur."},
 {id:"connective",name:"Bağ dokusu",color:"#aec3bb",description:"Kıkırdak, bağlar ve diğer bağ dokuları yapıları destekler, birbirine bağlar ve ayırır. Eklemleri dengeler ve mekanik yükleri dağıtır."}
];
var SYS={};SYSTEMS.forEach(function(s){SYS[s.id]=s});
/* Hangi beden: erkek (BodyParts3D) ya da kadın (HuBMAP). Seçim adres satırında (?sex=female) ve cihazda saklanır. */
var SEX=(function(){var m=/[?&]sex=(female|male)/.exec(location.search);if(m)return m[1];try{return localStorage.getItem("atlasSex")==="female"?"female":"male"}catch(e){return "male"}})();
var FEMALE=SEX==="female";
if(FEMALE){SYSTEMS.forEach(function(s){if(s.id==="reproductive")s.description="Burada gösterilen kadın üreme yapıları (rahim, yumurtalıklar, yumurta kanalları, vajina ve meme bezleri) yumurta üretimine, döllenmeye, gebeliğe ve cinsiyet hormonlarının üretimine katkı sağlar."})}
var DEFAULT_VISIBLE=["cardiac","sensory","skeletal","muscular","arterial","venous","nervous","respiratory","digestive","urinary","lymphatic","endocrine","reproductive","connective"].concat(FEMALE?["integumentary"]:[]);   // kadın modelinde iskelet ve kas kısmi olduğu için saydam deri kabuğu açık başlar
var ORGAN_SET=["cardiac","respiratory","digestive","urinary","endocrine","reproductive"];

var EXPL={
 "heart":"Göğüste yer alan kaslı bir pompa. Sağ yanı kanı akciğerlere, sol yanı vücut dolaşımına gönderir.",
 "liver":"Diyaframın sağ alt tarafında yer alan büyük bir organ. Emilen besinleri işler, safra üretir ve kanda taşınan birçok proteini sentezler.",
 "brain":"Sinir sisteminin merkez organı. Birbirine bağlı bölgeleri algıyı, hareketi, belleği, dili ve vücut işlevlerinin düzenlenmesini destekler.",
 "stomach":"Yemek borusu ile ince bağırsak arasında yer alan kaslı bir kese. Besini depolar, asit ve enzimlerle karıştırıp oniki parmak bağırsağına bırakır.",
 "spleen":"Karnın sol üst bölümünde yer alan lenfoid bir organ. Kanı süzer, yaşlanan kan hücrelerini ayıklar ve bağışıklık yanıtlarına katılır.",
 "pancreas":"Hem sindirim hem hormon işlevi olan karın organı. İnce bağırsağa enzim verir; insülin ve glukagon gibi hormonlar salgılar.",
 "urinary bladder":"Leğende yer alan kaslı bir depo. Böbreklerden üreterlerle gelen idrarı biriktirir.",
 "trachea":"Gırtlağı bronşlara bağlayan ana hava yolu. Kıkırdak destekleri, soluk alıp verirken hava yolunu açık tutar.",
 "diaphragm":"Göğüs ile karın boşluğunu ayıran geniş bir kas. Kasıldığında göğüs hacmini artırır ve akciğerlere hava çekilmesine yardım eder.",
 "kidney":"Karnın arka duvarında, omurganın iki yanında yer alan fasulye biçimli organ. Kanı süzer, idrar üretir; sıvı ve tuz dengesini düzenler.",
 "lung":"Göğüs kafesinde, kalbin iki yanında yer alan solunum organı. Oksijen kana geçer, karbondioksit dışarı atılır.",
 "gallbladder":"Karaciğerin altında yer alan küçük kese. Karaciğerin ürettiği safrayı depolar ve yağlı yemeklerde bağırsağa bırakır.",
 "small intestine":"Mideden sonra gelen uzun, kıvrımlı sindirim borusu bölümü. Besinlerin çoğu burada kana emilir.",
 "large intestine":"Sindirim borusunun son bölümü. Suyu ve tuzları emer, atığı dışkı olarak biriktirip dışarı yollar.",
 "esophagus":"Boğazı mideye bağlayan kaslı tüp. Yutulan lokmayı kas hareketleriyle (peristaltizm) mideye taşır.",
 "spinal cord":"Beyinden omurga kanalı içinde aşağı uzanan sinir demeti. Beyin ile vücut arasında bilgi taşır ve refleksleri yönetir.",
 "skull":"Beyni, gözleri ve kulakları koruyan kemik yapı; yüze de şeklini verir.",
 "femur":"Uyluktaki kemik; vücudun en uzun ve en güçlü kemiğidir. Yürürken ve koşarken vücut ağırlığını taşır.",
 "sternum":"Göğsün ortasında yer alan yassı kemik. Kaburgalarla birlikte göğüs kafesini oluşturur ve kalbin önünü korur.",
 "thyroid gland":"Boynun ön tarafındaki hormon bezi. Metabolizma hızını düzenleyen hormonlar salgılar."
};
function explanation(name,sys){
 var k=name.toLowerCase().replace(/^(left|right) /,"");
 return EXPL[k]||(SYS[sys]?SYS[sys].description:"");
}

/* Başlıca yapıların Türkçe karşılıkları (İngilizce FMA adı → Türkçe) */
var TRN={
 "uterus":"Rahim","body of uterus":"Rahim gövdesi","fundus of uterus":"Rahim tabanı (fundus)","cervix":"Rahim ağzı","uterine cervix":"Rahim ağzı","ovary":"Yumurtalık","fallopian tube":"Yumurta kanalı (fallop tüpü)","uterine tube":"Yumurta kanalı (fallop tüpü)","vagina":"Vajina","mammary gland":"Meme bezi","endometrium":"Rahim iç zarı (endometriyum)","myometrium":"Rahim kası (miyometriyum)","ligaments of uterus and ovaries":"Rahim ve yumurtalık bağları","round ligament of uterus":"Rahmin yuvarlak bağı","ovarian ligament":"Yumurtalık bağı","nipple":"Meme başı","areola":"Meme halkası (areola)","lungs":"Akciğerler","eyes":"Gözler","kidney":"Böbrek","renal pelvis":"Böbrek havuzu","renal pyramid":"Böbrek piramidi","renal papilla":"Böbrek papillası","jejenum":"Boş bağırsak","retina":"Ağ tabaka (retina)","iris":"İris","lens":"Göz merceği","cornea":"Saydam tabaka (kornea)","sclera":"Göz akı (sklera)",
 "heart":"Kalp","brain":"Beyin","cerebellum":"Beyincik","cerebrum":"Büyük beyin","brainstem":"Beyin sapı","brain stem":"Beyin sapı","medulla oblongata":"Omurilik soğanı","pons":"Pons (köprü)","corpus callosum":"Nasırlı cisim",
 "liver":"Karaciğer","stomach":"Mide","spleen":"Dalak","pancreas":"Pankreas","gallbladder":"Safra kesesi","urinary bladder":"İdrar kesesi (mesane)","trachea":"Soluk borusu (trakea)","bronchus":"Bronş",
 "kidney":"Böbrek","lung":"Akciğer","esophagus":"Yemek borusu","small intestine":"İnce bağırsak","large intestine":"Kalın bağırsak","duodenum":"Oniki parmak bağırsağı","jejunum":"Boş bağırsak","ileum":"Kıvrım bağırsağı","cecum":"Kör bağırsak","appendix":"Apandis (apandiks)","colon":"Kolon","rectum":"Rektum","anal canal":"Anal kanal",
 "diaphragm":"Diyafram","pericardium":"Kalp zarı (perikard)","thyroid gland":"Tiroid bezi","adrenal gland":"Böbreküstü bezi","thymus":"Timüs","pituitary gland":"Hipofiz bezi","larynx":"Gırtlak (larinks)","pharynx":"Yutak (farinks)","tongue":"Dil","tooth":"Diş","eyebrow":"Kaş","eyeball":"Göz küresi","eye":"Göz","ear":"Kulak","nose":"Burun",
 "skin":"Deri","skull":"Kafatası","mandible":"Çene kemiği","maxilla":"Üst çene kemiği","vertebral column":"Omurga","cervical vertebral column":"Boyun omurgası","thoracic vertebral column":"Sırt omurgası","lumbar vertebral column":"Bel omurgası","vertebra":"Omur","intervertebral disk":"Omurlar arası disk","sacrum":"Sakrum (kuyruk sokumu kemiği)","coccyx":"Koksiks (kuyruk kemiği)",
 "sternum":"Göğüs kemiği","rib":"Kaburga","rib cage":"Göğüs kafesi","clavicle":"Köprücük kemiği","scapula":"Kürek kemiği","humerus":"Kol kemiği (humerus)","radius":"Döner kemik (radius)","ulna":"Dirsek kemiği (ulna)","pelvis":"Leğen kemiği","hip bone":"Kalça kemiği","femur":"Uyluk kemiği (femur)","patella":"Diz kapağı","tibia":"Kaval kemiği (tibia)","fibula":"Baldır kemiği (fibula)",
 "spinal cord":"Omurilik","cranial nerve":"Kafa siniri","optic nerve":"Görme siniri","sciatic nerve":"Siyatik sinir","vagus nerve":"Vagus siniri",
 "aorta":"Aort (ana atardamar)","ascending aorta":"Çıkan aort","arch of aorta":"Aort kavsi","descending aorta":"İnen aort","abdominal aorta":"Karın aortu","superior vena cava":"Üst ana toplardamar","inferior vena cava":"Alt ana toplardamar","portal vein":"Kapı toplardamarı","common carotid artery":"Ortak şahdamarı","internal jugular vein":"İç şahdamarı","femoral artery":"Uyluk atardamarı","femoral vein":"Uyluk toplardamarı","pulmonary artery":"Akciğer atardamarı","pulmonary trunk":"Akciğer ana atardamarı",
 "right atrium":"Sağ kulakçık","left atrium":"Sol kulakçık","right ventricle":"Sağ karıncık","left ventricle":"Sol karıncık",
 "gluteus maximus":"Büyük kalça kası","biceps brachii":"İki başlı kol kası (biseps)","triceps brachii":"Üç başlı kol kası (triseps)","deltoid":"Deltoid (omuz kası)","trapezius":"Trapez kası","pectoralis major":"Büyük göğüs kası","latissimus dorsi":"Geniş sırt kası","rectus abdominis":"Düz karın kası","quadriceps femoris":"Dört başlı uyluk kası","gastrocnemius":"Baldır kası","sartorius":"Terzi kası","masseter":"Çiğneme kası",
 "prostate":"Prostat","testis":"Testis (erkek bezi)","scrotum":"Skrotum","penis":"Penis","ureter":"Üreter (idrar borusu)","urethra":"Üretra (idrar yolu)","hand":"El","foot":"Ayak","knee":"Diz","skeleton":"İskelet"
};
/* Genel arama sözcükleri (Türkçe kök → İngilizce parça) */
var TRW=[["kas","muscle"],["kemik","bone"],["atardamar","artery"],["toplardamar","vein"],["damar","artery"],["damar","vein"],["sinir","nerve"],["bagirsak","intestine"],["kaburga","rib"],["omur","vertebra"],["parmak","phalanx"],["parmak","finger"],["dis","tooth"],["beyin","cerebral"],["beyin","brain"],["akciger","lung"],["akciger","pulmonary"],["bobrek","renal"],["bobrek","kidney"],["karaciger","hepatic"],["karaciger","liver"],["kalp","cardiac"],["kalp","coronary"],["kalp","atrium"],["kalp","ventricle"],["mide","gastric"],["safra","biliary"],["kikirdak","cartilage"],["bag","ligament"],["kafatasi","cranial"],["omuz","shoulder"],["kol","arm"],["bacak","leg"],["ayak","foot"],["el ","hand"],["bilek","wrist"],["diz","knee"],["kalca","hip"],["goz","eye"],["goz","ocular"],["kulak","ear"],["boyun","cervical"],["bel","lumbar"],["sol","left"],["sag","right"]];
function fold(s){return String(s).toLocaleLowerCase("tr").replace(/ı/g,"i").replace(/ğ/g,"g").replace(/ü/g,"u").replace(/ş/g,"s").replace(/ö/g,"o").replace(/ç/g,"c").replace(/İ/g,"i").replace(/̇/g,"")}
function trName(name){
 var l=name.toLowerCase();if(TRN[l])return TRN[l];
 var f=/^(.+) \((left|right)\)( [a-z])?$/.exec(l);if(f)l=f[2]+" "+f[1];      // kadın modelindeki "ad (left)" biçimi
 if(TRN[l])return TRN[l];
 var m=/^(left|right) (.+)$/.exec(l);
 if(m&&TRN[m[2]])return (m[1]==="left"?"Sol ":"Sağ ")+TRN[m[2]].charAt(0).toLocaleLowerCase("tr")+TRN[m[2]].slice(1);
 return null;
}
var foldCache={};
function foldedNames(c){
 var f=foldCache[c.id];if(f)return f;
 var tr=trName(c.name);f=foldCache[c.id]={en:c.name.toLowerCase(),tr:tr?fold(tr):""};return f;
}

/* ------------------------------------------------------------------ durum */
var S={explode:0,visible:DEFAULT_VISIBLE.slice(),selected:[],isolate:false,view:"three-quarter",rotate:false,reset:0,inspectorOpen:false,ver:0};
var atlas=null,partsById=new Map(),counts={},activeSystems=[],chosen=null,panel=null,details=false,aboutOpen=false,query="";
var sceneApi=null;

function sysCountsInit(){
 counts={};SYSTEMS.forEach(function(s){counts[s.id]=0});
 atlas.parts.forEach(function(p){counts[p.system]=(counts[p.system]||0)+1;partsById.set(p.id,p)});
 activeSystems=SYSTEMS.filter(function(s){return counts[s.id]>0});
}
function visibleCount(){
 if(!atlas)return 0;var n=0;
 for(var i=0;i<atlas.parts.length;i++){var p=atlas.parts[i];
  if(S.isolate?S.selected.indexOf(p.id)>=0:(S.visible.indexOf(p.system)>=0||S.selected.indexOf(p.id)>=0))n++}
 return n;
}
function icon(path,size){return '<svg width="'+size+'" height="'+size+'" viewBox="0 0 24 24">'+path+'</svg>'}
var IC={
 x:'<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
 focus:'<circle cx="12" cy="12" r="3"/><path d="M3 7V5a2 2 0 0 1 2-2h2"/><path d="M17 3h2a2 2 0 0 1 2 2v2"/><path d="M21 17v2a2 2 0 0 1-2 2h-2"/><path d="M7 21H5a2 2 0 0 1-2-2v-2"/>',
 chev:'<path d="m9 18 6-6-6-6"/>',up:'<path d="M7 7h10v10"/><path d="M7 17 17 7"/>',
 rot:'<path d="M21 12a9 9 0 1 1-9-9c2.52 0 4.93 1 6.74 2.74L21 8"/><path d="M21 3v5h-5"/>',
 pause:'<rect x="14" y="4" width="4" height="16" rx="1"/><rect x="6" y="4" width="4" height="16" rx="1"/>'
};
function esc(s){return String(s).replace(/[&<>"]/g,function(c){return{"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]})}

/* ------------------------------------------------------------------ eylemler */
function bump(){S.ver++;ui()}
function choose(c){
 chosen=c;S.selected=c.elements.slice();S.isolate=false;S.rotate=false;details=true;panel=null;
 S.ver++;renderDetail();ui();
}
function choosePart(id){
 var p=partsById.get(id);if(!p)return;
 chosen={id:p.conceptId,name:p.name,elements:[id]};
 S.selected=[id];S.isolate=false;S.rotate=false;details=true;panel=null;
 S.ver++;renderDetail();ui();
}
function toggleSystem(id){
 details=false;S.selected=[];S.isolate=false;
 var i=S.visible.indexOf(id);if(i>=0)S.visible.splice(i,1);else S.visible.push(id);
 S.visible=S.visible.slice();bump();
}
function resetAll(){
 S.explode=0;S.visible=DEFAULT_VISIBLE.slice();S.selected=[];S.isolate=false;S.view="three-quarter";S.rotate=false;S.reset++;
 chosen=null;details=false;panel=null;$("exr").value=0;bump();
}
function setPanel(next){details=false;panel=(panel===next)?null:next;ui();if(panel==="search"){renderResults();setTimeout(function(){$("q").focus()},30)}}
function clearSelection(){S.selected=[];S.isolate=false;details=false;bump()}

/* ------------------------------------------------------------------ arayüz kurulumu */
function buildLayers(){
 var list=$("sysList");list.innerHTML="";
 activeSystems.forEach(function(s){
  var row=document.createElement("div");row.className="system-row";row.dataset.id=s.id;
  row.innerHTML='<button class="system-name" title="Yalnızca '+esc(s.name.toLocaleLowerCase("tr"))+' göster"><span class="system-dot" style="background:'+s.color+'"></span>'+esc(s.name)+'<span class="system-count">'+counts[s.id]+'</span></button><button class="sw" role="switch" aria-label="'+esc(s.name)+' göster"><i></i></button>';
  row.firstChild.onclick=function(){S.visible=[s.id];S.isolate=false;S.selected=[];details=false;bump()};
  row.lastChild.onclick=function(){toggleSystem(s.id)};
  list.appendChild(row);
 });
 $("sysCount").textContent=activeSystems.length;
 $("metaCount").textContent=fmt(atlas.parts.length);
}
function renderResults(){
 var box=$("results"),term=query.toLocaleLowerCase("tr").trim(),ft=fold(term),res;
 if(!atlas){box.innerHTML="";return}
 if(!term){
  res=["heart","brain","liver","stomach","spleen","pancreas","urinary bladder","trachea"].map(function(n){return atlas.concepts.find(function(c){return c.name.toLowerCase()===n})}).filter(Boolean);
 }else{
  var extra=[];TRW.forEach(function(w){if(ft.length>=2&&(w[0].indexOf(ft)===0||(ft.length>=w[0].length&&ft.indexOf(w[0])===0)))extra.push(w[1])});
  res=atlas.concepts.filter(function(c){
   var f=foldedNames(c);
   if(f.en.indexOf(term)>=0||c.id.toLowerCase().indexOf(term)>=0)return true;
   if(f.tr&&f.tr.indexOf(ft)>=0)return true;
   for(var i=0;i<extra.length;i++)if(f.en.indexOf(extra[i])>=0)return true;
   return false;
  });
  res.sort(function(a,b){
   var fa=foldedNames(a),fb=foldedNames(b);
   var sa=(fa.tr.indexOf(ft)===0||fa.en.indexOf(term)===0)?0:1,sb=(fb.tr.indexOf(ft)===0||fb.en.indexOf(term)===0)?0:1;
   return sa-sb||a.name.length-b.name.length;
  });
  res=res.slice(0,80);
 }
 if(!res.length){box.innerHTML='<div class="search-empty">Aramanızla eşleşen yapı yok.</div>'}
 else{
  box.innerHTML=res.map(function(c,i){var tr=trName(c.name);
   return '<button data-i="'+i+'"><span class="nm">'+(tr?esc(tr)+'<small>'+esc(c.name)+'</small>':'<span style="text-transform:capitalize">'+esc(c.name)+'</span>')+'</span><span class="small-number">'+c.elements.length+' parça</span></button>'}).join("");
  box.onclick=function(e){var b=e.target.closest("button");if(b)choose(res[+b.dataset.i])};
 }
 $("searchNote").textContent=term?"En fazla 80 eşleşme gösterilir. Daha küçük yapıları bulmak için aramayı daraltın.":"Büyük bir organla başlayın ya da adlandırılmış tüm yapılarda arayın.";
}
function renderDetail(){
 var box=$("detail");
 if(!chosen||!S.selected.length){box.innerHTML="";return}
 var sel=S.selected.map(function(id){return partsById.get(id)}).filter(Boolean),first=sel[0],sys=SYS[first.system];
 var tr=trName(chosen.name),known=EXPL[chosen.name.toLowerCase().replace(/^(left|right) /,"")];
 var h='<button class="close" id="dClose" aria-label="Kapat">'+icon(IC.x,18)+'</button>';
 h+='<div class="detail-header"><div class="detail-accent" style="background:'+(sys?sys.color:"#999")+'"></div><div class="eyebrow">'+esc(sys?sys.name:"Anatomi")+'</div>';
 h+='<h2 class="structure-title" id="dTitle" tabindex="-1"'+(tr?'':' style="text-transform:capitalize"')+'>'+esc(tr||chosen.name)+'</h2>'+(tr?'<div class="structure-sub">'+esc(chosen.name)+'</div>':'')+'</div>';
 h+='<div class="detail-scroll"><p class="structure-description">'+esc(explanation(chosen.name,first.system))+'</p>';
 if(!known)h+='<span class="context-note">Bu bir sistem özeti; yapı kaynak anatomiden belirlendi.</span>';
 h+='<div class="structure-meta"><span>Atlas referansı<strong>'+esc(chosen.id)+'</strong></span><span>Seçili parça<strong>'+fmt(S.selected.length)+'</strong></span></div>';
 if(sel.length>1){
  h+='<div class="member-list"><h3>İçerdiği yapılar</h3>'+sel.slice(0,50).map(function(p){var t=trName(p.name);return '<button data-id="'+p.id+'"><span>'+esc(t||p.name)+'</span>'+icon(IC.chev,14)+'</button>'}).join("");
  if(sel.length>50)h+='<p>Ve '+(sel.length-50)+' modellenmiş parça daha.</p>';
  h+='</div>';
 }
 h+='<a class="source-link" href="https://lifesciencedb.jp/bp3d/" target="_blank" rel="noreferrer">Anatomik kaynağı gör '+icon(IC.up,14)+'</a></div>';
 h+='<div class="detail-actions"><button class="primary-action'+(S.isolate?" active":"")+'" id="dIso">'+icon(IC.focus,18)+(S.isolate?"Çevredeki anatomiyi göster":"Yapıyı yalıt")+icon(IC.chev,16)+'</button><button class="secondary-action" id="dClear">Seçimi kaldır</button></div>';
 box.innerHTML=h;
 $("dClose").onclick=function(){details=false;ui()};
 $("dIso").onclick=function(){S.isolate=!S.isolate;S.explode=0;$("exr").value=0;S.ver++;renderDetail();ui()};
 $("dClear").onclick=clearSelection;
 var ml=box.querySelector(".member-list");if(ml)ml.onclick=function(e){var b=e.target.closest("button");if(b)choosePart(b.dataset.id)};
}

function ui(){
 var hasSel=S.selected.length>0;S.inspectorOpen=details&&hasSel;
 document.body.classList.toggle("has-detail",S.inspectorOpen);
 $("detail").hidden=!S.inspectorOpen;$("detail").classList.toggle("is-isolated",S.isolate);
 $("layers").classList.toggle("mobile-open",panel==="layers");
 $("searchPanel").hidden=panel!=="search";
 $("about").hidden=!aboutOpen;$("scrim").hidden=!aboutOpen;
 $("bLayers").setAttribute("aria-expanded",panel==="layers");
 // katmanlar
 Array.prototype.forEach.call($("sysList").children,function(row){
  var on=S.visible.indexOf(row.dataset.id)>=0;row.classList.toggle("enabled",on);row.lastChild.setAttribute("aria-checked",on)});
 var all=activeSystems.length>0&&activeSystems.every(function(x){return S.visible.indexOf(x.id)>=0});
 var skel=S.visible.length===1&&S.visible[0]==="skeletal";
 var org=S.visible.length===6&&ORGAN_SET.every(function(id){return S.visible.indexOf(id)>=0});
 var pb=document.querySelectorAll("[data-preset]");
 pb[0].setAttribute("aria-pressed",all);pb[1].setAttribute("aria-pressed",skel);pb[2].setAttribute("aria-pressed",org);
 $("visCount").textContent=fmt(visibleCount())+" parça görünür";
 // kamera
 Array.prototype.forEach.call(document.querySelectorAll("[data-view]"),function(b){
  var v=b.dataset.view;b.classList.toggle("active",S.view===v);b.setAttribute("aria-pressed",S.view===v);b.disabled=S.explode>.8&&v!=="front"});
 $("bRot").disabled=S.explode>=.4;$("bRot").classList.toggle("active",S.rotate);
 $("icRot").innerHTML=S.rotate?IC.pause:IC.rot;
 $("bRot").setAttribute("aria-label",S.rotate?"Dönmeyi duraklat":"Vücudu döndür");
 // alt dock
 var pct=Math.round(S.explode*100);$("exOut").innerHTML=pct+"<span>%</span>";$("exr").style.setProperty("--p",pct+"%");
 $("caption").textContent=S.isolate?(chosen?(trName(chosen.name)||chosen.name).toLocaleLowerCase("tr"):"Seçili yapı"):S.explode>.95?"Her parça ayrı":S.explode>.05?"Parçalar ayrılıyor":(FEMALE?"Yetişkin kadın v":"Yetişkin erkek v")+"ücudu";
 $("footHint").innerHTML=(S.explode>.8?"Sürükle: kaydır.":"Sürükle: döndür.")+" İki parmak: yakınlaştır. Dokun: incele.";
}

function wireUi(){
 $("bSearch").onclick=function(){setPanel("search")};
 /* Erkek / Kadın geçişi: seçimi sakla ve sayfayı o bedenle yeniden aç */
 Array.prototype.forEach.call(document.querySelectorAll("#sexSwitch button"),function(b){
  var on=b.getAttribute("data-sex")===SEX;b.classList.toggle("on",on);b.setAttribute("aria-pressed",on?"true":"false");
  b.onclick=function(){var v=b.getAttribute("data-sex");if(v===SEX)return;try{localStorage.setItem("atlasSex",v)}catch(e){}location.replace("index.html?sex="+v)};
 });
 if(FEMALE){var c=$("caption");if(c)c.textContent="Yetişkin kadın vücudu";var am=$("aboutMale"),af=$("aboutFemale");if(am)am.hidden=true;if(af)af.hidden=false}
 else{var c2=$("caption");if(c2)c2.textContent="Yetişkin erkek vücudu"}
 $("searchClose").onclick=function(){panel=null;ui()};
 $("bAbout").onclick=$("bCredits").onclick=function(){details=false;panel=null;aboutOpen=true;ui()};
 $("aboutClose").onclick=$("scrim").onclick=function(){aboutOpen=false;ui()};
 $("bLayers").onclick=function(){setPanel("layers")};
 $("layersClose").onclick=function(){panel=null;ui()};
 $("q").oninput=function(){query=this.value;renderResults()};
 $("q").onkeydown=function(e){if(e.key==="Escape"){panel=null;ui()}else if(e.key==="Enter"){var b=$("results").querySelector("button");if(b)b.click()}};
 document.addEventListener("keydown",function(e){
  if(e.key==="/"&&e.target.tagName!=="INPUT"){e.preventDefault();if(panel!=="search")setPanel("search")}
  else if(e.key==="Escape"){if(aboutOpen){aboutOpen=false;ui()}else if(panel){panel=null;ui()}}
 });
 Array.prototype.forEach.call(document.querySelectorAll("[data-preset]"),function(b){
  b.onclick=function(){var k=b.dataset.preset;S.selected=[];S.isolate=false;details=false;
   S.visible=k==="all"?activeSystems.map(function(x){return x.id}):k==="skeleton"?["skeletal"]:ORGAN_SET.slice();bump()}});
 $("hideAll").onclick=function(){S.visible=[];S.selected=[];S.isolate=false;details=false;bump()};
 Array.prototype.forEach.call(document.querySelectorAll("[data-view]"),function(b){
  b.onclick=function(){S.view=b.dataset.view;S.reset++;S.rotate=false;ui()}});
 $("bRot").onclick=function(){S.rotate=!S.rotate;ui()};
 $("bReset").onclick=resetAll;$("dockReset").onclick=resetAll;
 $("exr").oninput=function(){var v=+this.value;S.explode=v/100;if(v>80)S.view="front";S.rotate=false;ui()};
}

/* ------------------------------------------------------------------ yardımcılar */
function col(hex){return new T.Color(hex).convertSRGBToLinear()}

/* Sürükle-yakınlaştır-kaydır kamera denetimi (OrbitControls benzeri, sönümlemeli) */
function Orbit(cam,dom){
 var me=this,sph=new T.Spherical(),sd=new T.Spherical(0,0,0),pan=new T.Vector3(),off=new T.Vector3(),v=new T.Vector3(),scale=1,ptr=new Map(),prevPos=new T.Vector3(),prevTgt=new T.Vector3();
 me.target=new T.Vector3();me.enableRotate=true;me.autoRotate=false;me.autoRotateSpeed=.65;me.minDistance=.07;me.maxDistance=40;me.maxPolar=Math.PI*.96;me.damping=.085;
 function H(){return Math.max(1,dom.clientHeight)}
 function rotate(dx,dy){sd.theta-=2*Math.PI*dx/H();sd.phi-=2*Math.PI*dy/H()}
 function panBy(dx,dy){
  off.copy(cam.position).sub(me.target);var dist=off.length()*Math.tan(cam.fov/2*Math.PI/180);
  v.setFromMatrixColumn(cam.matrix,0).multiplyScalar(-2*dx*dist/H());pan.add(v);
  v.setFromMatrixColumn(cam.matrix,1).multiplyScalar(2*dy*dist/H());pan.add(v);
 }
 dom.addEventListener("pointerdown",function(e){
  ptr.set(e.pointerId,{x:e.clientX,y:e.clientY});try{dom.setPointerCapture(e.pointerId)}catch(_){}
 });
 dom.addEventListener("pointermove",function(e){
  var p=ptr.get(e.pointerId);if(!p)return;
  var nx=e.clientX,ny=e.clientY;
  if(ptr.size===1){
   var dx=nx-p.x,dy=ny-p.y;
   if(!me.enableRotate||(e.pointerType==="mouse"&&(e.buttons&6)))panBy(dx,dy);else rotate(dx,dy);
  }else if(ptr.size===2){
   var other=null;ptr.forEach(function(q,id){if(id!==e.pointerId)other=q});
   var d0=Math.hypot(p.x-other.x,p.y-other.y),d1=Math.hypot(nx-other.x,ny-other.y);
   if(d1>1&&d0>1)scale*=d0/d1;
   panBy(((nx+other.x)-(p.x+other.x))/2,((ny+other.y)-(p.y+other.y))/2);
  }
  p.x=nx;p.y=ny;
 });
 function end(e){ptr.delete(e.pointerId);try{dom.releasePointerCapture(e.pointerId)}catch(_){}}
 dom.addEventListener("pointerup",end);dom.addEventListener("pointercancel",end);
 dom.addEventListener("wheel",function(e){e.preventDefault();scale*=Math.exp(Math.max(-120,Math.min(120,e.deltaY))*.0015)},{passive:false});
 dom.addEventListener("contextmenu",function(e){e.preventDefault()});
 me.stop=function(){sd.theta=sd.phi=0;pan.set(0,0,0);scale=1};
 me.update=function(){
  prevPos.copy(cam.position);prevTgt.copy(me.target);
  off.copy(cam.position).sub(me.target);sph.setFromVector3(off);
  if(me.autoRotate&&ptr.size===0)sd.theta-=2*Math.PI/60/60*me.autoRotateSpeed;
  sph.theta+=sd.theta*me.damping;sph.phi+=sd.phi*me.damping;
  sph.phi=Math.max(1e-4,Math.min(me.maxPolar,sph.phi));sph.makeSafe();
  sph.radius=Math.max(me.minDistance,Math.min(me.maxDistance,sph.radius*scale));
  me.target.addScaledVector(pan,me.damping);
  off.setFromSpherical(sph);cam.position.copy(me.target).add(off);cam.lookAt(me.target);
  sd.theta*=1-me.damping;sd.phi*=1-me.damping;pan.multiplyScalar(1-me.damping);scale=1;
  return prevPos.distanceToSquared(cam.position)>1e-14||prevTgt.distanceToSquared(me.target)>1e-14;
 };
}

/* Basit satır-paketleme düzeni (patlatılmış görünüm) */
function explosionLayout(parts,aspect){
 var cards=parts.map(function(p){return{id:p.id,width:Math.max(.035,p.bounds[1][0]-p.bounds[0][0])+.04,height:Math.max(.035,p.bounds[1][1]-p.bounds[0][1])+.04}});
 var area=0,maxW=.3;cards.forEach(function(c){area+=c.width*c.height;if(c.width>maxW)maxW=c.width});
 var target=Math.max(maxW,Math.sqrt(area*Math.max(.5,Math.min(1.5,aspect||1)))*1.18);
 cards.sort(function(a,b){return b.height-a.height||(a.id<b.id?-1:a.id>b.id?1:0)});
 var cells=new Map(),x=0,y=0,row=0,used=0;
 cards.forEach(function(c){
  if(x>0&&x+c.width>target){x=0;y+=row;row=0}
  cells.set(c.id,{x:x+c.width/2,y:-y-c.height/2,width:c.width,height:c.height});
  x+=c.width;used=Math.max(used,x);row=Math.max(row,c.height);
 });
 var height=y+row;
 cells.forEach(function(c){c.x-=used/2;c.y+=height/2});
 return{cells:cells,width:used,height:height};
}

/* dokunma / sürükleme ayrımı */
function PointerTap(){this.active=new Map();this.blocked=false}
PointerTap.prototype.down=function(id,x,y,th){if(this.active.size===0)this.blocked=false;this.active.set(id,{x:x,y:y,th:th});if(this.active.size>1)this.blocked=true};
PointerTap.prototype.move=function(id,x,y){var s=this.active.get(id);if(s&&Math.hypot(x-s.x,y-s.y)>s.th)this.blocked=true};
PointerTap.prototype.up=function(id,x,y){this.move(id,x,y);var t=this.active.has(id)&&this.active.size===1&&!this.blocked;this.active.delete(id);return t};
PointerTap.prototype.cancel=function(id){this.active.delete(id);this.blocked=true};

/* Gzip'li model dosyasını çöz */
async function decodeModel(resp,expected){
 if(!resp.ok)throw new Error("Bir anatomi dosyası yüklenemedi.");
 var payload=await resp.arrayBuffer(),sig=new Uint8Array(payload,0,Math.min(2,payload.byteLength));
 var gz=sig[0]===0x1f&&sig[1]===0x8b,buf=payload;
 if(gz){
  if(typeof DecompressionStream==="undefined")throw new Error("Bu cihazın WebView sürümü çok eski. Lütfen Android System WebView’i güncelleyin.");
  buf=await new Response(new Blob([payload]).stream().pipeThrough(new DecompressionStream("gzip"))).arrayBuffer();
 }
 if(buf.byteLength!==expected)throw new Error("Bir anatomi dosyası eksik geldi. Lütfen yeniden yükleyin.");
 return buf;
}

/* Işık için basit "oda" ortamı (RoomEnvironment benzeri) */
function roomScene(){
 var sc=new T.Scene(),box=new T.BoxGeometry();
 var room=new T.Mesh(box,new T.MeshBasicMaterial({color:new T.Color(.30,.30,.31),side:T.BackSide}));room.position.set(-.757,13.219,.717);room.scale.set(31.713,28.305,28.591);sc.add(room);
 function block(p,ry,s,c){var m=new T.Mesh(box,new T.MeshBasicMaterial({color:new T.Color(c,c,c)}));m.position.set(p[0],p[1],p[2]);m.rotation.y=ry;m.scale.set(s[0],s[1],s[2]);sc.add(m)}
 block([-10.906,2.009,1.846],-.195,[2.328,7.905,4.651],.46);block([-5.607,-.754,-.758],.994,[1.97,1.534,3.955],.5);block([6.167,-.857,7.803],.561,[3.927,6.285,3.687],.42);
 block([-2.017,.018,6.124],.333,[2.002,4.566,2.064],.5);block([2.291,-.756,-2.621],-.286,[1.546,1.552,1.496],.45);block([-2.193,-.369,-5.547],.516,[3.875,3.487,2.986],.4);
 function lamp(p,s,i){var m=new T.Mesh(box,new T.MeshBasicMaterial({color:new T.Color(i,i,i)}));m.position.set(p[0],p[1],p[2]);m.scale.set(s[0],s[1],s[2]);sc.add(m)}
 lamp([-16.116,14.37,8.208],[.1,2.428,2.739],50);lamp([-16.109,18.021,-8.207],[.1,2.425,2.751],50);lamp([14.904,12.198,-1.832],[.15,4.265,6.331],17);
 lamp([-.462,8.89,14.52],[4.38,5.441,.088],43);lamp([3.235,11.486,-12.541],[2.5,2.0,.1],20);lamp([0,20,0],[2,.1,2],40);
 return sc;
}

/* ------------------------------------------------------------------ sahne */
function initScene(){
 var el=$("scene"),canvas=$("c"),hover=$("hover");
 var renderer;
 try{renderer=new T.WebGLRenderer({canvas:canvas,antialias:true,alpha:true,powerPreference:"high-performance"})}
 catch(e){showError("Bu cihaz 3D görüntüleyiciyi başlatamadı. WebGL etkin bir tarayıcı deneyin.");return}
 renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,innerWidth<768?1.5:2));
 renderer.setClearColor(0x000000,0);renderer.outputEncoding=T.sRGBEncoding;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.12;
 var scene=new T.Scene(),camera=new T.PerspectiveCamera(34,1,.005,100),controls=new Orbit(camera,canvas);
 camera.position.set(1.4,1.05,3.6);controls.target.set(0,.85,0);
 var pm=new T.PMREMGenerator(renderer);scene.environment=pm.fromScene(roomScene(),.04).texture;pm.dispose();
 scene.add(new T.HemisphereLight(0xffffff,col("#a7acb2"),.5));
 var key=new T.DirectionalLight(0xfffaf4,.72);key.position.set(-2,4,3);scene.add(key);
 var rim=new T.DirectionalLight(0xe9f0ff,.56);rim.position.set(2,2,-3);scene.add(rim);
 var ground=new T.Mesh(new T.CircleGeometry(.9,96),new T.MeshStandardMaterial({color:col("#d5d9dc"),roughness:1}));ground.rotation.x=-Math.PI/2;ground.position.y=-.019;scene.add(ground);
 var platform=new T.Mesh(new T.CylinderGeometry(.68,.7,.028,100),new T.MeshStandardMaterial({color:col("#eeeeec"),metalness:.12,roughness:.67}));platform.position.y=-.016;scene.add(platform);
 var ring=new T.Mesh(new T.RingGeometry(.63,.632,128),new T.MeshBasicMaterial({color:col("#8c969f"),transparent:true,opacity:.4,side:T.DoubleSide}));ring.rotation.x=-Math.PI/2;ring.position.y=.001;scene.add(ring);
 var inner=new T.Mesh(new T.RingGeometry(.55,.551,128),new T.MeshBasicMaterial({color:col("#a4aeb8"),transparent:true,opacity:.16,side:T.DoubleSide}));inner.rotation.x=-Math.PI/2;inner.position.y=.001;scene.add(inner);

 var N=atlas.parts.length,width=T.MathUtils.ceilPowerOfTwo(N);
 var data=new Float32Array(width*4),partTexture=new T.DataTexture(data,width,1,T.RGBAFormat,T.FloatType);partTexture.needsUpdate=true;
 var selData=new Uint8Array(width*4),selTexture=new T.DataTexture(selData,width,1);selTexture.needsUpdate=true;
 var pickers=new Array(N),pickMat=new T.MeshBasicMaterial({side:T.DoubleSide});
 var centers=atlas.parts.map(function(p){return new T.Vector3().fromArray(p.bounds[0]).add(new T.Vector3().fromArray(p.bounds[1])).multiplyScalar(.5)});
 var offsets=[],bounds=atlas.parts.map(function(p){return new T.Box3(new T.Vector3().fromArray(p.bounds[0]),new T.Vector3().fromArray(p.bounds[1]))});
 var packW=1,packH=1;
 var markerPos=new Float32Array(N*3),markerGeo=new T.BufferGeometry();markerGeo.setAttribute("position",new T.BufferAttribute(markerPos,3));
 var markerMat=new T.PointsMaterial({color:col("#64748b"),size:5,sizeAttenuation:false,transparent:true,opacity:.72,depthTest:false});
 markerMat.onBeforeCompile=function(sh){sh.fragmentShader=sh.fragmentShader.replace("#include <clipping_planes_fragment>","#include <clipping_planes_fragment>\nif (distance(gl_PointCoord, vec2(0.5)) > 0.5) discard;")};
 var markers=new T.Points(markerGeo,markerMat);markers.frustumCulled=false;markers.renderOrder=10;markers.visible=false;scene.add(markers);

 function materialFor(system){
  var integ=system==="integumentary";
  var m=new T.MeshStandardMaterial({color:col((SYS[system]||{}).color||"#aebbb8"),metalness:.08,roughness:.53,side:T.DoubleSide,transparent:integ,opacity:integ?.1:1,depthWrite:!integ});
  m.onBeforeCompile=function(sh){
   sh.uniforms.partState={value:partTexture};sh.uniforms.selectionState={value:selTexture};sh.uniforms.stateWidth={value:width};
   sh.vertexShader="attribute float partIndex; uniform sampler2D partState; uniform sampler2D selectionState; uniform float stateWidth; varying float partVisible; varying float partSelected;\n"+sh.vertexShader;
   sh.vertexShader=sh.vertexShader.replace("#include <begin_vertex>","#include <begin_vertex>\nvec2 stateUv = vec2((partIndex + 0.5) / stateWidth, 0.5); vec4 pstate = texture2D(partState, stateUv); transformed += pstate.xyz; partVisible = pstate.w; partSelected = texture2D(selectionState, stateUv).r;");
   sh.fragmentShader="varying float partVisible; varying float partSelected;\n"+sh.fragmentShader;
   sh.fragmentShader=sh.fragmentShader.replace("#include <clipping_planes_fragment>","#include <clipping_planes_fragment>\nif (partVisible < 0.5) discard;");
   sh.fragmentShader=sh.fragmentShader.replace("#include <color_fragment>","#include <color_fragment>\ndiffuseColor.rgb = mix(diffuseColor.rgb, vec3(0.42, 0.85, 0.78), partSelected * 0.75);");
  };
  m.customProgramCacheKey=function(){return "atlas-part"};
  return m;
 }
 var mats=new Map();SYSTEMS.forEach(function(s){mats.set(s.id,materialFor(s.id))});

 var disposed=false,ready=false,dirty=true,lastVer=-1,lastView="",lastReset=-1,lastIsolate="",layoutKey="",amount=0,loaded=0;
 var abortCtl=typeof AbortController!=="undefined"?new AbortController():null;

 async function loadChunk(ci){
  var ch=atlas.chunks[ci],url=(ch.gzip||ch.url).replace(/^\//,"");
  var resp=await fetch(url,abortCtl?{signal:abortCtl.signal}:undefined);
  var buffer=await decodeModel(resp,ch.bytes);if(disposed)return;
  var groups={};
  atlas.parts.forEach(function(p,i){
   if(p.chunk!==ci)return;
   var pos=new Float32Array(buffer,p.positions,p.vertexCount*3),nor=new Int16Array(buffer,p.normals,p.vertexCount*3),ind=new Uint32Array(buffer,p.indices,p.indexCount);
   var g=new T.BufferGeometry();g.setAttribute("position",new T.BufferAttribute(pos,3));g.setAttribute("normal",new T.BufferAttribute(nor,3,true));g.setIndex(new T.BufferAttribute(ind,1));
   g.boundingBox=bounds[i].clone();g.boundingSphere=new T.Sphere(centers[i].clone(),bounds[i].getSize(new T.Vector3()).length()/2+1e-4);
   var pick=new T.Mesh(g,pickMat);pick.matrixAutoUpdate=false;pickers[i]=pick;
   (groups[p.system]=groups[p.system]||[]).push({p:p,i:i,pos:pos,nor:nor,ind:ind});
  });
  Object.keys(groups).forEach(function(system){
   var list=groups[system],nv=0,ni=0;list.forEach(function(o){nv+=o.p.vertexCount;ni+=o.p.indexCount});
   var P=new Float32Array(nv*3),Nn=new Int16Array(nv*3),I=new Uint32Array(ni),PI=new Float32Array(nv),vo=0,io=0;
   list.forEach(function(o){
    P.set(o.pos,vo*3);Nn.set(o.nor,vo*3);PI.fill(o.i,vo,vo+o.p.vertexCount);
    for(var k=0;k<o.ind.length;k++)I[io+k]=o.ind[k]+vo;
    vo+=o.p.vertexCount;io+=o.p.indexCount;
   });
   var geo=new T.BufferGeometry();geo.setAttribute("position",new T.BufferAttribute(P,3));geo.setAttribute("normal",new T.BufferAttribute(Nn,3,true));geo.setAttribute("partIndex",new T.BufferAttribute(PI,1));geo.setIndex(new T.BufferAttribute(I,1));
   var mesh=new T.Mesh(geo,mats.get(system));mesh.frustumCulled=false;scene.add(mesh);
  });
  lastVer=-1;loaded++;setProgress(Math.round(loaded/atlas.chunks.length*100));dirty=true;
 }
 function setProgress(n){
  $("loadBar").style.width=n+"%";$("loadTxt").textContent=n+"% · "+fmt(N)+" parça yükleniyor";
  if(n>=100)$("loading").hidden=true;
 }
 (async function(){
  try{
   var cursor=0;
   await Promise.all([0,1,2].map(async function(){while(cursor<atlas.chunks.length){var i=cursor++;await loadChunk(i)}}));
   if(!disposed){ready=true;dirty=true;$("loading").hidden=true}
  }catch(e){if(!disposed&&!(e&&e.name==="AbortError"))showError(e&&e.message?e.message:"Anatomi yüklenemedi.")}
 })();

 function fit(view,extent){
  extent=extent||0;
  var mobile=el.clientWidth<768,fov=T.MathUtils.degToRad(camera.fov/2),h=el.clientHeight;
  var normalDistance=mobile?Math.max(4.5,1.8*h/Math.max(160,h-350)/(2*Math.tan(fov))):4;
  var reserved=mobile?350:270,availAspect=Math.max(.35,(el.clientWidth-(mobile?40:340))/Math.max(160,h-reserved));
  var atlasDistance=Math.max(packH,packW/availAspect)/(2*Math.tan(fov))*(h/Math.max(160,h-reserved))*1.08;
  var distance=T.MathUtils.lerp(normalDistance,Math.max(.2,atlasDistance),extent);if(extent>.8)view="front";
  var dir=view==="front"?new T.Vector3(0,.02,1):view==="back"?new T.Vector3(0,.02,-1):view==="side"?new T.Vector3(1,.02,0):new T.Vector3(.35,.06,1).normalize();
  controls.stop();
  controls.target.set(extent>.1&&el.clientWidth>767?-packW*.12:0,extent>.1||mobile?.85:.68,0);
  camera.position.copy(controls.target).addScaledVector(dir,distance);controls.update();dirty=true;
 }
 function resize(){
  layoutKey="";lastVer=-1;
  renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,el.clientWidth<768||el.clientHeight<600?1.5:2));
  camera.aspect=el.clientWidth/Math.max(1,el.clientHeight);camera.updateProjectionMatrix();renderer.setSize(el.clientWidth,el.clientHeight,false);
  fit(S.view,amount);
 }
 var ro=new ResizeObserver(resize);ro.observe(el);

 var targets=[],projected=new T.Vector3();
 function findTarget(x,y,radius){
  var best=-1,score=Infinity;
  for(var k=0;k<targets.length;k++){var t=targets[k];
   var dx=Math.max(t.left-x,0,x-t.right),dy=Math.max(t.top-y,0,y-t.bottom),d=Math.hypot(dx,dy);if(d>radius)continue;
   var cand=d+Math.hypot(t.x-x,t.y-y)*.025;if(cand<score){score=cand;best=t.index}}
  return best;
 }
 var raycaster=new T.Raycaster(),pointer=new T.Vector2(),tap=new PointerTap(),worldBox=new T.Box3(),hitPoint=new T.Vector3();
 canvas.addEventListener("pointerdown",function(e){hover.hidden=true;tap.down(e.pointerId,e.clientX,e.clientY,e.pointerType==="touch"?12:5)});
 canvas.addEventListener("pointermove",function(e){
  tap.move(e.pointerId,e.clientX,e.clientY);
  if(e.buttons||amount<.5||e.pointerType==="touch"){hover.hidden=true;return}
  var r=el.getBoundingClientRect(),x=e.clientX-r.left,y=e.clientY-r.top,idx=findTarget(x,y,12);
  hover.hidden=idx<0;canvas.style.cursor=idx<0?"grab":"pointer";
  if(idx>=0){var nm=atlas.parts[idx].name;hover.textContent=trName(nm)||nm;hover.style.left=Math.max(8,Math.min(x+14,el.clientWidth-260))+"px";hover.style.top=Math.max(8,Math.min(y+18,el.clientHeight-55))+"px"}
 });
 canvas.addEventListener("pointercancel",function(e){tap.cancel(e.pointerId)});
 canvas.addEventListener("pointerup",function(e){
  var valid=tap.up(e.pointerId,e.clientX,e.clientY);if(!valid||!ready)return;
  var r=canvas.getBoundingClientRect();pointer.set((e.clientX-r.left)/r.width*2-1,-(e.clientY-r.top)/r.height*2+1);raycaster.setFromCamera(pointer,camera);
  var nearest=Infinity,found=-1,hasSolid=atlas.parts.some(function(p,i){return p.system!=="integumentary"&&data[i*4+3]>.5});
  for(var i=0;i<N;i++){var mesh=pickers[i];
   if(!mesh||data[i*4+3]<.5||(hasSolid&&atlas.parts[i].system==="integumentary"))continue;
   worldBox.copy(bounds[i]).translate(mesh.position);if(!raycaster.ray.intersectBox(worldBox,hitPoint))continue;
   var hits=raycaster.intersectObject(mesh,false);if(hits[0]&&hits[0].distance<nearest){nearest=hits[0].distance;found=i}
  }
  if(found<0&&amount>.45)found=findTarget(e.clientX-r.left,e.clientY-r.top,e.pointerType==="touch"?24:16);
  if(found>=0){hover.hidden=true;choosePart(atlas.parts[found].id)}
 });
 canvas.addEventListener("webglcontextlost",function(e){e.preventDefault();showError("3D oturumu cihaz tarafından duraklatıldı. Devam etmek için yeniden yükleyin.")});

 var clock=new T.Clock(),frame=0,sIdxCache=SYSTEMS.map(function(s){return s.id});
 function animate(){
  if(disposed)return;frame=requestAnimationFrame(animate);
  var dt=Math.min(clock.getDelta(),.05),s=S;
  var changed=lastVer!==s.ver,moving=Math.abs(amount-s.explode)>.0001;
  if(moving){amount=T.MathUtils.damp(amount,s.explode,8,dt);dirty=true}
  if(changed||moving){
   var vis={},sel={};s.visible.forEach(function(k){vis[k]=1});s.selected.forEach(function(k){sel[k]=1});
   var visibleParts=atlas.parts.filter(function(p){return s.isolate?sel[p.id]:(vis[p.system]||sel[p.id])});
   var nextKey=visibleParts.length+":"+visibleParts.map(function(p){return p.id}).join(",")+":"+camera.aspect.toFixed(3);
   if(nextKey!==layoutKey){
    var lay=explosionLayout(visibleParts,camera.aspect);packW=lay.width;packH=lay.height;
    atlas.parts.forEach(function(p,i){var cell=lay.cells.get(p.id);offsets[i]=cell?new T.Vector3(cell.x,cell.y+.85,0):centers[i].clone()});
    layoutKey=nextKey;if(amount>.05&&!s.isolate)fit(s.view,Math.max(0,(amount-.3)/.7));
   }
   for(var i=0;i<N;i++){
    var p=atlas.parts[i],c=centers[i],dest=offsets[i],dx=0,dy=0,dz=0;
    var group=sIdxCache.indexOf(p.system),angle=group/SYSTEMS.length*Math.PI*2;
    if(amount<=.45){var t0=amount/.45;dx=Math.sin(angle)*t0*.48;dy=(c.y-.85)*t0*.28;dz=Math.cos(angle)*t0*.48}
    else{var t1=(amount-.45)/.55;dx=T.MathUtils.lerp(Math.sin(angle)*.48,dest.x-c.x,t1);dy=T.MathUtils.lerp((c.y-.85)*.28,dest.y-c.y,t1);dz=T.MathUtils.lerp(Math.cos(angle)*.48,-c.z,t1)}
    var selected=!!sel[p.id],shown=s.isolate?selected:(vis[p.system]||selected);
    data[i*4]=dx;data[i*4+1]=dy;data[i*4+2]=dz;data[i*4+3]=shown?1:0;selData[i*4]=selected?255:0;
    if(shown){markerPos[i*3]=c.x+dx;markerPos[i*3+1]=c.y+dy;markerPos[i*3+2]=c.z+dz}else{markerPos[i*3]=markerPos[i*3+1]=markerPos[i*3+2]=10000}
    var mesh=pickers[i];if(mesh){mesh.position.set(dx,dy,dz);mesh.updateMatrix();mesh.updateMatrixWorld(true)}
   }
   partTexture.needsUpdate=true;selTexture.needsUpdate=true;markerGeo.attributes.position.needsUpdate=true;lastVer=s.ver;dirty=true;
  }
  if(s.view!==lastView||s.reset!==lastReset){fit(s.view,amount);lastView=s.view;lastReset=s.reset}
  if(moving&&!s.isolate)fit(amount>.5?"front":s.view,Math.max(0,(amount-.3)/.7));
  var isoKey=s.isolate?s.selected.join(",")+":"+s.reset+":"+s.inspectorOpen+":"+camera.aspect:"";
  if(isoKey!==lastIsolate||(s.isolate&&moving)){
   if(s.isolate){
    var box=new T.Box3();atlas.parts.forEach(function(p,i){if(s.selected.indexOf(p.id)>=0)box.union(bounds[i].clone().translate(new T.Vector3(data[i*4],data[i*4+1],data[i*4+2])))});
    if(!box.isEmpty()){
     var center=box.getCenter(new T.Vector3()),size=box.getSize(new T.Vector3());
     var w=el.clientWidth,h=el.clientHeight,mobile=w<768,landscape=w>h&&h<=600,left=20,right=w-20,top=mobile?175:110,bottom=h-170;
     if(s.inspectorOpen){
      if(landscape){right=w-335;top=100;bottom=h-125}
      else if(mobile){var sh=document.querySelector(".detail-sheet"),hd=document.querySelector(".identity"),shr=sh&&sh.getBoundingClientRect(),hdr=hd&&hd.getBoundingClientRect();top=(hdr?hdr.bottom:94)+16;bottom=(shr?shr.top:h*.58-139)-16}
      else{right=w-370;left=w>1100?285:25}
     }
     var aw=Math.max(150,right-left),ah=Math.max(40,bottom-top);
     camera.setViewOffset(w,h,w/2-(left+right)/2,h/2-(top+bottom)/2,w,h);
     var tanF=Math.tan(T.MathUtils.degToRad(camera.fov/2));
     var distance=Math.max(.07,Math.max(size.y*h/ah,size.x*w/aw/camera.aspect,size.z)/(2*tanF)*1.35);
     controls.maxDistance=Math.max(40,distance*2);controls.stop();controls.target.copy(center);
     camera.position.copy(center).add(new T.Vector3(.2,.1,1).normalize().multiplyScalar(distance));controls.update();dirty=true;
    }
   }else if(lastIsolate){camera.clearViewOffset();fit(s.view,amount)}
   lastIsolate=isoKey;
  }
  controls.enableRotate=amount<.8;
  ground.visible=platform.visible=ring.visible=inner.visible=amount<.5&&!s.isolate;
  markers.visible=amount>.75;
  controls.autoRotate=s.rotate&&!s.isolate&&amount<.4;controls.autoRotateSpeed=.65;
  if(controls.update())dirty=true;
  if(dirty){
   renderer.render(scene,camera);targets=[];
   if(amount>.45){
    var hasSolid=atlas.parts.some(function(p,i){return p.system!=="integumentary"&&data[i*4+3]>.5});
    var W=el.clientWidth,H=el.clientHeight;
    for(var i2=0;i2<N;i2++){
     var pp=atlas.parts[i2];if(data[i2*4+3]<.5||(hasSolid&&pp.system==="integumentary"))continue;
     var l=Infinity,r=-Infinity,tp=Infinity,bt=-Infinity;
     for(var corner=0;corner<8;corner++){
      projected.set(pp.bounds[(corner&1)?1:0][0]+data[i2*4],pp.bounds[(corner&2)?1:0][1]+data[i2*4+1],pp.bounds[(corner&4)?1:0][2]+data[i2*4+2]).project(camera);
      var x=(projected.x+1)*W/2,y=(1-projected.y)*H/2;l=Math.min(l,x);r=Math.max(r,x);tp=Math.min(tp,y);bt=Math.max(bt,y);
     }
     projected.set(centers[i2].x+data[i2*4],centers[i2].y+data[i2*4+1],centers[i2].z+data[i2*4+2]).project(camera);
     if(projected.z<-1||projected.z>1)continue;
     targets.push({index:i2,x:(projected.x+1)*W/2,y:(1-projected.y)*H/2,left:l,right:r,top:tp,bottom:bt});
    }
   }
   dirty=false;
  }
 }
 animate();
 sceneApi={fit:fit};
}

/* ------------------------------------------------------------------ başlat */
wireUi();
fetch(FEMALE?"models/atlas-female.json":"models/atlas.json").then(function(r){if(!r.ok)throw new Error("Anatomi kataloğu yüklenemedi.");return r.json()}).then(function(data){
 atlas=data;sysCountsInit();buildLayers();$("loadTxt").textContent="0% · "+fmt(atlas.parts.length)+" parça yükleniyor";
 ui();initScene();
}).catch(function(e){showError(e&&e.message?e.message:"Anatomi kataloğu yüklenemedi.")});
ui();
})();
