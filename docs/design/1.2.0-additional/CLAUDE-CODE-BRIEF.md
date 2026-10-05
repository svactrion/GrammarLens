# GrammarLens — Paywall, Onboarding ve Soru V2 uygulama briefi

Tarih: 5 Ekim 2026. Hedef: mevcut Flutter uygulaması. Bu paket tasarım ve etkileşim referansıdır; üretim kodu içermez.

## 1. Kapsam ve öncelik

Paywall ve iki adımlı onboarding kullanıcı tarafından beğenildi. Kullanıcı yeni, klavye odaklı soru tasarımının da uygulanmak üzere bu pakete alınmasını istedi.

**Soru için tek güncel referans `source/grammarlens-question-keyboard.html` dosyasıdır.** Önceki beş ekran paketindeki `grammarlens-question.html`, eski soru briefi ve birleşik önizlemenin Soru sekmesi bu ekran açısından geçersizdir. Home, Review, Profile ve Topic kararları devam eder. Bu paketi uygularken onların devam eden değişikliklerini geri alma.

Önce README, bu brief, design-tokens.json ve üç önizlemeyi incele. Mevcut Flutter projesindeki tema, fontlar, ilgili ekranlar, soru oturum modeli, abonelik servisi, onboarding kayıtları ve veri izin akışını oku. Mevcut değişiklikleri koruyarak yerel bileşenleri geliştir. HTML/WebView olarak uygulamaya gömme.

Çakışmada sıra: kullanıcının son isteği → bu briefin davranış ve erişilebilirlik kuralları → bu paketin önizlemeleri → eski paketin ortak tasarım dili. Kaynakta temsili ürün verileri ve maket kontrolleri bulunduğu için HTML'yi bire bir iş mantığı kaynağı sayma.

## 2. Ortak tasarım dili

- Light: fil dişi zemin; dark: koyu nötr zemin. Nunito Sans korunur, projedeki gerçek font asseti kullanılır. Font eşlemesi doğrulanır; farklı fontla taklit edilmez.
- `design-tokens.json` önceki ortak değerleri ve bu üç ekrana özgü `screenOverrides` / `screenMetrics` değerlerini birlikte içerir. Ekran istisnaları yalnızca bu kapsamda uygulanır; diğer ekranların temasını topluca değiştirme.
- Turuncu ana eylem, lacivert/light-blue bağlantı ve seçim vurgusu. Kartlar hafif çerçeve ve gölgeyle ayrılır. Dark yüzeylerde gölgeden çok yüzey tonu ve sınır çizgisi farkı görünür.
- Tüm ölçüler Flutter logical pixel referansıdır. Önizlemedeki telefon dış çerçevesi, durum çubuğu, home indicator ve tema/cihaz/soru seçicileri uygulama bileşeni değildir.
- Yazı ağırlıkları: başlık 800–900, kart başlığı 800, gövde 400–600, soru cümlesi 700. Gerçek dosyanın bu ağırlıkları desteklediğini doğrula. Sistem text scaling kapatılmaz.
- Başlıklar ve sorular ellipsis ile kesilmez. Büyük yazıda alanlar büyür veya kontrollü kayar; metin sığdırmak için otomatik küçültülmez.
- İkon hedefleri en az 44×44; ana eylemler en az 48 yükseklik. Görselde 30–36 yüksekliğinde görünen küçük metin bağlantılarının dokunma alanını en az 44'e genişlet. Soru maketindeki 45 yüksekliğindeki Next için üretimde 48 kullan; yerleşimi yeniden ölç.
- Minimum gövde/cevap boyutları ve kontrast korunur. VoiceOver/TalkBack etiketleri, seçili/kapalı/loading durumları ve modal odak sırası tanımlanır.
- Gölgeler başlangıç referansı: light yaklaşık offset(0,6), blur18, düşük opaklıklı sıcak koyu; dark aynı geometri daha koyu ama hafif. Mevcut ortak Shadow tokenı varsa onu kullan.
- Hareket: kahraman seçimi 220ms ease-out; ekran geçişi 180–220ms; reduce motion tercihine uy. Klavye animasyonunu platform zamanlamasıyla takip et, ayrıca sıçratan sabit gecikme ekleme.

