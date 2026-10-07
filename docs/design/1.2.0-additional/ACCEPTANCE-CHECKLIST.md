# Uygulama kabul kontrolü

Bu liste Claude Code'un Flutter uygulamasında çalıştıracağı kontrollerdir. İşaretlenmemiş maddeler yapılmış sayılmaz. Paketin HTML önizlemeleri daha önce tarayıcıda denendi; gerçek Flutter cihaz testi yapılmadı.

## Soru V2 — öncelikli

- [ ] iOS ve Android gerçek sistem klavyesi kullanılıyor; maket klavye uygulamada yok.
- [ ] Rewrite cevabı alt satıra sarılıyor; tek satır/yatay kaydırma yok.
- [ ] 2 satırdan başlayan cevap alanı satır eklendikçe büyüyor, silince küçülüyor.
- [ ] Uzun cevap sınırdan sonra dikey kayıyor; soru ve eylemler alan dışına itilmiyor.
- [ ] Uzun cevapta baştaki kelimeyi seçme/düzeltme, copy/paste ve ortadan düzenleme çalışıyor.
- [ ] Return yeni satır açıyor; Next/Submit tetiklemiyor. IME composing bozulmuyor.
- [ ] Kısa/orta soru ve yönerge, standart boyutta klavye açıkken tamamen görünüyor.
- [ ] Küçük ekran + uzun soru: okunabilir metin, erişilebilir kaydırma ve Read full question; overflow/ellipsis yok.
- [ ] Done/Review answer klavyeyi kapatıyor, cevabı koruyor, okuma alanını artırıyor.
- [ ] Next → Back → Next sırasında tüm soruların cevapları ID bazlı korunuyor.
- [ ] İlk soruda geri uygun disabled durumda; geri düğmesi oturumdan çıkmıyor.
- [ ] Çıkış × ayrı ve mevcut onay/kayıt davranışını koruyor.
- [ ] Boş cevap, yalnız boşluk, çok uzun cevap, satır sonları ve emoji destekleniyor.
- [ ] Skip, son soruda Submit ve oturum uzunlukları mevcut mantıkla çalışıyor.
- [ ] İleri/geri/fokus değişimi ekstra AI isteği, puan veya hak tüketimi yaratmıyor.
- [ ] API loading/başarısızlıkta çift gönderim engelleniyor, metin kaybolmuyor.
- [ ] Klavye öneri çubuğu, farklı klavye yüksekliği, cihaz döndürme ve büyük yazıda taşma yok.

## Onboarding

- [ ] Tüm gerçek kahramanlar kaydırılabiliyor, merkezde seçilen büyüyor ve ID doğru kaydediliyor.
- [ ] İsim boşken Continue çalışıyor; isimsiz selamlama düzgün, Unicode isimler korunuyor.
- [ ] İsim klavyesi açıkken alan ve devam eylemi erişilebilir.
- [ ] Adımlar arası geri dönüşte isim/hero/amaç korunuyor.
- [ ] Amaç seçiminde varsayılan seçim yok; atlama ayrı/null değer olarak korunuyor.
- [ ] Amaç için kişiselleştirme/başlangıç önerisi vaadi yok.
- [ ] Araştırma verisinin gerçek kaydı/aktarımı incelendi; gizlilik metni buna uygun.
- [ ] Yeni telemetry sağlayıcısı veya izinsiz isim/cevap aktarımı eklenmedi.
- [ ] AI bilgilendirmesi mevcut AI onay mekanizmasının yerine geçmiyor.
- [ ] Tamamlama ve tekrar açılışta mevcut onboarding kayıtları doğru.
- [ ] İlk test zaten tamamlanmışsa yeni ücretsiz hak veya mükerrer oturum yaratılmıyor.

## Paywall

- [ ] Seçili kullanıcı kahramanı her durumda ortada; örnek Sloth sabitlenmemiş.
- [ ] Free günlük weak spot hakkı ve gerçek premium faydaları doğru gösteriliyor.
- [ ] Plan değişiminde fiyat, süre, CTA ve renewal metni birlikte güncelleniyor.
- [ ] Fiyat/para birimi ve trial eligibility mağazadan; hardcoded tasarruf/deneme yok.
- [ ] Satın alma başarılı/iptal/hata/bekliyor ve restore durumları gerçek servisle doğrulanıyor.
- [ ] Terms/Privacy gerçek sayfaları açıyor; kapat ve Maybe later geri dönüyor.
- [ ] Kod modalı klavye açıkken kullanılabiliyor; modal dışı sayfa etkileşimi kapalı.
- [ ] Boş kod, loading, geçersiz/süresi dolmuş/kullanılmış/uygun değil ve ağ hatası durumları mevcut.
- [ ] Kodun gerçek doğrulama kaynağı belirlendi; istemcide sahte doğrulama yok.
- [ ] İndirim koşulları ve ücretsiz erişim süresi onaydan önce gösteriliyor.
- [ ] Kod modalı kapatılınca plan seçimi kaybolmuyor.

## Ortak görsel ve erişilebilirlik

- [ ] Light/dark ve sistem tema değişimi; Nunito Sans gerçek ağırlıkları.
- [ ] 320/360/390/430 logical px genişlik, büyük sistem yazısı ve uzun yerelleştirilmiş metin.
- [ ] Minimum44 dokunma alanı; ana eylemler48 ve üstü.
- [ ] VoiceOver/TalkBack okuma sırası, seçim etiketleri, disabled/loading bilgisi.
- [ ] Modal odak yakalama, geri/escape kapatma ve eski odağa dönüş.
- [ ] Reduce motion; yavaş ağ ve eksik asset/ürün/veri durumları.
- [ ] Önizleme seçicileri, sahte status bar ve örnek completion mesajları üretimde yok.
