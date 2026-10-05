# GrammarLens — Flutter UI uygulama briefi

Tarih: 5 Ekim 2026. Bu paket UI referansı ve uygulama talimatıdır; çalışan Flutter kodu değildir.

## Başlangıç talimatı

Mevcut GrammarLens Flutter projesindeki Home, Review, Profile, soru ve Topic Practice ekranlarını bu paketteki tasarımlara göre güncelle. Önce mevcut ekranları, theme.dart dosyasını, font tanımlarını ve ortak bileşenleri incele. Var olan state management, routing, premium kontrolü, test üretimi, AI API entegrasyonu, veri kayıtları ve oyunlaştırma hesaplarını koru. Önce ortak tema/bileşenleri oluştur; sonra ekranları sırayla uygula. Üretim verisini önizlemedeki sabit örneklerle değiştirme.

Görsel referans: `index.html`. Kaynak: `source/grammarlens-five-screens.html`. Bu dosyaları tarayıcıda aç; yalnızca screenshot üzerinden ölçü tahmini yapma. Renk ve ölçüler için bu brief ve `design-tokens.json` kullan. HTML/CSS bir görsel referanstır; Flutter uygulamasını WebView içine taşımak için kullanılmaz.

## Kararların durumu

| Ekran | Referans | Durum |
|---|---|---|
| Home | Ayrı turuncu daily test kartı + klasik, patikaya bitişik yuvarlak başlık | Kullanıcı tarafından onaylandı |
| Review | Günlük ücretsiz pratik hakkı + kaydedilmiş weak spot kartları | Kullanıcı tarafından onaylandı |
| Profile | Ortalanmış büyük hero + arka plansız yatay madalya koleksiyonu + ayrı ilerleme kartı | Kullanıcı tarafından onaylandı |
| Soru | Tek soru kartı, iki adımlı yönerge, yakındaki çok satırlı cevap | Kullanıcının beşli çalışmaya dahil ettiği son referans; ayrı bir revizyon talebi yok |
| Topic Practice | Kompakt beş konu kartı; premium kullanıcı görünümü | Yeni taslak, açık onay bekliyor |

Reddedilmiş birleşik Home kartlarını veya eski renk alternatiflerini uygulama. Topic taslağını üretime taşımadan önce kullanıcı bu görünümü değerlendirsin; diğer ekranların çalışmasına bu yüzden ara vermek gerekmez.

## Paketi açma

`index.html` beş ekranı bir arada gösterir. Üstteki sekmeler tasarım inceleme aracıdır; gerçek uygulamaya eklenmez. Tema seçimi tüm ekranları etkiler. Yeni Topic ekranı ilk açılan sekmedir. Diğer sekmelerden Home, Review, Profile ve soru ekranı incelenir. Home bu çalışmada üst/alt bölümleri tek devamlı akışta gösterir.

Bu önizleme gerçek hesap/veri/API kullanmaz. Premium paywall, Data/Credits içeriği, test sonuçları ve diğer ara ekranların yer tutucuları üretim tasarımı olarak alınmamalı. Canlıya yayınlanmış bir site değildir. Google Fonts ve ikonların yüklenmesi için internet gerekebilir.

## Ortak renkler

| Token | Light | Dark |
|---|---|---|
| pageBackground | #F3EFE6 | #151517 |
| cardSurface | #FFFBF4 | #252528 |
| subtleSurface | #F6F0E5 | #303034 |
| textPrimary | #1B1B1F | #F0ECE7 |
| textSecondary | #46464F | #C9C5D0 |
| brandOrange | #FF7A1A | #FF8A3D |
| onOrange | #241200 | #241200 |
| primaryButton | #0D3B8F | #0D3B8F |
| onPrimaryButton | #FFFFFF | #FFFFFF |
| linkAndActive | #0D3B8F | #B4C8FF |
| infoSurface | #D7E1FA | #243859 |
| onInfo | #0A2E70 | #D8E1FF |
| border | #DED5C6 | #45454D |
| navigationSurface | #FFFCF7 | #2D2D32 |
| navigationBorder | #D2C6B4 | #595961 |

Turuncu artık büyük, tüm ekranı kaplayan app bar değildir. Home daily test kartı, Review günlük pratik kartı, Profile puan vurgusu, soru sayacı ve Topic erişim etiketi gibi anlamlı alanlarda kullanılır. Dark modda turuncu yüzeyin yazısını beyaza çevirmeyin; koyu yazı kullanın. Haritaların Green/Glacier/Red Canyon/Ember varyantları için başlık rengini sabit kum rengine bağlamayın.

## Tipografi ve ölçüler

