# 🍼 BebeCam (Görüntülü Bebek Telsizi)

**BebeCam**, Flutter ve WebRTC teknolojileri kullanılarak geliştirilmiş, ultra düşük gecikmeli (low-latency) uçtan uca (Peer-to-Peer) görüntülü ve sesli bir bebek telsizi uygulamasıdır.

Bu uygulama iki farklı cihazda çalışarak bir cihazı **Bebek Ünitesi (Kamera)**, diğerini ise **Ebeveyn Ünitesi (İzleyici)** olarak kullanmanıza olanak tanır. İki cihaz arasındaki bağlantı (Signaling) Firebase Realtime Database üzerinden sağlanırken, görüntü ve ses aktarımı doğrudan cihazlar arasında (P2P WebRTC) gerçekleşir.

---

## ✨ Özellikler

- **📹 Uçtan Uca Görüntülü ve Sesli İletişim:** WebRTC sayesinde saniyeden daha düşük gecikmeyle kesintisiz canlı yayın.
- **👶 Bebek Ünitesi Modu:** Cihazın kamerasını ve mikrofonunu açarak odayı izlemeye başlar ve rastgele 4 haneli bir bağlantı kodu üretir.
- **👨‍👩‍👧 Ebeveyn Ünitesi Modu:** Bebek ünitesinin ürettiği 4 haneli kodu girerek kameraya anında ve güvenli bir şekilde bağlanır.
- **⚡ Firebase Signaling:** Hızlı ve güvenilir WebRTC SDP ve ICE Candidate takası için optimize edilmiş altyapı.
- **🎨 Modern Arayüz (UI):** Göz yormayan koyu tema (Dark Theme) ve kullanıcı dostu sade ekranlar.
- **📱 Çapraz Platform:** Tek bir kod tabanıyla hem iOS hem de Android cihazlarda tam uyumluluk.

---

## 🛠️ Kullanılan Teknolojiler

- **[Flutter](https://flutter.dev/):** Mobil uygulama geliştirme çatısı.
- **[flutter_webrtc](https://pub.dev/packages/flutter_webrtc):** Video ve ses iletişimi için WebRTC entegrasyonu.
- **[Firebase](https://firebase.google.com/):** İki cihazın internet üzerinden birbirini bulması (Signaling) için Realtime Database kullanılmıştır.
- **[Provider](https://pub.dev/packages/provider):** Durum (State) yönetimi.
- **[permission_handler](https://pub.dev/packages/permission_handler):** Kamera ve mikrofon izinlerinin yönetimi.

---

## 🚀 Kurulum & Çalıştırma

Projeyi kendi bilgisayarınızda derlemek ve çalıştırmak için aşağıdaki adımları izleyin:

### 1. Gereksinimler
- Flutter SDK yüklü olmalıdır (`flutter doctor` ile kontrol edebilirsiniz).
- Uygulamayı test edebilmek için fiziksel iOS veya Android cihazlar önerilir (WebRTC simülatörlerde kamera kısıtlamaları yaşatabilir).
- Kendi Firebase projenizin (Realtime Database özellikli) hazır olması gerekmektedir.

### 2. Adımlar

```bash
# Projeyi klonlayın
git clone https://github.com/eisildak/bebeCam.git

# Proje dizinine girin
cd bebeCam

# Bağımlılıkları indirin
flutter pub get
```

### 3. Firebase Yapılandırması
1. Firebase Console üzerinden `bebecam-9a5fe` (veya kendi projeniz) isimli bir proje oluşturun.
2. **Realtime Database** servisini aktif edin.
3. Database kurallarını test edebilmek için Rules sekmesini aşağıdaki gibi güncelleyin:
   ```json
   {
     "rules": {
       ".read": true,
       ".write": true
     }
   }
   ```
4. Projenize uygun `google-services.json` (Android) ve `GoogleService-Info.plist` (iOS) dosyalarını indirip proje içerisine dahil edin.

### 4. Derleme

```bash
# İlk cihazda (Bebek Ünitesi olarak) başlatmak için:
flutter run

# İkinci cihazda (Ebeveyn Ünitesi olarak) başlatmak için:
flutter run
```

---

## 📸 Ekran Görüntüleri

*Buraya projenin arayüzüne ait mock-up veya screenshot dosyalarını ekleyebilirsiniz (`assets/mock-up/` vb.)*

---

> Güle güle kullanın! Bebeğiniz her zaman güvende. 💤🧸
