# UI cilası — özel görsel (asset) istekleri

Tarih: 2026-11-17 · Kaynak: tasarım canvas’ı, “İlk kullanıcı yolculuğu” sayfası, öneri v4
Amaç: canvas’taki v4 ekranlarında CSS ile taklit ettiğimiz duyguları (üzgün yoldaş, uyuyan yoldaş, yeni bayrak, puan yıldızı…) gerçek görsellerle güçlendirmek.

## Nasıl çalışacağız

1. Aşağıdaki sırayla üret (önce **A grubu**). Her dosyayı tablodaki adıyla `docs/design/ui-polish/generated/` klasörüne koy.
2. Bana “A grubu hazır” de. Ben her görseli kontrol listesiyle (en altta) kontrol eder, WebP’ye çevirir, canvas’taki ilgili ekranlara yerleştiririm.
3. Canvas’ta beğenirsen, uygulamaya entegrasyon için Claude Code prompt’unu hazırlarım (dosyalar o zaman `assets/` altına taşınır).

Üretim aracına her seferinde **iki referans görseli** ekle:
- `assets/avatars/avatar_14.webp` (Fox — stil ve karakter referansı)
- Bu dosyadaki “Ortak stil” paragrafı

Kısa brief’ler uzun kural listelerinden daha iyi sonuç verdiği için prompt’lar kısa tutuldu. Önce ortak stil paragrafını, sonra görselin kendi satırını yapıştır.

## Ortak stil (her prompt’un başına)

```
Same character and same style as the attached reference: a cute 3D clay-style animal icon,
soft matte velvet texture, rounded chubby shapes, big head and small body, simple black
line eyes and nose, pink cheeks, soft studio light from the top left, no outlines.
Front view, centered, full body visible, nothing cropped. Transparent background,
no ground shadow, no text, no extra objects unless asked.
```

Araç saydam arka plan vermezse: düz `#F0F0F0` gri arka plan iste, ben keserim (beyaz arka plan istemeyin; açık renkli kürk kenarları kaybolur).

## Ölçü ve çerçeve kuralı (heroların hepsi için)

- Dosya: **PNG, 1024 × 1024 px**, saydam.
- Karakter yatayda ortada, genişliği görselin yaklaşık **%70’i**.
- Ayakların altı **y ≈ 920 px**’de (yüksekliğin ~%90’ı). Mevcut avatarlarla aynı oran; kod gölgeyi ve zemin elipsini kendisi çiziyor, bu yüzden görselde gölge olmasın.
- Kulak/kuyruk/el kenara değmesin, en az **48 px** boşluk kalsın (animasyonda sallanınca kesilmesin).
- Uygulamaya 508 × 508 WebP olarak gireceği için ince detaylar (tek tel kıl, küçük yazı) kaybolur; büyük, net formlar tercih.

---

## A grubu — en çok etkisi olanlar (önce bunlar)

### A1–A6 · Fox poz seti

Uygulamanın varsayılan yoldaşı Fox. Önce yalnızca Fox’u üretiyoruz; stil 16 heroda tutarlı kalıyorsa diğer 15 hero için aynı 6 poz gelecek (bkz. “Sonra”).

| # | Dosya adı | Nerede kullanılır (canvas) | Prompt (ortak stilden sonra) |
|---|---|---|---|
| A1 | `fox_wave.png` | 02 Welcome, 03 Yoldaşını seç, R6 Yoldaşı değiştir | `The fox stands and waves hello with its right paw raised high, big happy closed-eye smile.` |
| A2 | `fox_cheer.png` | 08 Doğru, 10 Sonuç, 11 Rozet, R5 Madalya | `The fox jumps with joy, both paws up in the air, mouth open in a big smile, eyes closed happily. Feet slightly off the ground.` |
| A3 | `fox_think.png` | 18 Hazırlanıyor, 20 AI değerlendirme | `The fox sits and thinks, one paw touching its chin, eyes looking up to the side, small curious smile.` |
| A4 | `fox_inspect.png` | 20 AI değerlendirme (yükleme ekranı), 01 Açılış | `The fox holds a big magnifying glass in front of one eye and peeks through it, curious and focused. Magnifier: thick navy blue ring (#0D3B8F), light blue glass, navy handle.` |
| A5 | `fox_sad.png` | 13b Çıkış pop-up’ı, R10 Testten çıkış, R11 Bağlantı yok | `The fox sits with ears drooping down and head slightly lowered, eyebrows sad, small frown, one small blue tear on the cheek. Still cute, not crying hard.` |
| A6 | `fox_sleep.png` | 24 Günün görevleri bitti (kamp), widget’ların gece hâli | `The fox is curled up asleep, eyes closed, tail wrapped around its body like a blanket, peaceful smile. Lying down, seen from the front.` |

Not: A6 yatık poz olduğu için “ayak altı y ≈ 920” kuralı gövdenin alt kenarı için geçerli; genişlik %80’e kadar çıkabilir.

### B1 · Yeni zirve bayrağı (iki katman)

Sorun: mevcut bayrak turuncu ve dibinde taşlar var; turuncu dağda kayboluyor, taşlar kalabalık. Yeni bayrak hem tutorial’da (06, zirvenin tam ucunda) hem uygulamadaki C6 noktasında kullanılacak. Flama ayrı katman olmalı ki kodda dalgalansın.