Font: mevcut Nunito Sans. Sahte bold kullanmayın; 400, 600, 700, 800, 900 ağırlıkları doğru çözümlensin. Variable font varsa ağırlık ekseninin gerçek ağırlıkları verdiğini doğrulayın. Flutter'da gerçek font dosyasıyla göz kontrolü yapın; tarayıcı ve Flutter rasterizasyonu bire bir aynı olmayabilir.

| Kullanım | Boyut | Ağırlık | Satır yüksekliği | Harf aralığı |
|---|---:|---:|---:|---:|
| Home marka | 34 | 900 | 1.10 | -1.4 |
| Review/Profile sayfa başlığı | 34 | 900 | 1.10 | -1.1 |
| Topic sayfa başlığı | 32 | 900 | 1.10 | -1.0 |
| Soru konu başlığı | 26 | 900 | 1.12 | -0.65 |
| Ana kart başlığı | 23–25 | 900 | 1.15–1.20 | -0.45…-0.65 |
| Bölüm başlığı | 20–21 | 800 | 1.20 | -0.4 |
| Konu/weak spot kart başlığı | 17–18 | 800 | 1.23 | -0.25 |
| Soru senaryosu | 16 | 400 | 1.55 | 0 |
| Gövde/açıklama | 13–14 | 400 | 1.45–1.50 | 0 |
| Küçük meta | 11–12 | 600–800 | 1.40 | 0 |
| Buton | 14–15 | 800 | 1.30 | 0 |

Bu ölçüler varsayılan metin boyutunun başlangıç değerleridir. Flutter logical pixel kullanın; ekran görüntüsünün fiziksel pikselini aynen taşımayın. Sistem metin ölçeğine ve uygulamanın Small/Medium/Large tercihlerine saygı gösterin. Önizlemedeki ölçekler .92/1/1.16 yalnızca örnektir; projedeki mevcut ölçek mantığını koruyun.

- Yatay sayfa payı: 18; dar ekranda 14. Kart içi pay: 17–20.
- Bölüm aralığı: 23–24. Liste kartları arası: 12. İkon/metin arası: 10–12.
- Büyük kart yarıçapı: 22–24. Input: 18. Ana buton: 14–15. Navbar: 29.
- Kart çerçevesi: 1. Patika başlığının/çerçevesinin çizgisi: 1.5.
- Buton yüksekliği: en az 48; ikon butonlarında en az 44×44 dokunma alanı.
- Light kart gölgesi: offset(0,5), blur18, renk #483018, opacity yaklaşık .10.
- Dark kart gölgesi: offset(0,5), blur18, siyah, opacity yaklaşık .17.
- Light navbar gölgesi: offset(0,6), blur22, #483018, opacity yaklaşık .15.
- Dark navbar gölgesi: offset(0,6), blur22, siyah, opacity yaklaşık .33.

## Ortak Flutter bileşenleri

Projenin mevcut yaklaşımına uygun isimlerle şu sorumlulukları ortaklaştır: sayfa yüzeyi, uygulama kartı, primary/text button, bölüm başlığı, topic tile, weak spot tile, seçili segment, alt navigasyon ve medal tile. Light/dark renkleri ThemeData/ThemeExtension benzeri merkezi bir yapıdan okut; ekran içine rastgele sabit renk dağıtma. Mevcut ikon ailesinin karşılıklarını kullan; önizlemedeki Lucide ikonlarını elle çizerek kopyalama.

Home/Review/Profile aynı sabit Home–Review–Profile navbarını kullanır: çerçeve + gölge, aktif ikon ve yazı linkAndActive renginde. Gerçek Flutter uygulamasında SafeArea ve liste alt padding'i ile içerik navbar altında kalmamalı. Önizlemenin tamamı görülsün diye tarayıcıdaki telefon çerçevesi uzar; bunu uygulamada dev bir telefon boyu veya sabit içerik yüksekliği olarak uygulama. Topic ve soru ekranında navbar yoktur.

## Home

- Büyük GrammarLens marka ismi. Good morning/evening gerçek saate, isim gerçek profile bağlı. Örnek isim Ahmet. Sağdaki hero seçici korunur; FREE etiketi eklenmez.
- Daily test ve patika AYRI kartlardır. Daily kartı turuncu, CTA lacivert.
- Daily yalnızca iki durum: başlamamış / bitmiş. Başlamamışta 5 questions ve Start daily test. Bitmişte gerçek doğru/5 skoru, Review results ve ertesi gün açıklaması. Kart içinde test ilerleme çubuğu yok.
- Patika kare alan olarak kalır. Mevcut oyun motorunu, puanlama ve hareket akışını değiştirme.
- Mountain of Learning: ortalanmış kalın başlık; harita kartının üst sınırına bitişen oval, çerçeveli plaka. Nötr tema yüzeyi kullan; harita temalarına bağımlı kum renkli şerit yok.
- Topic practice: yana kaydırılan konu kartları. Free kullanıcıda mevcut paywall; premium kullanıcıda topic seçimi/ilgili pratik akışı.
- Weak spots: mevcut yanlışların gerçek konu, tekrar sayısı ve son görülme bilgisi. Home'daki premium pratik yönlendirmesi korunur.
- En altta tekrar premium satış bandı yerine Review'a çağrı: kullanıcı seçtiği bir weak spot için günde bir ücretsiz pratik yapabilir.

