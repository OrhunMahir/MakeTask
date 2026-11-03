# Konuma göre liste seçimi — 2 Kasım 2026

⌘← / ⌘→ / ⌘↑ / ⌘↓, etkin listenin solundaki/sağındaki/üstündeki/altındaki görünür listeyi seçer. Daraltılmış notlar dahildir. Pencerelerin o anki başlık konumları kullanılır; liste sırası ve notun açık gövde yüksekliği yön seçimini değiştirmez. O yönde komşu yoksa seçim aynı kalır; başa sarma yoktur. Gizli, küçültülmüş, başka Space'teki veya açık sheet'i olan hedefler seçilmez.

Metin alanı veya başka bir kontrol odaktayken normal ok tuşu davranışı korunur. Geçiş hedef listenin tuvaline odaklanır; önceden açık kalmış bir editör sonraki geçişi engellemez. Bu işlem görev taşımaz veya undo girdisi üretmez. Ayarlar → Shortcuts → List Navigation altında dört kısayol değiştirilebilir. Uygulama rehberi, README ve GUIDE güncellendi.

## Doğrulama

- 114 birim/yerel pencere testi başarılı. Dört yön, farklı açık/daraltılmış yükseklikler, kaydırılmış yerleşim ve negatif ekran koordinatları, gerçek key-window/first-responder aktarımı, gizli listeyi atlama, fareyle taşınan pencerenin yeni konumu ve kısayol çakışmaları kapsandı.
- Metin/yerel kontrollerin yeni kısayolları koruduğu mevcut routing testine eklendi.
- İzole Release preview derlemesi başarılı: `build/NavigationPreview/Build/Products/Release/MakeTask.app`. Bundle `dev.orhun.MakeTask.NavigationPreview`; ayrı App Group/URL şeması, üretim global kısayolları kapalı. Gerçek görev verileri ve kurulu uygulama değiştirilmedi.
- Pencere aktarımı native-window testinde doğrulandı. Orhun deneme sürümünü denedikten sonra 2 Kasım’da “tamam çalışıyor” diyerek manuel kabul verdi. Yeni fiziksel XCTest UI çalıştırması yapılmadı.

Değişiklikler `task-progress-focus` dalında `9961853` olarak commit edilip gönderildi. 1.1.4 (10), 3 Kasım 2026’da Apple incelemesine gönderildi: Waiting for Review; onay sonrası otomatik yayın seçili. Ayrıntılar: [1.1.4 yayın kaydı](1.1.4_STATUS_TR.md).
