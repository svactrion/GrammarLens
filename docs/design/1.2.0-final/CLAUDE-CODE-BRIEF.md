# GrammarLens — üç ekran için uygulama brief'i

## 1. Kapsam ve öncelik

Bu iş mevcut Flutter uygulamasına uygulanacak ek UI revizyonudur. Canlı uygulama Nunito Sans, fil dişi light tema, koyu dark tema, yuvarlak kartlar ve çerçeve + gölgeli alt navigasyon kullanıyor.

Öncelik sırası: bu brief'teki son ürün kararları → canlı ortak bileşenler ve tema → paketteki önizlemeler. Önceki büyük Credits illüstrasyonu ve önceki yüksek Premium kart referansı geçersizdir. Data tasarımı korunmuştur. Önizleme gerçek veri/servis entegrasyonu değildir.

## 2. Premium Review — Suggested Focus

### Görünürlük

- Yalnızca mevcut abonelik/entitlement katmanının **Premium** kabul ettiği kullanıcıda göster.
- Free kullanıcıda mevcut turuncu günlük hak kartı ve hak kullanıldıktan sonraki görünüm aynen devam eder. Suggested Focus Free ekranına eklenmez.
- Premium kullanıcının kartı günlük Free hak kullanımıyla gizlenmez, grileşmez ve yarını bekleme mesajı göstermez.
- Entitlement yüklenirken Premium'u varsayma; mevcut yükleme politikasını kullan. Yanlış Free/Premium kartının bir anlığına görünmesini önle.

### Seçim mantığı — zorunlu

Kaynak, Review'daki **Saved weak spots** listesinin aynı veri kümesidir. Her kayıtta gösterilen `count`, o kaydın seçim değeridir. Alanın projedeki gerçek adı farklı olabilir; aynı veriyi eşleştir.

1. Kullanılabilir kayıtlar arasında `count` en büyük olanı seç.
2. Count eşitse `lastSeen` en yeni kaydı seç (eşitlik için önerilen kararlı kural).
3. İkisi de eşitse mevcut kararlı kayıt ID'sine göre seç. Yeniden çizimde rastgele değişmesin.
4. Recent / Repeated / başka bir liste sıralama tercihi kartın seçimini değiştirmesin. Görünür ilk kayıt seçilmez; tüm uygun kayıtlar değerlendirilir.
5. Count'ları konu bazında yeniden toplama, ağırlıklı puan oluşturma, doğruluk yüzdesi veya AI önerisi üretme. Bu iş için yeni API çağrısı gerekmez.
6. Yeni hata, count değişimi veya kayıt silinmesi olduğunda aynı kuralla yeniden hesapla.
7. Pratik tamamlamak tek başına kaydın count'unu düşürmez ve kaydı “öğrenildi” yapmaz. Mevcut veri modelinde böyle bir davranış varsa onu koru; bu tasarımdan yeni bir davranış çıkarma.

Örnek: Gerund vs. Infinitive = 1, Modal Verbs = 2, Articles = 1 → **Modal Verbs**. Articles = 3 olduğunda kart **Articles** olur.

Eksik/geçersiz count durumunda sahte bir sayı gösterme. Mevcut veri normalizasyonunu kullan; uygulanabilir geçerli kayıt yoksa öneri kartı yerine boş durum göster. LastSeen eksikse eşitlik çözümünde bilinen tarihler önce, sonra kararlı ID kullanılabilir. Aynı konudan birden fazla kayıt varsa mevcut kayıt kimliklerini koru; bu iş kapsamında birleştirme yapma.

### Görünüm ve içerik

- Ekran başlığı `Review`, alt metin `Turn your mistakes into progress.` korunur.
- Lacivert üst kart, turuncu CTA; premium rozeti veya upsell eklenmez.
- Küçük üst etiket: `SUGGESTED FOCUS`.
- Başlık: seçilen kaydın gerçek konu/weak spot başlığı.
- Açıklama: `Saved 2 times · Most repeated`. Tekil count için `Saved 1 time`. Yerelleştirme ve çoğul kuralları kullanılır.
- CTA: `Practise this weak spot`. Konu başlığını butonda tekrar ederek kartı büyütme.
- CTA mevcut weak spot detay/pratik giriş akışını seçilen gerçek kayıt ID'siyle açar. Var olan soru sayısı seçimi, AI izin kontrolü, cevap üretimi ve geri dönüş davranışı korunur.
- Alt hata listesi, sayaç etiketleri, kart detayları ve mevcut navigasyon korunur. Büyük listelerde lazy/scroll davranışı mevcut yapıdan alınır.