## Review

- Kompakt Review başlığı. Üstte günlük ücretsiz pratik hakkını anlatan turuncu alan.
- Kullanılabilir / bugün kullanılmış durumları görsel ve metinle ayrılır. Kullanıldıktan sonra ücretsiz hakkı varmış gibi CTA gösterme; ertesi gün dönüş bilgisi, premium pratiğe geçiş ve kaydedilmiş açıklamaları inceleme yolu korunur.
- Ücretsiz hakkı kullanıcı herhangi bir kayıtlı weak spot için seçer. Sistemin zorladığı tek konuya çevrilmez.
- Liste: kategori, konu başlığı, kısa geri bildirim özeti, tekrar bilgisi ve tarih. Recent sıralaması ve projenin mevcut diğer sıralamaları korunur.
- Karttan ayrıntı; pratik sonunda mevcut AI API incelemesi ve açıklaması. Prototipteki sabit örnek yanıtları gerçek AI çıktısı yerine koyma.

## Profile

- Üst kimlik kartı: Your companion → ortalanmış büyük hero → Change your avatar. Hero görsel kutusu 158×158. Aşağıda Your name / Ahmet / Edit satırı.
- Edit, aynı kartta metin alanı ve Save/Cancel açar. Boş/yalnız boşluk isim kaydedilmez. Projenin mevcut isim sınırı esas; önizlemedeki 32 karakter gerçek ürün sınırı olarak zorlanmaz.
- Medal collection arka plansızdır; her madalyaya ayrı kart/daire zemini ekleme. Yatay, en yeni ay solda. Bulunulan ay henüz kazanılmadıysa görsel opacity yaklaşık .38; metin tam okunur.
- Madalyaya dokununca büyük görsel + ay + kazanılma durumu + ilgili detaylar. Önerilen büyüme geçişi yaklaşık 240ms ease-out; reduced-motion tercihinde hareket azaltılır.
- Aylık ilerleme ayrı kart: orange puan etiketi, bir sonraki madalya hedefi ve çubuk. Örnek 7/78 Bronze, 71 points to go; aylık toplam ayrı 7/310. Bronze78, Silver155, Gold233 örnek eşiklerdir; gerçek ayın hesaplanan eşiklerini kullan. 78'i her ay sabit varsayma.
- Bronze kazanıldıktan sonra next-medal hesabı Silver'a; Gold sonrasında tamamlanma mesajına geçer. Kazanılmış hedef için negatif kalan puan gösterme. Bu durumların metni uygulama verisine bağlanacak uygulama ayrıntısıdır; yeni puan kuralı icat etme.
- System/Light/Dark ve Small/Medium/Large kontrolleri, zorunlu Data ve Credits satırları korunur. Data/Credits mevcut ekranlarına gider.
- Birikmiş koleksiyon seçicisi yalnız önizleme aracıdır; geçmiş ay kayıtları örnek verilerdir, uygulamaya eklenmez.

## Soru

- Gerund vs. Infinitive konu başlığı kompakt; sağ üstte çıkış. İlk soruda önceki soru oku yok; projenin mevcut geri gitme davranışı sonraki sorularda korunur.
- Soru kartında soru tipi ve 1/3 sayacı, senaryo ve iki adımlı yönerge. Soru adedini gerçek testten al; Daily testte gerçek 5 soru kuralını koru.
- Kart altına yakın Your answer ve 2 connected sentences. Çok satırlı input min145 yükseklik. Boşluk doldurmada tek satırlı input kullan; her soruyu iki cümle formatına dönüştürme.
- Boş/boşluk yanıtta Next pasif, içerikte aktif. Son soruda Submit. Bu butonlar mevcut kaydet/gönder akışını çağırır. Basit nonempty kontrolünü cevabın doğruluğunu onaylamak için kullanma.
- Skip daha düşük vurgulu metin butonu. Çıkış için gösterilen onay önerilen etkileşimdir; verinin korunup korunmayacağı mevcut ürün davranışına göre belirlenir.
- Klavye açıldığında cevap ve ana eylem görünür kalır; içerik gerektiğinde kayar. Küçük ekranda metinler kesilmez. Gereksiz dikey spacer ile soru ve inputu ayırma.
- Önizleme açıklamayı kısaltıp böler. Gerçek AI içerikleri keyfî olarak değiştirilmez; veri sözleşmesi desteklemiyorsa mevcut yönerge metni korunarak hiyerarşi uygulanır. Share your hobbies gibi başlıklar UI örneğidir, tüm sorulara sabit yazılmaz.

