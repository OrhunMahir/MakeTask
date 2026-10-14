> 14 Ekim güncel durum: Bu değişiklikler 1.1.3 (9) ile gönderildi; güncel doğrulama ve yayın bilgisi için [1.1.3_STATUS_TR.md](1.1.3_STATUS_TR.md). Aşağıdaki kayıt önceki yerel çalışma durumudur.

# Başlık düzenlemesini boş alandan kapatma — 7 Ekim 2026

1.1.2 (8) gönderiminden sonra bildirilen ayrı düzeltme; henüz Apple paketine dahil değil.

- İsim düzenleyicisi yazı genişliğiyle sınırlı; yanındaki boşluk tıklama/sürükleme alanı olarak kalır.
- Boş alana tek tık adı kaydeder, düzenleme ve metin seçimini kapatır.
- Düzenleme açıkken de boş alana çift tık daraltır/genişletir; taslak korunur.
- Yazının içine tıklamak imleci korur. Gecikmeli odak/seçim işlemleri kapanmış editörü yeniden etkinleştirmez.

Doğrulama: **100 birim/yerel pencere testi geçti**; `/tmp/maketask-header-rename-final.log`. Yeni regresyon gerçek NSHostingView içindeki başlığı düzenler, boşluk geometrisini kontrol eder, tek/çift fare olaylarını hem açık hem daraltılmış notta çalıştırır ve taslağı/daraltma durumunu doğrular.

Release preview derlendi: `build/ProgressPreview/Build/Products/Release/MakeTask.app`; ayrı bundle/veritabanı `dev.orhun.MakeTask.ProgressPreview`. Canlı arayüzde menüden Rename açıldı, metin seçimi ve boş alan görüldü; koordinatla tıklama CUA `noWindowsAvailable` hatasıyla engellendi, bu bölüm manuel geçmiş sayılmaz.

Yerel değişiklikler `task-progress-focus` dalında, `430a436` üzerine uygulanmış ve henüz commit/push edilmemiş durumda. İncelemedeki build 8 değiştirilmedi. Yeni yayın için bu düzeltmeyle yeni build gerekir.