## 3. Paywall

Referans: `previews/paywall.html` / `source/grammarlens-paywall.html`.

### Yerleşim ve içerik

1. Küçük GrammarLens marka adı ve 44×44 kapatma düğmesi.
2. Kahraman grubu: **kullanıcının seçili kahramanı daima ortada büyük**. Maketteki Sloth ve üçlü sayım örnektir. Mevcut kahraman sıralama kodunu, toplam hero sayısını ve assetleri koru. Ortadaki görsel 124, yanlar yaklaşık66 genişlik; görsel en-boy oranı korunur.
3. Premium etiketi, `Turn your mistakes into progress.` başlığı (28/900), kısa destek metni.
4. Üç fayda, tek kart içinde: hataları AI geri bildirimiyle anlama; günlük bir ücretsiz pratiğin ötesinde weak spot practice; tüm konular ve 3/5/10 soruluk oturumlar. Ücretsiz Review hakkının varlığını gizleme; AI'nin yalnızca premiumda mevcut olduğunu iddia etme.
5. `Compare Free & Premium` açılır tablo. Mevcut gerçek hakları esas al: Daily Test herkese; Free Review'da seçtiği bir weak spot için günlük bir pratik; Topic Practice premium. Bilinmeyen premium limitlerini “unlimited” diye uydurma.
6. Yıllık ve aylık planlar alt alta, radio seçimi. Yıllık toplam fiyat belirgin; seçili kart border2 ve info yüzeyi. Save etiketi brand-soft.
7. `Have a code?` bağlantısı → kod modalı.
8. Alt eylem alanı: ana CTA, yenileme koşulları, Restore purchases, Terms, Privacy ve Maybe later.

Sayfa kenarı20; fayda kartı radius23; plan radius19, minimum yükseklik87; plan arası10; CTA radius17 ve minimum52. Uzun içerik kayabilir. Alt satın alma alanını SafeArea içinde görünür tut; küçük ekran/büyük metinde içerik veya şartlar gizlenmesin. Kod modalı açıldığında klavye ve modal içeriği kaydırılabilsin; arkadaki sayfa etkileşimi engellensin.

### Plan ve satın alma durumları

Maket $49.99/yıl, $5.99/ay, %30 tasarruf ve yıllık 7 gün deneme gösterir. **Bunlar ekran görüntüsündeki örneklerdir.** Para birimi, fiyat, indirim, dönem ve trial uygunluğu mevcut mağaza ürünlerinden gelir. Denemeye uygun olmayan kullanıcıya ücretsiz deneme sözü verme. Aylık plan için makette deneme gösterilmemiş olması backend kuralı değildir; gerçek ürün şartlarına uy.

Plan değişince CTA ve bütün ücret/yenileme açıklamaları aynı seçili ürünü göstermeli. Loading sırasında çift ödeme isteğini engelle. İptal, ödeme hatası, ürün yüklenemedi, restore sonucu ve zaten premium durumlarını mevcut satın alma altyapısına bağla. İşlem doğrulanmadan premium açma. Terms/Privacy için mevcut gerçek URL'leri kullan. Kapatma/Maybe later mevcut dönüş yolunu izler.

### Kod modalı

Başlık `Redeem your code`; alan etiketi `Your code`; eylem `Check code`. Boşken disabled. Kodu yazmak otomatik satın alma/aktivasyon başlatmaz.

- Kontrol ediliyor: loading, tekrar gönderme engeli; alan değeri korunur.
- Geçersiz / süresi dolmuş / kullanılmış / uygun değil: alan yanında anlaşılır hata; kod düzeltilebilir.
- Bağlantı hatası: kod silinmeden tekrar deneme.
- İndirim geçerli: hangi planı kapsadığı, uygulanmış fiyat, teklif süresi ve sonraki yenileme koşulları gösterilir; kullanıcı onayından sonra mevcut satın alma akışı devam eder.
- Ücretsiz erişim geçerli: erişim süresi ve varsa ilgili şartlar gösterilir; doğrulanan hak üzerinden etkinleştirilir. Ücretsiz erişimi kendiliğinden ücretli yenilenen plana dönüştürme.
- İptal/kapatma: mevcut plan seçimi korunur.

