# MakeTask iPhone, iPad ve iCloud planı

**Hedef:** Mac'te açık olan yapılacaklar listesine iPhone'dan görev eklemek, yolda internet olmadan düzenlemek ve bağlantı geldiğinde iki cihazda da aynı güncel listeyi görmek. İlk sürüm için iPhone ve iPad varsayıldı. Android yakın vadede gerekliyse bulut mimarisi ilk aşamada yeniden seçilmeli.

## İlk sürüm kapsamı

| İki yönlü eşitlenen | Cihaza özgü |
| --- | --- |
| Liste adı, rengi, sırası ve silinmesi | Mac not penceresinin konumu, boyutu, görünürlüğü ve katlanma durumu |
| Görev başlığı, notu, önceliği, son tarihi, tamamlanma ve devam ediyor durumu | Mac klavye kısayolları, açılış ayarı, yerel geri alma geçmişi |
| Görevin listesi, sırası, oluşturulma ve tamamlanma tarihi | Widget'ta hangi listenin gösterildiği, son açık ekran ve hızlı ekleme hedefi |
| Alt görevler, sıraları, tamamlanma durumları ve tarihleri | Her cihazın yerel yedek dosyaları |

Mac'te masaüstünden gizlenen bir listenin içeriği telefonda görünür. Bir görevi başka listeye taşımak, silmek veya tamamlamak iki cihazda da uygulanır. Mobil uygulama renkli liste kartları, liste detayı, arama, hızlı görev ekleme ve görev düzenleme sunar. iPad aynı işlevleri yan yana liste ve detay görünümüyle kullanır. Mobil ana ekran widget'ı ve bildirimler, çekirdek eşitleme yayınlandıktan sonra eklenebilir.

## Teknik yaklaşım

