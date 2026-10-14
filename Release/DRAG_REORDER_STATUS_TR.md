# Görev sürüklerken canlı sıralama — 13 Ekim 2026

Kullanıcı, 1.1.2 (8) sürümünü yayımladığını bildirdi. Bu çalışma o yayından sonraki yerel düzeltmedir; önceki başlık düzenleme düzeltmesi korunmuştur.

## Değişiklik
- Satır başına SwiftUI bırakma hedefleri yerine bütün görev alanını kapsayan sabit AppKit hedefi kullanılır. Fare satırların orta noktalarını geçtikçe görevler kayar ve sürüklenen satır için arada yer açılır.
- Liste boşluğuna bırakma artık görevi koşulsuz sona eklemez; görünen konum korunur.
- Sürükleme görseli gerçek satır genişliğini, yazı boyutunu ve tamamlanma/In Progress simgesini kullanır; boş yerin çerçevesi hafifletilmiştir.
- Kenara yaklaşınca liste kayar. Değişken satır yüksekliği ve arama sonuçları hesaba katılır; görev tamamlanma durumu değişmez.
- Esc veya geçersiz yere bırakma başlangıç sırasını geri getirir. Başarılı taşıma tek geri alma işlemi olarak kaydedilir. 30 saniyede sürüklemeyi zorla bitiren zamanlayıcı kaldırılmıştır.

## Doğrulama
- **107 birim/yerel pencere testi geçti**, sıfır hata: `/tmp/maketask-drag-final.log`.
- Yeni testler: gerçek NSHostingView notunda native hedefe sürükleme olayları, bırakmadan önce sıralama, aynı yerde beklerken kararlılık, tek undo/redo; yukarı/aşağı/sona hareket; değişken yükseklik, durum ve arama koruması; boş listeye geçiş/iptal/kalıcılık; yabancı payload reddi ve kenar kaydırması.
- Release önizleme derlendi: `/tmp/maketask-drag-preview.log`.
- Önizleme: `build/ProgressPreview/Build/Products/Release/MakeTask.app`; bundle `dev.orhun.MakeTask.ProgressPreview`, ayrı veri/App Group/URL scheme. Gerçek görevler kullanılmadı.
- Canlı fare otomasyonu denendi, ancak önizleme süreci çalışmasına rağmen AX ve CGWindow listelerinde pencere bulunamadı. Fiziksel fareyle canlı doğrulama tamamlanmış sayılmaz. Otomasyon için açılan geçici süreçler kapatıldı; normal ayrı önizleme başlatıldı. Kullanıcı görsel kabulü bekleniyor.

Kaynak dalı `task-progress-focus`, HEAD `430a436`. Bu değişiklikler ve önceki başlık düzeltmesi commit/push edilmedi; App Store'a yeni paket gönderilmedi.