**Bağımlılık:** İndirim/ücretsiz Premium kodlarının gerçek kaynağı ve doğrulama servisi bu tasarım çalışmasında belirlenmedi. Mevcut projede bir servis varsa onu kullan. Yoksa modal ve servis arayüzünü hazırlayıp entegrasyon eksiğini bildir; istemci içine geçerli kod listesi veya sahte başarılı aktivasyon koyma. Üretimde bağlantısız kod akışını çalışıyor gibi sunma. Kullanılan mağaza/abonelik sağlayıcısının desteklediği redemption akışı uygulama sırasında doğrulanmalı. Bu brief o mekanizmanın yerine geçmez.

## 4. İki adımlı onboarding

Referans: `previews/onboarding.html` / `source/grammarlens-onboarding.html`.

### Adım 1 — Companion + isim

Kaydırılabilir kahraman seçimi korunur. Seçili kahraman merkezde büyük, yan komşular kısmen görünür. Projedeki bütün kahramanlar mevcut ID'leriyle kullanılır; maketteki üç öğe sabit liste olarak kopyalanmaz. Orta görsel150×165, komşu ölçek0.72 / opaklık0.48 referansı; seçim snap ile ortalanır, renk dışında boyut/seçim açıklaması da değişir. Mevcut döngü davranışını koru.

`What should we call you?` kartı radius22, padding19; input52 yüksekliği/radius13. İsim isteğe bağlı. Boş isimle Continue çalışır; uygulamada boş ismi “null” veya sahte kişi adı olarak gösterme, isimsiz selamlama kullan. İsim doluysa önce/sonra boşluklar temizlenir, Unicode isimler korunur. Maketteki maxlength40 temsili üst sınırdır; projenin mevcut doğrulamasıyla uyumlandır.

Klavye açıldığında isim alanı ve Continue görünür; kahraman bölümü gerektiğinde kayabilir. Geri gidip gelme, klavye değişimi ve tema değişiminde seçili kahraman/isim kaybolmaz.

### Adım 2 — Amaç: ürün araştırması

Kullanıcının netleştirdiği gerçek durum: **öğrenme amacı şu anda dersleri veya başlangıç önerisini kişiselleştirmiyor. Kullanıcı kitlesini anlamak ve sonraki geliştirmeleri yönlendirmek için soruluyor.**

Eski `This helps us suggest where to start.` metni kullanılmaz. Bu paketin kaynak ve önizlemesinde düzeltilmiştir:

- Üst küçük etiket: `Help shape GrammarLens`
- Açıklama: `Choose what matters most to you. Your answer helps us decide what to improve next.`
- Seçenekler: Exam prep, Work, Everyday confidence (mevcut general-fluency değerine map et).
- Hiçbiri varsayılan işaretli değil. Seçim yapılınca Start my first test etkin; `Skip goal & start` seçimsiz devam ettirir. Atlamayı General fluency sayma; null/skipped olarak ayır.
- Geri düğmesi ilk adıma döner, seçimleri korur. Tamamlama ilk ücretsiz Daily Test'e yönelir. O gün test tamamlanmış/oturum mevcutsa mevcut akışa uygun Home/sonuç dönüşünü kullan; yeni hak yaratma.

Amaç kartları radius21, aralık12, minimum yükseklik91, ikon40. Kenarlar22. Ana CTA54/radius17. Seçili kahraman ikinci adımda küçük48 görselle eşlik eder.

### Veri açıklaması ve kayıt

Paket açıklaması kişiselleştirme vaadini kaldırır. Önceki ekranın “isim ve amaç yalnızca cihazda kalır” ifadesi ile kitlenin amacını uzaktan ölçme hedefi aynı anda doğrulanmadan söylenemez. Pakette isim için yerel saklama ifadesi korunmuş, amaç için mutlak yerel-saklama iddiası çıkarılmıştır.

