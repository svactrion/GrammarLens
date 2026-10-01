# GrammarLens scene-art: prompt ve referans kaydı (1 Ekim 2026)

Araç: ChatGPT görsel üretimi (Gemini denendi, dağı üretemediği için bırakıldı).
Bu kayıtta yalnızca gerçekten yapılanlar var. Kontrol edilmemiş şeyler en altta "Açık / doğrulanmamış" başlığında.

## Klasör yapısı (kararlaştırılan)

```
scene-art/
├── green/        background_light.png, background_dark.png, raw/ (upscale öncesi hâller)
├── volcanic/     background_light.png (geçici tema; dark yok, zirve bayrağı yok)
├── objects/      campfire, tent, fountain, cabin, summit_flag (.png, şeffaf)
└── PROMPTS.md
```

Yol kalıbı: `<tema>/background_<mod>.png`. Nesneler temadan bağımsız `objects/` altında.

## Alınan kararlar (build-log için)

1. **Kamera:** düz cephe yerine hafif yukarıdan (~35°) eğik bakış. Düz cephe metinle kontrol edilemedi (3 deneme: koni, alçak açı, piramit).
2. **Patika arka planın parçası.** Eski karar "patika kodla çizilecek" idi. Yeni karar: patika resimden gelir, kodda orta çizgisi (polyline) çıkarılır, adımlar yay uzunluğuna göre eşit dağıtılır (28–31). Avatar patikaya sığmazsa avatar ölçeklenir.
3. **Patika spiral değil, switchback:** ön yamaçta sağa-sola kıvrılır, hiçbir kısmı dağın arkasına girmez.
4. **Oran 3:4** (9:16 yerine). Ay geçişinde dağın tamamı karta daha büyük sığar.
5. **Nesneler ayrı üretilir, kodla yerleştirilir.** Sebep: durum değişimi (ulaşılınca belirme), temalar arası yeniden kullanım, yer değişikliği.
6. **Her tema light + dark çifti.** Dark = sahnenin tamamı alacakaranlık. Önce Green, diğer temalar cihazda test sonrası.
7. **Zirve bayrağı yalnızca zirvesi uygun temalarda** (volkanikte yok).
8. **`pine.png` ve `shrub.png` listeden çıktı:** sahnede zaten çam/çalı/kaya var.
9. **START yazısı** ChatGPT'ye bırakıldı (bayrak üzerinde). Bozulursa kodla eklenir.
10. **Renk uyumu ChatGPT'ye bırakıldı** (Ahmet'in kararı).

## Doğrulananlar (ölçüldü)

- Volkanik ↔ Green light overlay: patika, 6 boşluk, START bayrağı, halı piksel piksel çakışıyor.
- Green light ↔ Green dark overlay: aynı sonuç. Yani **tek patika koordinat seti light/dark ve temalar için geçerli**.
- Sahnede 6 düz boşluk var (3 sol, 3 sağ), hepsi dönemeç dış köşesinde ve patikaya bitişik. En üstteki diğerlerinden biraz küçük.

## Ne işe yaradı, ne yaramadı

- **İşe yarayan:** Ahmet'in kısa, amaç odaklı brief'i + avatar referansları + bulduğu dağ/patika referansı. Model kompozisyonu kendi çözdü.
- **İşe yaramayan:** uzun, yüzdeli, yasak listeli promptlar; gri blok kompozisyon referansı (model ortadaki sert ışık çizgisini kıvrım yaptı, yine koni çıktı); Gemini.
- **Düzenleme kuralı:** tek mesajda tek değişiklik ("Keep everything the same, but ..."), aynı sohbette.
- **Nesneler için:** yeni sohbet, sahne görseli + avatarlar referans, düz açık gri zemin (arka plan silmek için).

## Referanslar (yüklenenler)

- Avatarlar: salyangoz, koala, kurbağa (yalnızca stil).
- Ahmet'in bulduğu dağ + patika referans görseli (düşük-poly, filigranlı; yalnızca açı/yerleşim fikri).
- Nesneler için: `green/background_light.png` (açı, ışık, stil) + avatarlar.

## Promptlar (sırayla, kullanıldığı gibi)

### Temel brief (Ahmet'in, ChatGPT; referanslar: avatarlar + dağ/patika örneği)

