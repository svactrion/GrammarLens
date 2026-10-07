# GrammarLens — Ek ekranlar teslim paketi

Bu paket **Paywall + iki adımlı Onboarding + yeni Soru V2** tasarımlarını içerir.

## Başlangıç

ZIP'i çıkar. `index.html` dosyasını tarayıcıda açarak üç önizlemeye ulaş. Claude Code'a bu klasörü kaynak göster ve önce `CLAUDE-CODE-BRIEF.md` dosyasını okut.

- `CLAUDE-CODE-BRIEF.md`: kapsam, ölçüler, etkileşimler, Flutter yaklaşımı, korunacak işleyiş ve bağlantı gereksinimleri.
- `design-tokens.json`: önceki ortak tema ve bu üç ekranın ek/istisna değerleri.
- `ACCEPTANCE-CHECKLIST.md`: uygulama sonrası kontroller; yapılmış test raporu değildir.
- `CLAUDE-START-PROMPT.txt`: Claude Code'a doğrudan yapıştırılabilecek talimat.
- `previews/`: korumalı iframe ve CSP ile tarayıcıda açılabilir üç ekran.
- `source/`: düzenlenebilir HTML tasarım kaynakları; Flutter üretim kodu değildir.

## Sürüm önceliği

**Bu paketin Soru V2 tasarımı, önceki beş ekranlık paketin Soru ekranının ve o ekrana ait brief maddelerinin yerini alır.** Diğer dört ekranın kararlarını değiştirmez.

Onboarding kopyasında artık amaç seçiminin kişiselleştirme yaptığı söylenmez. Soru kullanıcı kitlesini anlamak ve geliştirmelere yön vermek içindir. Gerçek veri aktarımı mevcut projede doğrulanmalıdır.

Paywall kod penceresi işlevsel bir arayüz taslağıdır; gerçek kod doğrulama/abonelik servisi içermez. Fiyat ve deneme şartları örnektir. Soru ekranındaki klavye de simülasyondur; Flutter'da sistem klavyesi kullanılmalıdır.

## Önizleme notları

Light/dark seçimi her dosyada bulunur. Paywall'da planlar ve kod penceresi; onboarding'de kahraman kaydırma, iki adım ve amaç seçimi; Soru V2'de metin büyümesi, geri/ileri, klavye açık/kapalı, küçük ekran ve uzun soru denenebilir.

Kahraman görselleri dosyalara gömülüdür. Font ve ortak önizleme kaynakları internet bağlantısı gerektirebilir. Flutter'da projenin kendi görsel/font assetleri kullanılır. Bu paket yayınlanmış bir site veya uygulanmış uygulama güncellemesi değildir.
