# UI cilası — 9. hero: Crab (poz seti)

Tarih: 2026-11-17 · Önceki turlar: `asset-requests.md`, `asset-requests-round2.md`

Crab seçime geri dönüyor ve 9. hero oluyor. Diğer 8 hero gibi 6 poz alacak.

**Referans dosyası:** `assets/avatars/avatar_07.webp`

**Korunacak özellikler:**
- Parlak turuncu-kırmızı yuvarlak gövde
- Gövdenin üstünde iki kısa sapın ucunda siyah gözler
- Pembe yanaklar ve küçük gülümseme
- İki büyük kıskaç, iki yanda üçer küçük bacak

**Dikkat:** Crab’ın gövde rengi uygulamanın turuncusuna çok yakın. Turuncu kartların üstünde kaybolmasın diye rengi referanstaki kırmızıya yakın tut, turuncuya kaydırma.

## Üretim

**Her üretimde iki görsel ekle:**
1. `avatar_07.webp` (karakter referansı)
2. Aynı adlı Fox pozu, örneğin `fox_wave.png` (poz ve çerçeve referansı)

**Dosya adı:** `crab_<poz>.png` · **Klasör:** `docs/design/ui-polish/generated/round2/`
**Ölçü:** PNG, 1024 × 1024, saydam. Crab yatay bir karakter: genişlik ~%75, kıskaçların uçlarında en az 48 px boşluk. Bacak uçları y ≈ 920 px.

### Ortak stil (her prompt’un başına)

```
Same character and same style as the first attached image: a cute 3D clay-style crab icon,
soft matte velvet texture, rounded chubby shapes, simple black eyes on two short stalks,
pink cheeks, soft studio light from the top left, no outlines. Copy the pose idea and
framing of the second attached image, but keep the first image's character exactly
(red-orange color, eye stalks, two big claws, six small legs). Front view, centered,
full body visible, nothing cropped. Transparent background, no ground shadow, no text,
no extra objects unless asked.
```

### Pozlar

| Dosya | Prompt satırı (ortak stilden sonra) |
|---|---|
| `crab_wave.png` | `The crab waves hello with its right claw raised high and slightly open, big happy closed-eye smile.` |
| `crab_cheer.png` | `The crab jumps with joy, both claws up in the air, mouth open in a big smile, eyes closed happily. Legs slightly off the ground.` |
| `crab_think.png` | `The crab thinks, one claw gently touching the side of its mouth, eyes looking up to the side, small curious smile.` |
| `crab_inspect.png` | `The crab holds a big magnifying glass in one claw in front of one eye and peeks through it, curious and focused. Magnifier: thick navy blue ring (#0D3B8F), light blue glass, navy handle.` |
| `crab_sad.png` | `The crab sits low with its eye stalks drooping slightly, sad eyebrows, small frown, one small blue tear on the cheek, claws resting on the ground. Still cute, not crying hard.` |
| `crab_sleep.png` | `The crab is asleep, lying flat with legs tucked in, eye stalks bent down and eyes closed, claws folded in front of its body, peaceful smile.` |

## Kontrol listesi

- [ ] Renk referanstaki kırmızı-turuncu (uygulama turuncusundan ayrışıyor)
- [ ] İki göz sapı, iki kıskaç, altı bacak; fazladan uzuv yok
- [ ] Saydam arka plan, kenarda hale yok; gölge ve yazı yok
- [ ] Kıskaç uçları kesilmemiş, kenarlarda ≥ 48 px boşluk
- [ ] 64 px’e küçültünce poz hâlâ okunuyor

## Lisans notu

Crab, CC BY 4.0 lisanslı “Cute Animal 3D Icons” setinden; pozlar da uyarlama sayılır ve Credits ekranındaki atıf bunları kapsar.
