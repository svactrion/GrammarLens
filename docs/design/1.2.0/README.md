# GrammarLens — Beş ekran, tek çalışma

- `index.html`: tarayıcıda açılabilen birleşik önizleme. Home, Review, Profile, Soru ve Topic Practice sekmeleri; ortak light/dark seçimi.
- `CLAUDE-CODE-BRIEF.md`: Claude Code'a verilecek uygulama briefi. Önce bu dosyayı okut.
- `design-tokens.json`: renk, tipografi ve ölçü başlangıç değerleri.
- `source/`: düzenlenebilir önizleme kaynakları. Flutter kodu değildir.

Topic Practice yeni taslaktır; diğer ekranlar önceki kararlara dayanır. Topic'i değerlendirdikten sonra aynı pakette revize edebiliriz.

Claude Code'a önerilen başlangıç mesajı:

> CLAUDE-CODE-BRIEF.md dosyasını oku ve index.html içindeki beş ekranı incele. Mevcut Flutter projesini inceleyerek önce ortak tema ve bileşenleri, sonra onaylı ekranları sırayla uygula. Var olan veri, premium erişim ve AI API iş mantığını koru. Topic Practice henüz taslak olduğu için üretim uygulamasına geçirmek üzere onaylı kabul etme. Her ekranın light/dark ve büyük metin görünümünü kontrol et.

Önizlemedeki üst sekmeler ve durum seçicileri gerçek uygulamaya eklenmez. Veri ve akışların bir kısmı temsili örnektir. Modal içindeki yer tutucular, madalya screenshot kırpımları ve örnek AI geri bildirimleri üretim kodu/asset/veri olarak kullanılmaz. Gerçek görseller projedeki assetlerden, içerik mevcut kaynaklarından gelir.

Bu dosya paketi yereldir; canlı web yayını içermez. Font/ikon CDN kaynakları için internet bağlantısı gerekebilir.