> Bir mobil uygulamada avatarlarımın bir dağ patikasında yürümesini kurguluyorum. Karakterlerimi ekledim (kurbağa, koala, salyangoz), renk paletlerini kavra. Örnek referans olarak bir dağ ve patika tasarımı ekledim. Dağ 3B görünse de patikada karakterlerim 2B olarak Monopoly gibi ilerleyecek, yaklaşık 28 ila 31 arasında değişken patika adımı. Kod tasarımında kullanabileceğim bir background istiyorum: ortada bir dağ, çevresinde patikadan başlayan bir yol ve dağa tırmanış.

Çıktı: Green ve volkanik iki varyant. Volkanik üzerinden devam edildi.

### 1. Oran (volkanik)

```
Keep everything the same (style, colors, path shape, mountain, scene elements), but change the image to a 3:4 vertical aspect ratio. Keep the whole mountain visible with the summit near the top and the start of the path near the bottom. Do not crop the summit or the start of the path.
```

### 2. Boşluklar

```
Keep everything the same (style, colors, path shape and width, mountain, lighting, camera angle, image size), but make a small, flat, empty clearing on the outer side of each of the six bends of the path. Each clearing should be a flat oval patch of plain ground, about the size of a small round table, right next to the outer curve of the bend, touching the path edge. Keep the clearings completely free of rocks, plants, lava cracks and any other objects, using the same ground color and texture as the surrounding terrain.
```

### 3. Start halısı (beğenilmedi, geri alındı)

Halı yeterince okunmadı, önceki görsele (altı boşluklu) dönüldü. Prompt kayda değmiyor.

### 4. START bayrağı (kabul)

```
Keep everything the same (style, colors, path shape and width, mountain, lighting, camera angle, image size, and the six clearings), but add a start flag planted in the ground right beside the very beginning of the path at the bottom of the image. Make it a small, cute, clay-style pole with a banner, in a warm color that fits the scene, standing on the flat ground next to the path's start and not on the path itself. The banner shows only the word "START" in clean, clear capital letters, and nothing else. The flag must be large enough to read at a glance, but much smaller than the clearings' surroundings and clearly not blocking the path.
```

Not: patikanın ucundaki ince halı yine de görselde kaldı, kodda başlangıç noktası olarak kullanılabilir.

### 5. Green tema (volkanikten)

```
Keep everything the same (camera angle, image size, composition, mountain shape, path shape and width, the six flat clearings, the START flag and the mat), but change the theme to a calm, soft spring meadow: replace all lava, fire and glowing cracks with soft green grass and gentle small streams, replace the volcano crater with a rounded summit with a small soft snow cap, and use soft sage and mint greens, pale grey-green sky, hazy pale sage-blue distant hills, and soft warm-grey rocks. Keep the light, soft, matte clay-like style.
```

### 6. Green dark (alacakaranlık)

```
Keep everything the same (camera angle, image size, composition, mountain shape, path shape and width, the six flat clearings, the START flag and the mat, and all rocks, plants, streams and waterfalls in the same positions), but change the lighting to a calm dusk. Make the sky a deep twilight blue-violet with a few soft dim clouds and a hint of warm glow near the horizon. Make the whole landscape dimmer and cooler: slightly darker, more muted green grass, cool blue-tinted shadows, soft muted rocks and a slightly dim path, and a gentle cool tint on the water. Keep the light direction from the upper left but much weaker. Keep the soft matte clay-like style. No stars, no moon, no glowing objects.
```

### 7. Ay ve yıldız (önerildi, KULLANILMADI: Ahmet yıldızsız dark hâlini seçti)

```
Keep everything the same (camera angle, image size, composition, mountain, path, clearings, START flag, mat, rocks, plants, water, lighting on the landscape), but add a few small, soft, clay-style stars and a gentle crescent moon in the upper part of the dark sky only. Keep them subtle and sparse, with a soft glow limited to the sky. Do not add any glow or light to the landscape below. Do not change the sky colors.
```

### 8. Nesneler (yeni sohbet; referanslar: green/background_light.png + avatarlar)

