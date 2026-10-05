# GrammarLens — Premium Review, Data ve Credits

6 Ekim 2026 • Flutter için ek tasarım teslimi

Bu paket yalnızca üç alanı kapsar: Premium Review üst kartı, Data ve sadeleştirilmiş Credits. Ana ekran, soru, onboarding, paywall ve diğer canlı ekranlar bu işin kapsamı dışındadır.

## Claude Code ile kullanım

1. ZIP'i aç ve bu klasörü projedeki Claude Code oturumuna kaynak olarak göster.
2. `CLAUDE-START-PROMPT.txt` içeriğini gönder.
3. Claude önce `CLAUDE-CODE-BRIEF.md`, ardından `ACCEPTANCE-CHECKLIST.md` dosyalarını okumalı.
4. `index.html` tarayıcıda iki önizlemeye bağlantı verir. Data ve Credits aynı önizlemedeki ekran seçicisinden açılır. İkisi de light/dark destekler.

## En son kararlar — önceki görsellerin önüne geçer

- Suggested Focus yalnızca Premium Review'da görünür; seçim Saved weak spots içindeki **en yüksek count** değerine göre yapılır.
- Premium üst kartının ölçüsü canlıdaki **Free Review üst kartıyla aynı** olmalı. Kaynak önizlemedeki sabit ölçüler canlı uygulamanın ölçüsünü değiştirme gerekçesi değildir. Ortak kart kabı kullanılmalıdır.
- Credits görselsizdir: hero, illüstrasyon, büyük rozet ve teşekkür alanı kaldırıldı. Eser, üretici, uyarlama bilgisi ve iki bağlantı korunur.
- Data onaylanan tasarımı korur.

## İçerik

- `CLAUDE-CODE-BRIEF.md`: ölçüler, davranışlar, seçim kuralları, Flutter aktarımı.
- `ACCEPTANCE-CHECKLIST.md`: uygulama sonrası kontrol listesi.
- `design-tokens.json`: önizleme renkleri ve temel ölçüler; canlı ortak tema önceliklidir.
- `source/`: düzenlenebilir görsel kaynaklar; üretim kodu değildir.
- `previews/`: sandbox iframe ve CSP korunarak dışa aktarılmış önizlemeler.

Mockup'lardaki butonlar gerçek izin, silme veya pratik işlemi yapmaz. Fontlar ve önizleme bağımlılıkları için internet gerekebilir. Flutter uygulamasında mevcut font asset'leri ve mevcut bileşenler kullanılmalıdır. Telefon çerçevesi, saat, önizleme seçicileri ve örnek veri notları uygulamaya taşınmaz.

Üretim deposu bu teslim için incelenmedi veya değiştirilmedi. Flutter doğrulaması henüz yapılmadı; kontrol listesi bu nedenle boş bırakıldı.
