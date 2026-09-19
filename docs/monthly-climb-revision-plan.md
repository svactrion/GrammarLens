# Monthly Climb — cihaz geri bildirimi revizyon planı

2026-09-18. Kullanıcının cihaz gözlemleri; görseller konu bazında gelecek.
Bu belge konu bazlı revizyon sırasıdır. İlk paket uygulandı; aşağıdaki kabul
durumu otomatik/görsel kontrolleri cihazda kullanıcı kabulünden ayırır.
Branch: `monthly-climb-v2`, the launch branch as of 2026-09-19: it merges to
`main` only on the owner's explicit approval and ships as the first App Store
release (see `roadmap.md`, "Launch scope"). No merge or PR has been made.
Storage, migration ve atomik Daily Test completion temeli korunacak.

## Kullanım ve çalışma biçimi

Plan başında canlı limit: beş saatlik pencerede %17, haftalık %39 kaldı.
Beş saatlik yenilenme: 18 Eylül 2026 04:24 Türkiye saati.
Yüzde, kesin token/iş kapasitesi garantisi değildir. Tek seferde bir paket:
ilgili görseller → karar → uygulama → hedefli test/görsel kontrol → kayıt.
Bir paket kapanmadan yenisine başlanmaz. Geniş revizyonlar yenilenme sonrasına
bırakılır. Hatırlatma kodlamayı otomatik başlatmaz.

## 1. Daily Test sonuç ve görünür ilerleme döngüsü (kullanıcı 1–2)

**Tamamlandı — 2026-09-18; kullanıcı kendi cihazında sorunsuz çalıştığını doğruladı.** Sonuç sonunda
`See your climb` / `Back to Home`, kayıt sürerken devre dışı bekleme ve hata
durumunda retry eklendi. Home sonuç rotasının kapanma animasyonu bitene kadar
görsel ilerlemeyi bekletir; dağı görünür alana getirip kayıtlı yeni adıma yürür.
Geç kayıt başka sekmede tamamlanırsa hareket Home'a dönene kadar bekler.
Day-0 kendi mevcut CTA'sını kullanır. İlk pakete yeni paywall yolu eklenmedi.
Testler görünür başlangıç/ara/son karelerini, CTA/geri dönüşünü, reduced motion,
replay, tümünü atlama, kayıt hatası/retry ve geç kayıt/sekme dönüşünü kapsar.
Sonuç footer'ı light/dark widget render'larında incelendi.
Statik analiz temiz; ilgili 61 test ve tam pakette 397 test geçti.

- Birincil CTA önerisi: `See your climb`, Home'a döndürür ve yeni adımı gösterir.
  Adım verilmeyen/tümü atlanan veya eski sonuçta `Back to Home`.
- Kullanıcı kararı: ilk pakette paywall yönlendirmesi yok. Olası ikincil
  Premium bağlantısı sonraki Premium çalışmasında değerlendirilebilir.
- Düzeltme öncesi kod bulgusu: `onCompletionSaved` Home'u sonuç ekranı açıkken yeniliyordu.
  Mountain ilk kurulurken doğrudan kayıtlı konuma yerleşiyor; animasyon yalnız
  mevcut widget'ın ilerleme değeri değişince başlıyor. Dolayısıyla eksik CTA
  tek başına neden değil; rota görünürlüğü ve gösterilen adımın zamanlaması
  birlikte ele alınmalı.
- Kalıcı kayıt hemen yapılır; görsel önceki adım ve bekleyen geçiş ayrı tutulur.
  Home görünürken bir defa ilerle; CTA ve sistem geri aynı davranışı paylaşsın.
- Kabul: cevaplanan test +1 görünür hareket; tümü atlanan +0; replay +0;
  başarısız kayıt hayali adım göstermez; retry/erken çıkış doğru güncellenir;
  reduced motion anlık geçiş; ay değişimi geriye tırmanma animasyonu yaratmaz.

## 2. Home kaydırma ve ilerleme alt alanı (kullanıcı 3 ve 6)