### Free kartıyla ölçü eşitliği — zorunlu

Premium kartı ayrı bir boyut sistemiyle tasarlama. **Aynı cihaz genişliği, dil ve metin ölçeğinde Free ve Premium üst kartlarının dış genişliği ve yüksekliği aynı olmalı.** İç padding, köşe yarıçapı, başlığa/listeye olan dış mesafeleri de aynı ortak tokenlardan alınmalı.

Uygulama yaklaşımı:

- Canlıdaki Free kart widget'ını/kabını incele; mevcut constraints, padding, radius ve text ölçeği davranışını temel al.
- Ortak bir `ReviewTopCard` kabında Free available / Free used / Premium suggested varyantları kullan. Free hak hesabını bu görsel kabın dışında tut.
- Canlı Free ölçüsünü değiştirmeden Premium içeriğini o alana sığdır. Önizlemede yaklaşık 190 mantıksal px taban yükseklik kullanıldı; **bu rakam canlı Free yüksekliğinin ölçüldüğü anlamına gelmez ve üretim için sabit zorunluluk değildir**.
- Başlık iki satıra kadar akabilir; CTA minimum 44–48 mantıksal px dokunma alanını korur. Açıklama kısa tutulur. Kritik bilgiyi keserek, fontu küçülterek veya taşırarak eşitlik sağlama.
- Büyük erişilebilirlik yazısında veya uzun yerelleştirmede sabit yükseklik zorlanmaz. İki varyant aynı genişleme kuralını/ortak hesaplanan yüksekliği paylaşır; yalnız Premium büyümez. Uzun başlığın tamamı okunabilmelidir.
- Free available, Free used ve Premium için aynı viewport'ta kart bounds karşılaştırması yap; varsayılan ölçekte kullanıcı Free'den Premium'a geçince liste başlangıcı aşağı kaymamalıdır.

### Durumlar

- Veri yükleniyor: mevcut kart alanını koruyan sakin yükleme görünümü; sahte konu/count yok.
- Kayıt yok: öneri üretme. `Your next step starts with practice.` / `As you practise, your mistakes will appear here so you can work on them again.` / `Explore Topic Practice`. Buton mevcut Premium konu seçimine gider. Free boş durumuna bu kurguyu uygulama.
- Veri okuma hatası: boş liste gibi davranma; mevcut hata/yeniden dene akışını kullan.
- Pratik açılırken: çift tıklamayı önle; hata durumunda konu seçimi ve liste kaybolmasın.
- Ekrana geri dönüşte scroll/sıralama tercihi korunsun.

## 3. Data — onaylanan görünüm

Üstte Profile'a geri dönüş, `Data` başlığı ve `Your practice. Your choices.` alt metni. İki ayrı, açık temada sıcak açık yüzeyli kart: AI feedback ve Reset progress.

### AI feedback

Metin: `Topic Practice sends your typed answers and questions to Anthropic (Claude) to create feedback.` Soru, yazılan cevap, alıcı ve amaç görünür kalır.

- Anahtar etiketi `Allow AI feedback`.
- Açık açıklama: `On · Required for Topic Practice`.
- Kapalı açıklama: `Off · Topic Practice needs permission`.
- Bilgi satırı: `Daily Test works without this permission.`
- Anahtar ilk değerini mevcut kayıtlı izinden alır; mockup açık başladığı için uygulamada yeni izin verilmiş sayılmaz.
- Mevcut consent kaydı ve geri alma davranışını koru. İzin kapalıysa ilgili AI pratik akışındaki mevcut kontrol çalışmalı; Daily Test çalışmaya devam eder.
- Kalıcı kayıt başarısızsa görünümü gerçek değere geri getirip anlaşılır hata göster. Değişiklik sırasında tekrar tıklamayı engelle. Yeni veri gönderme veya farklı sağlayıcı ekleme.

### Reset progress

Metin: `Clear your practice history and saved weak spots.` İkincil satır: `Your name, goal and theme stay as they are.`

Ana ekrandaki eylem düşük yoğunluklu kırmızı yüzey + çerçeve, `Reset progress data`. Dokununca onay diyaloğu:

- Başlık `Reset your progress?`
- `This clears your practice history and saved weak spots.`
- `Your name, goal and theme will stay as they are.`
- Güvenli eylem `Keep my progress`; silme eylemi `Reset progress data`.