Ortak kalıp: sahnenin açısı/ışığı/stili, düz açık gri zemin, kenarlarda boşluk, kare görsel, yazı/insan/hayvan/filigran yok, turuncu (#F0843A) yalnızca küçük vurgu.

**Kamp ateşi (kabul):** taşlarla çevrili küçük kamp ateşi, turuncu alev, küçük duman.

**Çadır (kabul):** küçük, yumuşak renkli çadır, giriş kenarında turuncu vurgu.

**Çeşme (kabul):** gri taş havuz, orta sütun, açık mavi su akıntısı.

**Kulübe (3 tur):**
1. Krem renkli yastık duvarlı ev: reddedildi (ahşap gibi okunmadı).
2. Kalaslı kahverengi ev, bacalı: reddedildi (hâlâ oyuncak ev ikonu).
3. Kütük kulübe, kabul (yeşil yosun yaması modelin eklediği bir hata olarak çıktı, ayrı mesajla kaldırıldı):

```
Redo the fourth object, same style, camera angle, lighting and framing as the other objects (campfire, tent, fountain), but as a rustic log cabin instead of a plank house: walls built from thick, rounded, slightly uneven logs in warm brown, with the log ends sticking out and overlapping at the corners. A low, wide roof with a generous overhang, slightly uneven, in a darker brown. A small, slightly narrow wooden door set a little off-center, one tiny round window, and no chimney. Add a tiny warm orange (#F0843A) accent only as a small door knob. Keep soft rounded clay-like edges and a matte finish, but make the proportions less perfect and less symmetrical, like a cozy little forest cabin, not a toy house or a house icon. Small and simple, readable at a very small size. Show it alone, centered, on the same plain flat light grey background (no ground, no shadow on the background), with generous empty margin around it. Square image. No text, no people, no animals, no watermark.
```
Düzeltme: `Keep everything the same, but remove the green patch from the roof. The roof should be plain brown wood with no green or any other added patch on it.`

**Zirve bayrağı (kabul):** küçük taş yığını üzerinde ince ahşap direk ve turuncu üçgen flama, yazısız. Turuncu bilinçli seçim: marka rengi, ayın hedefi.

## Son durum

- `green/background_dark.png` = yıldızsız, ay yok (altıncı prompttaki hâl).
- Upscale ve arka plan silme Ahmet tarafından kontrol edildi, sorun yok.

## Açık / doğrulanmamış

- Upscale (2x) ve arka plan silme sonuçlarını ben görmedim; Ahmet kontrol etti, sorun yok dedi. Uygulama içinde (cihazda) küçük boyutta yine bakılacak.
- Kamp ateşinin dumanı gri zeminde silikti; silinince kaybolduysa sorun yok, halesi kaldıysa temizlenmeli.
- Çadır giriş kanatları küçükte "kapı" olarak okunmayabilir; çeşme "kâse" gibi okunabilir; kulübe hâlâ biraz oyuncak. Hepsi cihazda test edilecek.
- Beş nesne aynı açıyla üretildi ama ışık yönü sahneyle birebir doğrulanmadı. Sol/sağ yerleşimde yatay çevirmek (flipX) ışığı sağ üste kaydırır.
- Boşluk kullanımı: 6 boşluk var (3 sol, 3 sağ), save point sayısı 4. Ahmet "3 sağ / 2 sol" dedi, hangi beşi/dördü kullanacağı ana sohbette netleşecek.
- Volkanik tema için dark versiyon ve temalar arası geçiş (3 tema daha) üretilmedi.
- Oran 3:4 ile kartın ~350 pt penceresi arasındaki kadraj çalışması (ay geçişinde tam dağ gösterimi) ana sohbette yapılacak.

## Ana sohbette yapılacaklar (Claude Code için girdi)

1. `green/background_light.png` üzerinden patikanın orta çizgisini (polyline) çıkar, yay uzunluğunu ölç, ay uzunluğuna göre 28–31 adımı eşit dağıt.
2. Altı boşluğun merkez koordinatlarını belirle; save point'lere hangilerinin atanacağına karar ver.
3. Nesneleri koordinatlara yerleştir, sol/sağ için flipX kullan.
4. `background_dark.png` ile aynı koordinatları kullan (overlay ile doğrulandı).
5. Volkanik tema için nesne ve bayrak kararı cihaz testinden sonra.