## Topic Practice — TASLAK

- Premium erişimi açılmış konu seçme ekranı. Geri oku, Topic Practice başlığı ve kısa alt açıklama. Küçük Premium access etiketi sadece erişim durumudur; satın alma CTA'sı değildir.
- Mevcut beş konu: Gerund vs. Infinitive, Modal Verbs, Modal Past Forms, Tense Selection, Articles. Gerçek konu kaynağı ve ID'leri korunur; listede daha fazla konu varsa gizleme.
- Tek sütun, her konu tek dokunma hedefi. 38×38 küçük ikon yüzeyi, 17/800 başlık, 13/400 kısa açıklama, 11/600 durum, sağ chevron. Kart padding17×15, radius22, aralık12.
- İlk görünümde hepsi Not started yet, çünkü verilen ekranda bu durum vardı. Sahte skor, yüzde ilerleme, streak veya öğrenme düzeyi ekleme. Geçmiş çalışma varsa mevcut gerçek veriden durum üret.
- Konuya dokunmak mevcut pratik akışını başlatır. Birleşik önizlemede soru sekmesine gider; ayrı kaynakta yer alan ara dialog, yalnız demo bağlantısıdır, üretimde ekstra adım değildir.
- Bu ekranda tekrar paywall veya kilit yok. Free kullanıcı giriş kontrolü önceki ekranda/route guard'da mevcut mantıkla korunur; UI görünümü premium kontrolünün yerine geçmez.
- Beş konu için arama/filtre eklenmedi. Konu sayısı ve ürün ihtiyacı değişirse ayrıca değerlendirilir.

## Veri, uç durumlar ve erişilebilirlik

- Gerçek avatar, harita ve madalya PNG/SVG assetlerini projeden kullan. Önizleme madalyaları/map'i screenshot içinden CSS ile gösterir; bu crop tekniği veya screenshot üretim asseti değildir. Başka aylara ait örnek madalyalar tekrar kullanılan temsili görsellerdir.
- Uzun isim, konu adı ve çevrilmiş metinlerde satır sardır; kritik metni ellipsis ile gizleme. Yatay madalya/topic listesi hariç yatay taşma olmamalı.
- Review boşsa boş durum + daily test'e dönüş; ücretsiz hakkı kullanabilmek için olmayan bir weak spot gösterme. Koleksiyon boşsa mevcut Welcome/ay durumunu gerçek verilere göre kullan.
- Loading'de aynı eylemin tekrar tetiklenmesini engelle. API hatasında kullanıcının yanıtını kaybetme; hata ve yeniden deneme göster. Günlük hakkın tüketilmesi UI tıklamasıyla değil mevcut başarı/servis mantığıyla belirlenir.
- Semantics etiketleri: avatar değiştir, önceki soru, çıkış, konuya başla, madalya ayı/durumu, aylık ilerleme sayısal değeri. Renk tek başına durum belirtmesin.
- 320/390/430 logical pixel genişliklerde, en büyük yazı tercihinde, light/dark/system ve klavye açıkken kontrol et. Metni zorla küçülterek taşmayı gizleme.
- Kartları ve butonları klavye/screen reader odağıyla kullanılabilir tut. Modal açılınca odak içerisine geçer, kapanınca açan öğeye döner.

## Uygulama sırası ve tamamlanma kontrolü

1. Mevcut yapı ve veri akışını incele; ortak tema, tipografi, kart, buton ve navbar bileşenlerini güncelle.
2. Home → Review → Profile → soru ekranı. Her ekranda light/dark ve ana etkileşimleri doğrula; sonra sıradakine geç.
3. Topic taslağı onaylandığında aynı bileşenlerle uygula.
4. Mevcut projeye uygun analiz/testleri çalıştır. Özellikle daily ready/done, ücretsiz hak used/available, premium routing, isim düzenleme, madalya sırası ve input/klavye davranışını kontrol et.
5. Kullanıcıya beş ekranın aynı cihaz boyutunda light/dark görüntülerini, yapılan değişiklikleri ve kalan farkları göster. Yeni görsel tasarım bahanesiyle API, abonelik ve puanlama iş mantığını değiştirme.

Bu brief bağlayıcı kullanıcı kararlarıyla önerilen uygulama ayrıntılarını ayırır. Belirsiz hesap, veri saklama veya erişim davranışında mevcut ürün mantığını esas al; tahminle ürün kuralı oluşturma.