- **Başlangıç noktası:** Scaphoid'deki son kayıtlı Mac release kaynağı olan `9961853`, yerel `origin/main` referansındaki değişiklikleri içeriyor. Ürün entegrasyonu için güncel dağıtım kaynağını tekrar doğrula. 1.1.4 kaynaklarında SwiftData yerel, widget ise App Group üzerinden anlık görüntü okuyor.
- **Uygulamalar:** Aynı Xcode projesine native SwiftUI iOS/iPadOS target'ı ekle. SwiftData modellerini, platformdan bağımsız renk ve öncelik değerlerini ve görev işlemlerini iki target arasında paylaş. AppKit, pencere yönetimi ve global kısayollar macOS target'ında kalsın.
- **Yerel veri:** SwiftData iki cihazda da okuma ve yazma kaynağı olsun. Mac'teki mevcut store konumu, UUID'ler, görev hiyerarşisi ve pencere durumu korunsun. Ortak bir yazma katmanı Mac hızlı ekleme, düzenleme, widget aksiyonları, import, geri alma ve mobil işlemlerini kapsasın. Widget görüntüsü yerel veya uzaktan gelen değişiklik uygulandıktan sonra yenilensin.
- **iCloud:** Önerilen yaklaşım, iki target'ta aynı CloudKit container'ının özel veritabanına `CKSyncEngine` ile bağlanmak. Böylece SwiftData modellerindeki `@Attribute(.unique)` ve zorunlu ilişki dizilerini CloudKit'e uygun hale getirmek için değiştirmek gerekmiyor. CloudKit'e yalnızca eşitlenecek alanlar çıkar. Bu yaklaşım kayıt eşlemesini ve çakışma kurallarını uygulamada yönetmeyi gerektiriyor. İlk prototipte bu maliyeti ve gerçek cihaz davranışını doğrula. [Apple'ın CloudKit seçenekleri](https://developer.apple.com/documentation/cloudkit/deciding-whether-cloudkit-is-right-for-your-app) · [SwiftData otomatik eşitleme kısıtları](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- **Eşitleme durumu:** Ayarlarda iCloud eşitlemesini kullanıcı açar. Aynı iCloud hesabındaki cihazlar aynı veriyi görür. Bekleyen değişiklikleri veriyle birlikte kaydet, engine durumunu kalıcı tut ve başarısız gönderimleri yeniden dene. Kullanıcı son başarılı eşitlemeyi ve bekleyen değişiklikleri görebilsin. Arka plan eşitlemesinin zamanlaması sistem ve bağlantıya bağlı olduğundan arayüz anlık teslim sözü vermesin. [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)

## Uygulama sırası

| Aşama | Yapılacak iş | Bitirme ölçütü |
| --- | --- | --- |
| 1. Prototip | Release tabanını doğrula. Ayrı test store'u ve geliştirme CloudKit ortamıyla Mac ve fiziksel iPhone arasında tek listeyi ve bir görevi eşitle. İmzalama, iCloud yetkileri ve push davranışını kontrol et. | Görev iki yönde düzenleniyor ve internetsiz değişiklik uygulama yeniden açıldıktan sonra da gönderiliyor. |
| 2. Veri güvenliği | Sürümlü kayıt eşlemesi, sabit kayıt kimlikleri, kalıcı gönderim kuyruğu, hesap değişimi ve ilk eşitlemeyi ekle. Eski Mac store kopyalarıyla yükseltme ve yeniden deneme testleri yaz. | İlk eşitleme kesilip tekrarlandığında kopya oluşmuyor. Bir yedek dosyasından geri yükleme yolu test edilmiş. |
| 3. Mobil uygulama | Liste kartları ve detay, hızlı ekleme, arama, alt görev, öncelik, son tarih, durum ve listeye taşıma. iPad düzeni ve eşitleme ayarları. Mac'te uzaktan gelen liste ekleme/silme olaylarını açık pencereler ve widget ile uzlaştır. | Aynı görev telefon, Mac not penceresi ve Mac widget'ında güncelleniyor. Mac'teki pencere düzeni korunuyor. |
| 4. Beta ve yayın | İki cihazlı regresyon testleri ve dahili TestFlight. App Store Connect'te mevcut MakeTask kaydına iOS platformu ekleme ve aynı bundle ID uygunluğunu doğrulama. CloudKit production şeması, gizlilik açıklamaları, ekran görüntüleri ve inceleme notları. | Güncellenmiş Mac sürümüyle mobil sürümün production eşitlemesi beta kurulumunda doğrulanmış ve yayın sırası hazır. |

Mac'e eşitlemeyi getiren güncellemenin dağıtımı, mobil çıkıştan önce veya aynı yayın penceresinde tamamlanmalı. Mevcut App Store kaydına iOS platformunu eklemek universal purchase sağlar. [Apple App Store Connect — platform ekleme](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-platforms)

## Veri güvenliği ve kabul senaryoları

- **İlk açılış:** Mevcut Mac verisinin UUID'leri koruyan bir yedeğini al. Güncel JSON import yeni UUID ürettiğinden yükseltme geri dönüşü için store düzeyinde bir yedekleme yolu doğrula. İlk eşitlemede cihazdaki ve buluttaki kayıtları UUID ile birleştir. İki cihazda farklı UUID ile açılmış aynı isimli listeleri koru. Yeni cihazda ilk bulut kontrolü bitmeden otomatik örnek liste oluşturma.
- **Aynı anda düzenleme:** Başlık ve son tarih gibi bağımsız alanları birleştir. Aynı alan iki cihazda düzenlenmişse deterministik bir kural kullan. Tamamlanma durumu ve zamanı birlikte güncellensin. Liste değiştirme ve sıralama birlikte uygulansın. Eşit sıralama değerleri cihazlar arasında sabit bir ikinci anahtarla çözülsün.
- **Silme ve geri alma:** Çevrimdışı cihazın eski bir görevi yeniden oluşturmasını engellemek için silmeyi sürümlü bir kayıt olarak işle. Silinen bir üst listenin altındaki görev ve alt görevleri tutarlı biçimde ele al. Kullanıcının açıkça geri aldığı silme, eski bir güncellemeden ayırt edilebilsin.
- **Hesap ve bağlantı:** İnternet kesilmesi, uygulamanın kapanması, iCloud'dan çıkış, hesap değiştirme, eşitlemeyi kapatıp açma ve kota dolması test edilsin. Bekleyen yüklemeler hesapla ilişkilendirilsin. Bir hesaptan gelen kayıtlar başka hesaba kendiliğinden aktarılmasın. [Apple — hesap değişikliği olayı](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/event/accountchange)
- **Mevcut kullanıcı:** Üretim store'unun bir kopyasını yükseltip önceki ve sonraki UUID'leri, kayıt sayılarını, görev hiyerarşisini ve pencere düzenini karşılaştır. Güncellenmiş Mac + temiz iPhone ve daha önce veri eklenmiş iPhone + güncellenmiş Mac senaryolarını ayrı çalıştır.

**İlk geliştirme teslimi:** [MakeTask Sync Lab](MobileSyncPrototype/README.md) projesinde Mac'te eklenen test görevi iPhone'da görünsün. iPhone uçak modundayken görevi tamamla, uygulamayı kapatıp aç ve bağlantıyı geri getir. Mac'te tamamlanma durumunun güncellendiğini ve iki cihazda da aynı kimliğe sahip tek görev bulunduğunu doğrula. Widget kontrolü ürün entegrasyonunda yapılır.