| # | Dosya adı | Ölçü | Prompt (ortak stil **yerine** bunu kullan) |
|---|---|---|---|
| B1a | `summit_flag_pole.png` | 256 × 1024 px, saydam | `A single 3D clay-style flag pole, cream white wood with a small round gold knob on top and a slightly pointed bottom tip, as if planted in the ground. Vertical, centered, front view, soft light from the top left, matte texture. No flag cloth, no rocks, no ground, no shadow, transparent background.` |
| B1b | `summit_flag_pennant.png` | 768 × 512 px, saydam | `A 3D clay-style triangular pennant flag cloth only, deep navy blue (#0D3B8F) with one thick gold (#FFC23C) horizontal stripe through the middle and a thin cream border, gently waving. The left edge is straight and vertical (it attaches to a pole). Soft light from the top left, matte texture. No pole, no text, no shadow, transparent background.` |

Yerleşim (kod için): direk görselin ortasında; flamanın sol kenarı direğin merkezine, direğin üstünden %6 aşağıya bağlanır. Taban taşı yok; altındaki küçük gölgeyi kod çizer.

### B2 · Puan yıldızı

| # | Dosya adı | Ölçü | Nerede | Prompt (ortak stil yerine) |
|---|---|---|---|---|
| B2 | `points_star.png` | 512 × 512 px, saydam | 14/15 Home puan kapsülü, 23 Profil, 24 kamp ekranı, 08 Doğru’da “+2” uçuşu | `A chunky 3D clay-style gold star (#FFC23C) with soft rounded points, a slightly darker golden rim and a small white shine on the top left. Slight 3/4 tilt. No face, no text, no sparkles, no shadow, transparent background.` |

Kontrol: 40 px’e küçültüldüğünde hâlâ yıldız olarak okunmalı.

---

## B grubu — sahneleri zenginleştirenler

| # | Dosya adı | Ölçü | Nerede | Prompt (ortak stil yerine) |
|---|---|---|---|---|
| C1 | `hero_podium.png` | 1024 × 384 px, saydam | 03 Yoldaşını seç, R6, 23 Profil sahnesi | `A low round 3D clay podium seen from slightly above (about 35 degrees), warm cream color (#F2E6D8), soft rounded rim, empty flat top. Matte texture, soft light from the top left. No character, no shadow, transparent background.` |
| C2 | `lens.png` | 512 × 512 px, saydam | 01 Açılış, 02 Welcome demo, 20 AI değerlendirme | `A 3D clay-style magnifying glass, thick navy blue ring (#0D3B8F), light blue translucent glass with one white curved highlight, short navy handle pointing to the bottom right at 45 degrees. Front view, centered. No shadow, transparent background.` |
| C3 | `campfire_logs.png` | 512 × 384 px, saydam | 24 Günün görevleri bitti | `A small 3D clay-style campfire base: three crossed brown logs inside a ring of small grey stones, no flames, no smoke. Seen from slightly above. No shadow, transparent background.` (Alevi kod çizip titretiyor.) |
| C4 | `medal_shelf.png` | 1170 × 180 px, saydam | 23 Profil madalya koleksiyonu | `A simple 3D clay-style wooden shelf plank, warm light wood (#E7D6BC), front view, long and thin, rounded edges. No objects on it, no wall, no shadow, transparent background.` |

---

## Sonra (A grubu tutarlı çıkarsa)

- **Diğer 15 hero için aynı 6 poz** (A1–A6). Dosya adı: `<hero>_<poz>.png`, ör. `panda_sad.png`. Hero adları: koala, snail, elephant, bee, frog, chick, crab, cat, turtle, penguin, giraffe, hedgehog, bird, fox, panda, sloth. Toplam 90 görsel; her hero için A1’i (wave) önce dene, karakter referansla aynı görünüyorsa kalan 5’e geç.
- Referans olarak her seferinde o heronun kendi `assets/avatars/avatar_XX.webp` dosyasını ekle (Fox’unkini değil).
- Tutarlılık tutmazsa plan B: pozlar yalnızca Fox’ta kalır, diğer herolar mevcut görselle + kodla verilen hareketle (zıplama, sallanma, düşen kulak yerine eğilme) devam eder. Bu kararı A grubundan sonra birlikte verelim.

## Kontrol listesi (her görsel için)

- [ ] Karakter referansla aynı: renkler (turuncu gövde, krem göğüs/yüz, pembe yanak), yüz çizgileri, doku.
- [ ] Saydam arka plan, kenarlarda beyaz/gri hale yok.
- [ ] Gölge, zemin, yazı, fazladan nesne yok.
- [ ] Hiçbir parça kesilmemiş; kenarlarda ≥ 48 px boşluk.
- [ ] Ayak altı y ≈ 920 px (yatan pozlar hariç).
- [ ] 64 px’e küçültüldüğünde poz hâlâ anlaşılıyor (el sallıyor mu, üzgün mü?).

## Lisans notu

Herolar CC BY 4.0 lisanslı “Cute Animal 3D Icons” setinden uyarlanıyor. Yeni pozlar da uyarlama sayılır; Credits ekranındaki “Adapted from …” atfı bunları da kapsıyor, metin değişmeden kalmalı. Bayrak, yıldız, kürsü, mercek, kamp ateşi ve raf sıfırdan üretim; atıf gerektirmez.
