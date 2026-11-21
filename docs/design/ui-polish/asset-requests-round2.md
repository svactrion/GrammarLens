# UI cilası — görsel istekleri, 2. tur

Tarih: 2026-11-17 · Kaynak: canvas, “Yeni tasarım — gruplar (v5)” sayfası
1. tur: `asset-requests.md` (Fox poz seti ve nesneler, tamamlandı)

## Karar: 8 hero

Seçimde kalan 8 hero ve her birinin karakter referansı:

| Hero | Referans dosyası | Korunacak özellikler |
|---|---|---|
| Fox | `assets/avatars/avatar_14.webp` | **Tamamlandı (1. tur)** |
| Panda | `assets/avatars/avatar_15.webp` | Siyah kulaklar, siyah göz lekeleri, siyah kollar ve bacaklar, krem gövde |
| Koala | `assets/avatars/avatar_01.webp` | Gri gövde, büyük yuvarlak kulaklar (içi açık gri), büyük siyah burun |
| Frog | `assets/avatars/avatar_05.webp` | Açık yeşil gövde, başın üstünde iki büyük göz, geniş gülümseme |
| Bird | `assets/avatars/avatar_13.webp` | Açık mavi gövde, turuncu küçük gaga ve ayaklar, kollar yerine kanatlar |
| Giraffe | `assets/avatars/avatar_11.webp` | Sarı gövde, turuncu-kahve lekeler, iki küçük boynuz, uzun boyun |
| Cat | `assets/avatars/avatar_08.webp` | Krem gövde, kapalı gülen gözler, bıyık çizgileri, sivri kulaklar |
| Sloth | `assets/avatars/avatar_16.webp` | Açık kahve gövde, yüzde koyu göz bandı, uzun kollar |

Seçimden kalkanlar (Snail, Elephant, Bee, Chick, Crab, Turtle, Penguin, Hedgehog) **silinmiyor**: bu heroyu seçmiş kullanıcılar onunla devam eder, yalnızca seçim ekranında görünmez. Onlar için poz üretilmeyecek; uygulamada ifade kiti kullanılacak.

## A · Poz seti: 7 hero × 6 poz = 42 görsel

**Üretim sırası:** her hero için önce `wave` üret ve kontrol et. Karakter referansla aynı görünüyorsa aynı heronun kalan 5 pozuna geç. Hero sırası: Panda → Koala → Frog → Cat → Sloth → Bird → Giraffe (zordan kolaya değil, kolaydan zora: kanat ve uzun boyun sona).

**Her üretimde iki görsel ekle:**
1. O heronun kendi avatar dosyası (karakter referansı)
2. Aynı adlı Fox pozu, örneğin panda için `fox_wave.png` (poz ve çerçeve referansı)

**Dosya adı:** `<hero>_<poz>.png`, örneğin `panda_wave.png`, `giraffe_sleep.png`.
**Klasör:** `docs/design/ui-polish/generated/round2/` (Documents’ta üretiyorsan da olur, yolu söylemen yeterli).

### Ortak stil (her prompt’un başına)

```
Same character and same style as the first attached image: a cute 3D clay-style animal icon,
soft matte velvet texture, rounded chubby shapes, big head and small body, simple line eyes,
pink cheeks, soft studio light from the top left, no outlines. Copy the pose and framing of
the second attached image, but keep the first image's character exactly (colors, markings,
ears, face). Front view, centered, full body visible, nothing cropped. Transparent background,
no ground shadow, no text, no extra objects unless asked.
```

### Pozlar (ortak stilden sonra; `<HERO>` ve `<LIMB>` yerine tablodaki değeri yaz)

| Poz | Prompt satırı |
|---|---|
| wave | `The <HERO> stands and waves hello with its right <LIMB> raised high, big happy closed-eye smile.` |
| cheer | `The <HERO> jumps with joy, both <LIMB>s up in the air, mouth open in a big smile, eyes closed happily. Feet slightly off the ground.` |
| think | `The <HERO> sits and thinks, one <LIMB> touching its chin, eyes looking up to the side, small curious smile.` |
| inspect | `The <HERO> holds a big magnifying glass in front of one eye and peeks through it, curious and focused. Magnifier: thick navy blue ring (#0D3B8F), light blue glass, navy handle.` |
| sad | `The <HERO> sits with its head slightly lowered, sad eyebrows, small frown, one small blue tear on the cheek. Still cute, not crying hard.` |
| sleep | `The <HERO> is curled up asleep, eyes closed, peaceful smile. Lying down, seen from the front.` |

### Heroya özel notlar