**Tamamlandı — 2026-09-18; kullanıcı cihazında çalıştığını doğruladı.** Home'daki
dağ dikey sürüklemeyi sayfaya bırakır; piyon için otomatik kamera takibi devam
eder. Uzun alt açıklama kaldırıldı; aylık sayaç başlık alanına taşındı, ekran
okuyucu ilerleme/zirve duyurusu korundu. Standalone önizlemenin rota gezintisi
korunur. Haftalık şerit veya yeni tam-dağ ekranı eklenmedi.

- Öneri: Home'da tek dikey kaydırma sahibi sayfa olsun. Dağ, mevcut konumu
  gösteren kullanıcı tarafından ayrıca kaydırılmayan bir pencere olsun.
  Tam rotayı inceleme ihtiyacı varsa ayrı `View mountain` görünümünde gezilsin.
- Uzun `Answer at least one question…` açıklaması ana görünümden kaldırılsın.
  Aylık ilerleme kompakt başlık/sayaç ve erişilebilir semantikte korunabilir.
- Pzt–Paz şeridi ayrı bir katılım göstergesidir; aylık ilerleme ile aynı şey
  değildir. Eski tasarım görseli görülmeden geri getirildiği varsayılmayacak.
- Kabul: dağın üstünden başlayan sürükleme sayfayı kaydırır; CTA ve alt içerik
  küçük ekranda ulaşılır; piyon geçişi görünür; ekran okuyucu ilerlemeyi duyar.

## 3. Tipografi kararı, ardından Premium paketi (kullanıcı 7 ve 4a–c)

**Sıra değişikliği / 4a uygulandı:** Kısıtlı kullanım penceresinde yalnızca
Annual/Monthly dış çerçeve eşitliği öne alındı; font kararı verilmedi. İki
kartın doğal içerik yüksekliğinin büyüğü ortak yükseklik olur. Seçili 2 px /
seçili olmayan 1 px çerçeve farkı padding ile dengelenir, seçim değişince
boyut oynamaz. Sabit yükseklik kullanılmadı; indirim/fiyat hesapları korunur.
Statik analiz temiz; Premium'un 67 testi geçti. Eşitlik ve seçim kararlılığı
320 px / 1× ve 375 px / 2× yazıda, gerçek light/dark temalarda doğrulandı.
4a kullanıcı tarafından cihazda onaylandı.

**4b tamamlandı — kullanıcı cihazında doğruladı:** Ana başlık bütün girişlerde
`Unlock personalized feedback` olarak sabit. Weak spot varsa mevcut alt
açıklama yerine `Practice <konu>.` gösterilir; ek metin bloğu eklenmez.
Boş/yalnız boşluk içeren konu normal açıklamaya döner. Uzun konu metinleri
kırpılmaz; küçük ekran/büyük yazıda kaydırma korunur. Light/dark testlerinde
`Modal past forms` ve `definite articles` girişlerinin gövde yüksekliği, kart
konumu, footer konumu ve kaydırma miktarı normal girişle aynı. Premium'un
70 testi geçti; statik analiz temiz. Tüm cihazlarda sıfır kaydırma iddiası yok.

**4c tamamlandı — kullanıcı cihazında doğruladı:** Yan avatarların %60 opaklığı ve
örtüşen offsetleri kaldırıldı. Kullanıcının avatarı ortada ve daha büyük;
aralarında 8 px boşluk olan tam opak avatarlar, kullanılabilir genişliğe göre
3 veya 5 adet gösterilir. 90 px hero yüksekliği, deterministik seçim, eski
profil fallback'i ve tek erişilebilirlik etiketi korunur. 320/390 px light/dark
yerleşim kontrolleri dahil 74 Premium testi geçti; statik analiz temiz.

Ek bulgu: 320 px / 2× yazıda Premium karşılaştırma tablosunun başlık ve
satırlarında yatay taşma görüldü (fiyat kartlarından ayrı bileşen). Genel
Premium yerleşim çalışmasında ele alınacak; bu dar 4a düzeltmesinde giderilmedi.

**Nunito Sans + üç metin boyutu uygulandı — cihaz incelemesi bekliyor:** Kullanıcı
fontu beğendi fakat ilk ölçüyü küçük buldu. Bu ölçü `Small` olarak korundu;
yeni varsayılan `Medium` %10, `Large` %20 daha büyük. Profile içindeki
Appearance bölümünden anında seçilir ve v16'daki ayrı tek-satır preference
tablosunda kalıcıdır. Sistem erişilebilirlik ölçeği ayrıca korunur. Google Fonts
değişken fontu ve OFL lisansı projede; çalışma zamanında ağ gerekmez. Statik
analiz temiz, tam pakette 416 test geçti. Cihazda üç boyutun Home, Daily Results
ve Premium satır kırılımları kabul edilmeden tipografi kapanmış sayılmaz.

