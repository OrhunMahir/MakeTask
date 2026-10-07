# In Progress ve görev odağı düzeltmesi — 7 Ekim 2026

## Davranış

- Detay panelinde Priority etiketinin sağında To Do / In Progress menüsü. Dar genişlikte menü yalnız simgeye küçülür; erişilebilir adı ve açıklaması korunur.
- In Progress yarım dolu daireyle gösterilir, aktif bölümde kalır ve tamamlanan sayacını artırmaz. Daireye tek tık tamamlar. Tamamlamayı geri almak önceki aktif durumu geri getirir.
- Durum kalıcı kayıtta, JSON yedekte, içe aktarmada ve silme/geri alma geçmişinde korunur. Eski kayıt/yedekler To Do olarak açılır.
- Üst bara tıklama ve daraltma, görev seçimini ve düzenleme odağını temizler; görev başlığı taslağı önce kaydedilir. Liste başlığını düzenleme, sürükleme ve daraltma korunur.
- Daraltılmış notta görev kısayolları çalışmaz. Genişletme eski seçimi geri getirmez. Space/Return artık seçim yokken ilk görevi otomatik seçmez.

## Doğrulama

- Son koşu: **99 birim testi geçti, sıfır hata**. `/tmp/maketask-progress-unit-final.log`.
- Eski 1.1.1 modelinden oluşturulan gerçek SQLite veritabanı yeni modele açıldı; görevler/alt görevler ve metinler korundu, yeni durum kaydedilip yeniden açıldı.
- Yerel NSWindow/NSHostingView testi: seçili görev düzenlendi, başlık etkileşimi taslağı kaydetti, sonraki Space/Return eski görevi değiştirmedi. Başlık editörü ve gövde tıklaması ayrı doğrulandı.
- CUA ile izole Release uygulamasında In Progress menüsü ve görsel yerleşim görüldü; sayaç 0/2 kaldı, tek tıkla tamamlamada 1/2 oldu. Cmd+M ardından Space/harf/Delete ve tekrar genişletme görevi değiştirmedi. Düzenlenen başlık daraltmada kaydedildi.
- Yeni iki XCTest UI testi yazıldı ancak **UI test çalıştırıcısı başlatılamadı**: ilk koşu automation-mode timeout, ikinci koşu runner bağlantı timeout. Bu testler geçmiş sayılmaz. Başlık bölgesine fiziksel tıklamanın canlı kontrolü ekran yakalama hataları nedeniyle tamamlanamadı; yerel pencere regresyon testi geçti.
- Release preview derlendi. Gerçek kullanıcı verisi kullanılmadı.

## Kullanıcı denemesi

Uygulama: `build/ProgressPreview/Build/Products/Release/MakeTask.app` (görünen ad: MakeTask Progress Preview; bundle: `dev.orhun.MakeTask.ProgressPreview`). Ayrı veritabanı, App Group ve URL şeması kullanır. Global kısayollar bu preview kimliğinde kapalıdır; notun yerel Cmd+M ve menü komutları çalışır.

Preview'ın ayrı App Group'unda widget snapshot yazma izni uyarısı görüldü; bu kopyada widget doğrulaması yapılmadı. Görevlerin normal yerel kaydı çalıştı.

1. Bir görevin detayında In Progress seç; sayaç değişmemeli, tek tık tamamlamalı.
2. Görev başlığını düzenle, üst bardaki boşluğa veya liste adına tıkla; taslak kaydedilmeli ve görev seçimi kalkmalı.
3. Space/harf/Delete eski görevi değiştirmemeli. Liste adını özellikle düzenlemeye açarsan yazı girişi liste adına aittir.
4. Görev düzenlerken Cmd+M ile daralt; tuşlara bas, tekrar genişlet. Görev metni korunmalı, eski görev seçilmemeli.

## Yayın durumu

Yerel dal `task-progress-focus`. Kullanıcı 7 Ekim’de hazırsa App Store Connect’e yükleme yetkisi verdi. 1.1.1 (7), Connect’te Ready for Distribution olarak görüldü. Yeni sürüm 1.1.2 (8); universal Release arşivi ve App Store dağıtım imzası doğrulandı. Paket: `build/AppStore-ggkmzJ/Export/MakeTask.pkg`, SHA-256: `42da86aca7d262d9e65c847e94c71e48f0e43a69b70e5ab15199128125d0a273`. Connect sürüm formu, yenilikler ve inceleme notları hazırlandı; manuel yayın seçimi korundu. Kaynak `9b011e1` GitHub’a gönderildi. Build 8 yüklendi ve 7 Ekim 14:25 CEST’te Apple incelemesine gönderildi; Waiting for Review doğrulandı. Ayrıntı: `Release/1.1.2_STATUS_TR.md`.

7 Ekim yayın öncesi UI testi tekrarı da automation-mode başlangıç zaman aşımıyla durdu; testler çalışmış/geçmiş sayılmaz. 99 birim testi, yerel pencere regresyonu ve yukarıdaki canlı kontroller mevcut doğrulama kanıtıdır.