| Hero | `<LIMB>` | Not |
|---|---|---|
| Panda | paw | Göz lekeleri üzgün pozda da yerinde kalsın; gözyaşı lekenin altından aksın. |
| Koala | paw | Kulaklar üzgün pozda hafif aşağı düşebilir. |
| Frog | hand | Gözler başın üstünde; üzgün pozda kaşlar gözlerin üstüne çizilsin. Uyku pozunda yayvan yatış. |
| Cat | paw | Uyku pozunda kuyruk gövdeye sarılsın (Fox’taki gibi). |
| Sloth | arm | Referanstaki dal **olmasın** (kollar serbest kalsın). Uzun kollar: el sallama ve sevinçte kollar uzun görünebilir. |
| Bird | wing | Kollar yerine kanatlar: el sallama = tek kanat havada, sevinç = iki kanat açık. “Inspect”te büyüteci kanadıyla tutar. |
| Giraffe | front hoof | Uzun boyun: karakterin **yüksekliği** çerçeveye sığsın (genişlik %55 civarı olabilir). Boynuzların üstünde en az 48 px boşluk. Uyku pozunda boyun gövdeye kıvrık. |

### Ölçü ve çerçeve (1. turla aynı)

- PNG, 1024 × 1024 px, saydam arka plan
- Karakter ortada, genişlik ~%70 (Giraffe ~%55)
- Ayak altı y ≈ 920 px (yatan pozlar hariç), kenarlarda en az 48 px boşluk

## B · Bayrak, 2. sürüm (uygulama renkleri)

Canvas’taki bayrak şu an üretilen bayrağın **renkleri değiştirilmiş geçici hâli**: lacivert flama, turuncu şerit, krem kenar ve turuncu topuz. Canvas’ta beğendiysen yeniden üretmene gerek yok, bu dosyaları kullanırız. Daha temiz bir sonuç istersen:

| Dosya | Ölçü | Prompt (ortak stil yerine) |
|---|---|---|
| `summit_flag_pole_v2.png` | 256 × 1024 | `A single 3D clay-style flag pole, cream white wood with a small round orange (#FF7A1A) knob on top and a slightly pointed bottom tip. Vertical, centered, front view, matte texture, soft light from the top left. No flag cloth, no rocks, no shadow, transparent background.` |
| `summit_flag_pennant_v2.png` | 768 × 512 | `A 3D clay-style triangular pennant flag cloth only, deep navy blue (#0D3B8F) with one thick orange (#FF7A1A) horizontal stripe through the middle and a thin cream border, gently waving. The left edge is straight and vertical. Matte texture, soft light from the top left. No pole, no text, no shadow, transparent background.` |

## C · İfade kiti aksesuarları (6 küçük nesne)

Kit pozların üstüne ve pozu olmayan durumlara ekleniyor (örneğin yanlış cevaptaki ter damlası). Şu an canvas’ta düz SVG; kil stilinde olursa herolarla aynı dünyada durur.

| Dosya | Ölçü | Prompt (ortak stil yerine) |
|---|---|---|
| `prop_sparkle.png` | 256 × 256 | `A small 3D clay-style four-pointed sparkle star, warm gold (#FFC23C), soft rounded points, tiny white shine. No face, transparent background, no shadow.` |
| `prop_sweat.png` | 256 × 256 | `A single 3D clay-style sweat drop, light blue, glossy highlight on top left, teardrop shape. Transparent background, no shadow.` |
| `prop_tear.png` | 256 × 256 | `A single small 3D clay-style tear drop, light blue, rounder and smaller than a sweat drop. Transparent background, no shadow.` |
| `prop_thought.png` | 512 × 384 | `A 3D clay-style white thought bubble with three small navy dots inside and two tiny trailing circles at the bottom left. Transparent background, no shadow.` |
| `prop_cloud.png` | 512 × 320 | `A small 3D clay-style grey rain cloud, soft and rounded, with two tiny light blue rain drops under it. Transparent background, no shadow.` |
| `prop_zzz.png` | 384 × 384 | `Three 3D clay-style letters “Z”, white with a soft lavender shade, getting bigger from bottom left to top right. Transparent background, no shadow.` |

## D · Raf, 2. sürüm (isteğe bağlı)

1. turdaki raf çok ince geldi; madalyalar havada duruyor gibi.

| Dosya | Ölçü | Prompt (ortak stil yerine) |
|---|---|---|
| `medal_shelf_v2.png` | 1170 × 240 | `A 3D clay-style wooden shelf seen from the front and slightly above: a thick plank with a visible top surface (where objects stand) and a rounded front edge, warm light wood (#E7D6BC). Long and horizontal. No objects on it, no wall, no shadow, transparent background.` |

## Toplam

A: 42 · B: 2 (isteğe bağlı) · C: 6 · D: 1 (isteğe bağlı)

## Kontrol listesi (her görsel)

- [ ] Karakter kendi referansıyla aynı: renkler, lekeler, kulaklar, yüz
- [ ] Poz, aynı adlı Fox pozuyla aynı fikirde ve aynı çerçevede
- [ ] Saydam arka plan, kenarda hale yok
- [ ] Gölge, zemin, yazı, fazladan nesne yok (sloth’ta dal yok)
- [ ] Hiçbir parça kesilmemiş; kenarlarda ≥ 48 px boşluk
- [ ] 64 px’e küçültünce poz hâlâ okunuyor

## Lisans notu

Herolar CC BY 4.0 lisanslı “Cute Animal 3D Icons” setinden uyarlanıyor; yeni pozlar da uyarlama sayılır ve Credits ekranındaki atıf bunları kapsar. Bayrak, aksesuarlar ve raf sıfırdan üretim.