- 4a: kodda kartlar üstten hizalı bağımsız yükseklikte; `Save` satırı yalnız
  Annual'da, border da seçilende 2 diğerinde 1 px. Ortak satır yapısı/rozet
  alanı ve eşit dış yükseklik; border için sabit alan. Sabit kısa yükseklikle
  uzun fiyat veya büyük metin kırpılmayacak. İndirim gerçek fiyattan hesaplanır.
- 4b: kodda `sourceContext` başlığa ekleniyor. Ana başlığı sabit tutup konu
  bağlamını mevcut alt açıklamanın yerine koymak önerilir; ilave blok eklenmez.
  Normal cihaz boyutunda giriş yolları aynı düzeni kullanır. Büyük yazı/küçük
  ekranda okunurluk için kaydırma kabul edilir; satın alma CTA'sı erişilir.
- 4c: merkezde seçili avatar, yanlarda daha küçük ve tam opak avatarlar;
  genişliğe göre 3 veya 5 adet, çakışmayan yerleşim. Cihazda onaylandı.
- Kabul: üç giriş yolunun karşılaştırılması, eşit plan sınırları, uzun fiyat
  ve konu metni, light/dark, büyük yazı; avatar yüzleri kapanmaz.

## 4. Profile ve madalyalar (kullanıcı 8)

1. **Tamamlandı; kullanıcı cihazında doğruladı:** Alt nav kişi ikonu/`Profile`, ekran
   başlığı `Profile`. Mevcut avatar, ad, yaş, meslek, görünüm, veri ve geliştirici
   ayarları aynı ekranda erişilebilir; yeni metin boyutu da Appearance altında.
2. **Tamamlandı; kullanıcı cihazında doğruladı:** Profile'da bronz/gümüş/altın
   madalyonlar, boş açıklaması ve açık `Not earned`/kilit durumuyla gösterilir.
   320 px, light/dark ve üç uygulama metin boyutunda taşma yok.
3. **Kararlaştırıldı ve uygulandı:** doğru +2, yanlış +1, atlanan +0. Bronze /
   Silver / Gold ayın teorik maksimumunun sırasıyla %25 / %50 / %75'i ve
   eşikler yukarı yuvarlanır. Ayrı minimum gün yok; tam ay paydası küçülmez,
   telafi ve geriye dönük test yoktur.
4. **Uygulandı; cihaz incelemesi bekliyor:** v17 sonuç tablosu ayı kural v1 ile
   bir kez dondurur; Bronze altı sonuç da saklanır ve yeniden hesaplanmaz.
   Yalnız en az bir Daily Test kaydı olan geçmiş aylar kesinleşir; boş aylar
   sahte geçmiş satırı üretmez. Mevcut ay `In progress`, puan/maksimum ve aktif
   günleri gösterir. Profile geçmişi ay, seviye/`No medal` ve puanı listeler.

## 5. Dağ geometrisi ve dekor (kullanıcı 5, düşük öncelik)

Geniş alt dönüşlerden dar üst dönüşlere, zirvede daha dikey patika. Patika,
piyon ve duraklar aynı geometriyi kullanır. Duraklar rotadan tutarlı mesafede;
seyir terası kar yüzeyinden light/dark'ta ayrışır. 28–31 gün, 7/14/21/28
durakları ve 28 günlük ayın ortak teras/zirve alanı doğrulanır.

## Bir sonraki giriş

İlk iki paket, Premium 4a–c, Nunito Sans/üç kalıcı boyut, Profile/nav ve kilitli
madalya koleksiyonu cihazda onaylandı. Sürümlü puanlama, ay sonu kesinleştirme
ve Profile geçmişi otomatik kontrollerden geçti; sıradaki kapı cihaz kabulü.
Ardından en sonda dağ geometrisi
ve dekor çalışması var. Premium 320 px / 2× karşılaştırma tablosu taşması da
genel yerleşim paketinde kapatılacak.
