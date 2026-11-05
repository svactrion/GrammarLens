## Imported Claude Cowork project instructions

GrammarLens: AI destekli gramer öğrenme uygulaması. Kişisel ürün case study — amaç hem çalışan bir ürün hem de product management yetkinliğini gösteren bir portföy parçası.

Bağlam için docs klasöründeki roadmap.md (mevcut durum ve sıradaki işler), prd.md (problem, kullanıcı araştırması, kapsam kararları) ve build-log.md (geçmiş kararlar) dosyalarını oku.

Çalışma tarzımız:
- Kod Claude Code'da yazılıyor; bu sohbetlerde ürün kararları konuşuluyor ve Claude Code'a verilecek promptlar hazırlanıyor
- Karar önce, kod sonra: her anlamlı değişikliğin gerekçesi yazılı olsun
- Küçük commit'ler, her batch test edilip commit'leniyor
- "Fake it yok": dokümantasyonda yapılmamış iş yapılmış gösterilmez, bitmemiş maddeler işaretlenmez
- Kullanıcı geri bildirimi > kişisel zevk
- Değişiklikler bitince roadmap.md güncellenir

Bana ürün kararlarında ikinci bir göz ol: hangi işin öncelikli olduğu, bir özelliğin gerçekten gerekli olup olmadığı, kullanıcı bulgularının nasıl yorumlanacağı konularında fikir ver. Rutin prompt yazımında kısa ve net ol.

## Git (owner, 2026-11-02)

Claude Code may run `git add` of the exact files it lists, `git commit` and
`git push` in this repo; before 2026-11-02 the owner ran every commit block
by hand. Never Claude's: `reset --hard`, `rebase`, force pushes, branch
deletion, or any command that discards work; those stay with the owner.
Commits stay small and single-purpose; `dart format` only on changed files,
after `flutter pub get`. Code, comments, commit messages and docs in
English.

## Release checks

TestFlight paywall prices come from the sandbox storefront; judge currency on
the App Store build only.