**Uygularken veri akışını doğrula:** amacı mevcut analytics altyapısı gerçekten alıyor mu? Alıyorsa kullanıcıya gerçek aktarımı mevcut privacy metniyle tutarlı anlat; almıyorsa araştırma verisi toplanıyor diye raporlama. Bu paket yeni analytics sağlayıcısı kurma veya isim/serbest cevapları telemetriye gönderme talimatı değildir. Mevcut izin tercihleri korunur; eksik araştırma-verisi bağlantısı ayrı raporlanır.

`Your data & AI` penceresi mevcut açıklamaları erişilebilir biçimde sunar. Topic Practice yanıtlarının Anthropic/Claude'a gönderilmesi ve önceden izin alınması, kullanım/crash verisi açıklamaları gerçek uygulamayla doğrulanarak korunur. Bu bilgilendirme penceresindeki “Got it” düğmesi AI veri aktarımı için mevcut ayrı onay adımının yerine geçmez.

Onboarding completion yalnızca tamamlanınca yazılır; uygulama yeniden açıldığında tamamlanmış kullanıcıya her seferinde onboarding gösterilmez. Aradaki taslak seçimler mevcut kalıcılık modeline uygun korunur.

## 5. Soru V2 — Klavye ve uzun cevaplar

Referans: `previews/question-v2.html` / `source/grammarlens-question-keyboard.html`.

### Esas problem ve kabul edilen çözüm

Canlı uygulamadaki tek satırlı cevap yatay kayıyor; kullanıcı uzun rewrite cevabının başını göremiyor/düzeltemiyor. Eski mockup klavye açık yerleşimi göstermiyordu. Yeni düzen kompakt başlık + soru/yönerge kartı + yakınında büyüyen çok satırlı cevap + klavyenin üzerinde eylemlerden oluşur.

- Sol üst geri **önceki soruya** gider, ekranı kapatmaz. İlk soruda disabled/yerleşimi korunan durum. Sağ üst × oturumdan çıkıştır; mevcut çıkış kuralı ve onayı korunur.
- Başlık17/900; sayfa kenarı16, kart içi15×14, radius21; soru17/700, line-height1.45. Yönerge13, line-height1.5. Makette örnekler var; API sorularını kısaltma, özetleme, yeniden yazma veya yeni soru üretme.
- Cevap16, line-height25px karşılığı; padding13×12, radius17. İki satırdan başlar, kelimeler alt satıra sarılır; hiçbir cevap türünde yatay tek satır akışına zorlanmaz. Metin girişini/uzunluğunu görünür satır sayısıyla sınırlandırma.
- Cevap büyürken önce sorunun tamamına yer ayrılır. Cevap alanı yalnızca kalan alana kadar büyür; limit sonrası kendi içinde dikey kayar. Kullanıcı başa dokunup imleci taşıyabilir, seçim/copy/paste yapabilir. Return yeni satır ekler; cevap göndermemeli.
- Normal rewrite örneğinde soru ve yönerge, klavye açıkken bütünüyle görünür. Uzun soru + küçük ekran + büyük metinde her şey aynı anda sığmayabilir. Metni küçültme/kesme; soru alanını ayrı dikey kaydırılabilir yap. “Read full question” klavyeyi kapatır. İçeriğin devamı olduğuna görünür bir kaydırma işareti ekle.
- “Review answer” / klavyeyi kapatma kontrolü cevap kaybetmeden klavyeyi kapatır ve okuma alanını artırır. Sınırsız metnin her durumda tek karede görünmesi taahhüt edilmez; dikey kaydırma erişilebilir olmalı.
- Skip ve Next/Submit klavye üstünde görünür kalır. Boş/yalnız boşluk cevabında Next disabled; Skip mevcut kuralı uygular. Son soruda Submit.
- Önceki/sonraki sorular arasında ID bazlı cevap taslaklarını sakla; index değişince controller yeniden oluşturup metni kaybetme. Aynı soru tekrar açılınca cevap, seçili aralık ve uygun scroll konumu geri gelir.
- Geri dönmek veya klavyeyi kapatmak AI isteği, puan artışı veya hak tüketimi oluşturmaz. Değerlendirme zamanı, skip kuralı, oturum uzunluğu, sonuç, günlük ücretsiz hak ve mevcut API davranışı korunur. Gönderim/loading durumunda çift isteği engelle; hatada cevapları koru.

