# MakeTask mobil önizleme

iPhone ve iPad arayüzünü Mac'teki MakeTask 1.1.4 kaynaklarıyla karşılaştıran, Mac'te de derlenen geliştirme uygulaması. Önizleme kendi yerel test verisini ve CloudKit alanını kullanır.

| MakeTask 1.1.4 | Mobil önizleme |
| --- | --- |
| Liste oluşturma, yeniden adlandırma, renk, sıralama ve silme | On Mac rengi, aynı renk şeridi, tamamlanma sayacı ve liste düzenleme |
| Quick Add ve görev arama | Şimşek düğmesiyle liste seçerek hızlı ekleme, görev başlığı, not ve alt görevlerde arama |
| Görev durumları ve öncelik | Aynı daire, yarım daire, onay işareti ve renkli bayraklar |
| Not, son tarih, alt görev, listeye taşıma | Görev detayından düzenleme ve görev/alt görev sıralama |
| Tamamlanan görevler | Katlanabilir bölüm ve tamamlananları temizleme |
| Ana uygulama ikonu | Mac ile aynı çizim, iOS ikon boyutlarına Xcode tarafından derleniyor |
| Mac pencere modları, menü çubuğu, global kısayollar | iPhone'da dokunmatik gezinme, iPad'de yan yana liste ve detay |
| Geri al/yinele | Liste ve görev menülerinde. Geri alma geçmişi oturum boyunca tutulur. |
| Yedek içe/dışa aktarma | Mac ile aynı JSON biçimi. İçe aktarma listeleri yeni kimliklerle ekler. |
| Widget ve tamamlanma sesi | Ürün entegrasyonunda ele alınacak |

## Xcode ile dene

1. `MakeTaskSyncPrototype.xcodeproj` projesini aç. `MakeTaskSyncPrototype` şemasını ve iPhone/iPad simülatörünü veya Mac'i seç. Bir liste oluştur, renk seç, şimşek düğmesinden görev ekle ve görev detayında öncelik, tarih, not ve alt görev eklemeyi dene.
2. iCloud testi için Apple Developer takımını seç. `dev.orhun.MakeTask.SyncPrototype` geliştirme App ID’sine Push Notifications ve `iCloud.dev.orhun.MakeTask.SyncPrototype` CloudKit container’ı ekle. Mac ve iOS geliştirme profillerinde bu container ve push yetkileri bulunmalı. [Apple’ın CKSyncEngine örneği](https://github.com/apple/sample-cloudkit-sync-engine)
3. Uygulamayı aynı iCloud hesabını kullanan Mac ve fiziksel iPhone’da çalıştır. İkisinde de ana listenin üç nokta menüsünden **iCloud Sync → Connect to iCloud** seç. Mac’te bir test listesi ve görev ekle. iPhone’da değişiklik gelmezse **Sync Now** ile getir.
4. iPhone’u uçak moduna al, görevi tamamla ve uygulamayı kapatıp yeniden aç. Tamamlanma ve bekleyen değişikliği doğrula. Bağlantıyı açıp eşitle. Mac’te tamamlanmış tek görev göründüğünü doğrula.
5. Görevi Mac’te yeniden aç. iPhone’da onayın kalktığını ve görevin çoğalmadığını doğrula. Liste rengi, notlar, tarih ve alt görevleri de iki yönde kontrol et.

Bu sürüm `store-v2.json` ve ayrı bir geliştirme CloudKit bölgesi kullanır. İlk test sürümündeki `store.json` kendi konumunda durur. iCloud bağlantısı her açılışta kullanıcı tarafından başlatılır. Ürün SwiftData geçişi ve alan düzeyinde çakışma çözümü sonraki aşamadır.

## Mac yedeğini önizlemede dene

Ana ekrandaki üç nokta menüsünden **Backup → Import Backup** ile Mac’in dışa aktardığı JSON dosyasını seç. İçe aktarma, önizlemedeki listeleri korur ve yedekteki listelerin kopyalarını ekler. **Undo** ile son içe aktarmayı geri alabilir veya **Redo** ile yeniden uygulayabilirsin. **Export Backup** önizleme verisini Mac’in okuyabileceği JSON olarak kaydeder.