İptal, geri ve dışarı dokunma hiçbir veri silmez. Gerçek reset yalnızca açık onaydan sonra mevcut servise gider. Çift işlem önlenir; başarı bildirimi ve Review yenilenmesi sağlanır. Hata halinde başarı mesajı gösterilmez. Bu tasarım reset kapsamını genişletmez: abonelik, izinler, kimlik, madalya veya Daily Test mantığı için yeni silme davranışı ekleme. Mevcut servis kapsamı görünür metinle çelişiyorsa uygulamadan önce çelişkiyi raporla.

## 4. Credits — son sade sürüm

Profile'a geri dönüş, `Credits` ve küçük `Artwork and attribution.` alt metni. Tek sade kart; içerik kadar yüksek. Ekranı doldurmak için büyütme.

- Başlık: `Avatar illustrations`.
- Metin: `Adapted from Cute Animal 3D Icons by Tran Mau Tri Tam, via Figma Community. Licensed under CC BY 4.0.`
- Bağlantı `Figma file`: https://www.figma.com/community/file/1514963172455082116/cute-animal-3d-icons
- Bağlantı `CC BY 4.0 license`: https://creativecommons.org/licenses/by/4.0/

Hero görseli, illüstrasyon şeridi, süslü lisans rozeti, teşekkür bölümü ve pazarlama içeriği **eklenmez**. Uzun URL'ler paragraf içinde basılmaz; açıklamalı bağlantılarda tutulur. Kaynak, yazar, lisans ve uyarlama bilgileri kaldırılmaz. Bu bilgiler mevcut ekrandan aktarılmıştır; yeni bir lisans denetimi yapılmış sayılmaz. Canlı projede ek zorunlu atıflar varsa korunur.

Bağlantılar mevcut güvenli dış URL açma akışını kullanır. Açma başarısızsa kısa hata göster; uygulama ekranı korunur.

## 5. Görsel sistem ve Flutter uyarlaması

Canlı ortak tema/token karşılıkları varsa yeniden tanımlamak yerine onları kullan. HTML piksel değerleri Flutter'da mantıksal ölçü referansıdır; görüntü piksel ölçüsü değildir.

| Öğe | Referans |
| --- | --- |
| Yazı ailesi | Nunito Sans, mevcut yerel font asset'leri |
| Sayfa başlığı | 33–34 / 900, line height 1.15 |
| Bölüm başlığı | 18–19 / 800, line height 1.25 |
| Gövde | 13–14 / 400–600, line height 1.5–1.65 |
| İkincil etiket | 11–12 / 600–800 |
| Sayfa yatay boşluğu | Review 18, Data/Credits 20 |
| Kart iç boşluğu | Review ortak Free kart tokenı; Data/Credits 19 |
| Kart yarıçapı | 24; hata liste kartı 22 |
| Data kartları arası | 16 |
| Buton yarıçapı / yükseklik | 13–14 / en az 46–48 |
| Alt navigasyon | Mevcut çerçeve + gölge; yalnız Review'da |

Renkler `design-tokens.json` ve kaynakların light/dark değişkenlerinde bulunur. Review focus laciverti light #183854, dark #203D57; CTA #FF8A3D / yazı #241200. Data ve Credits aynı temel yüzey sistemini kullanır.

- Native Flutter bileşenleri kullan; HTML'yi WebView'a gömme.
- SafeArea, gerçek status bar, sistem geri hareketi ve mevcut navigation yapısını koru. Mockup telefon çerçevesi/saati/ev göstergesi üretim UI'sı değildir.
- 320, 360, 390 ve 430 mantıksal px genişlikte, en az 1.0/1.3/2.0 metin ölçeğinde taşma kontrolü yap. Kartlar içerikle büyüyebilir; ekran dikey kayabilir.
- Başlık, toggle durumu, buton ve bağlantılara anlamlı Semantics ver; renk tek durum göstergesi olmasın. Dokunma hedefleri en az 44×44 olmalı.
- Diyalog açıldığında erişilebilirlik odağı içeride, kapandığında açan butona döner. Klavye/ekran okuyucu kullanıcıları iptal edebilir.
- Yeni sürekli animasyon yok. Mevcut tema ve basılma efektlerini koru; gerekiyorsa 150–200 ms kısa geçiş ve azaltılmış hareket tercihi uygulanır.

## 6. Uygulama teslimi

Mevcut çalışma ağacındaki kullanıcı değişikliklerini koru. Yeni backend, öneri AI servisi, veri migrasyonu veya ücret sınırı ekleme. Seçim fonksiyonunu saf ve test edilebilir tut. Repo test/lint kurallarını uygula, `ACCEPTANCE-CHECKLIST.md` içindeki gerçek uygulama doğrulamalarını yap. Yapılmayan testleri yapılmış gibi raporlama.