### Flutter uygulama yaklaşımı

Bunlar referans yaklaşımlardır; projenin mimarisine uygun uygulanır:

- `Scaffold(resizeToAvoidBottomInset: true)` ve gerçek `MediaQuery.viewInsets.bottom` / `SafeArea` ile klavye alanını dikkate al. Resize edilen gövdeye aynı inset'i ikinci kez ekleyip çift boşluk oluşturma.
- `TextField` veya `TextFormField`: `keyboardType: TextInputType.multiline`, `textInputAction: TextInputAction.newline`, `minLines: 2`; büyüme için mevcut constraint'e uygun `maxLines` veya `maxLines: null` + sınırlı yükseklik. **`maxLines: 1` kullanma.** `expands` ile `minLines/maxLines` çelişen ayarlar kurma.
- `LayoutBuilder` ve gerekirse `TextPainter` ile gerçek genişlik, text scaler, soru/yönerge yüksekliği, padding, alt eylemler ölçülür. Kalan alandan cevap üst sınırı belirlenir. Çok küçük kullanılabilir yükseklikte minimumları zorlayıp overflow üretme; kaydırılabilir geri dönüş düzeni kullan.
- Soru ve cevap ayrı kaydırma alanlarıdır; caret görünürlüğü sadece cevap alanını gerektiğinde kaydırmalı. Her tuşta tüm sayfayı en alta atma. `TextEditingController` ve `FocusNode` build içinde yeniden oluşturulmaz.
- Enter, IME composing, otomatik düzeltme ve selection normal platform davranışını korur. HTML maketindeki `inputmode="none"` ve elle çizilen klavye **üretime taşınmaz**; gerçek iOS/Android klavyesi kullanılır.
- Önizlemenin 300px klavyesi ve 390×844 / 360×740 cihaz çerçeveleri yalnızca deneme ölçüleridir. Gerçek klavye, öneri çubuğu, SafeArea veya gövde boyu sabitlenmez.
- Büyük yazı, yatay yön, farklı klavyeler ve ekran döndürmede cevap/kaydırma/fokus korunur. Gerekirse üst başlık satır sayısı artar; soru metni otomatik küçültülmez.

Referanslar: [TextField maxLines](https://api.flutter.dev/flutter/material/TextField/maxLines.html), [minLines](https://api.flutter.dev/flutter/material/TextField/minLines.html), [resizeToAvoidBottomInset](https://api.flutter.dev/flutter/material/Scaffold/resizeToAvoidBottomInset.html).

## 6. Uygulama sırası ve teslim

1. Mevcut kodu ve devam eden değişiklikleri incele; ortak tokenları mevcut sisteme ekle.
2. Öncelikle Soru V2'de gerçek klavye, metin büyümesi ve cevapların korunmasını uygula/doğrula.
3. Onboarding'i iki adıma ayır; amaç açıklamasını düzelt; mevcut kaydı ve izin akışını koru.
4. Paywall görselini mevcut satın alma akışına bağla; kod servisi durumunu ayrı bildir.
5. `ACCEPTANCE-CHECKLIST.md` maddelerini çalıştır. Gerçek cihaz/emülatör testlerini yapılmadıysa yapılmış sayma. Mevcut anlamlı testleri çalıştır; özellikle soru taslağı geri/ileri ve API çift gönderim davranışını doğrula.
6. Teslimde değişen dosyaları, gerçekleştirilen doğrulamaları ve kalan servis/mağaza/analytics bağımlılıklarını açıkça bildir. HTML önizleme başarısı Flutter cihaz testi değildir.
