# PlayStation (PS) Salon Yönetim Sistemi

Bu proje, bir PlayStation kafesinin veya benzer oyun salonlarının günlük işlemlerini kolayca takip edebilmeniz için geliştirilmiş bir **Flutter** uygulamasıdır. Veritabanı ve kimlik doğrulama süreçleri için **Supabase** altyapısı kullanmaktadır.

## ✨ Özellikler

- **Masa / Konsol Takibi:** Cihazların (PS4, PS5 vb.) boş, dolu veya arızalı olup olmadığını anlık görüntüleme.
- **Süre ve Adisyon Yönetimi:** Süreli/süresiz oyun açılışı, eklenen ürünlerin (içecek, yiyecek) masaya yansıtılması ve toplam hesabın otomatik hesaplanması.
- **Gelişmiş Kimlik Doğrulama:** Supabase Auth sayesinde güvenli Giriş/Çıkış işlemleri.
- **Çoklu Platform:** Hem masaüstü (Windows, macOS) hem de mobil (Android, iOS) platformlarda çalışacak şekilde tasarlanmıştır.

## 🚀 Teknolojiler
- **Arayüz (UI/UX):** [Flutter](https://flutter.dev/) (Dart)
- **Backend / Veritabanı:** [Supabase](https://supabase.com/) (PostgresSQL & Authentication)
- **State Management:** Provider / Riverpod (Projedeki tercihine göre)

## ⚙️ Kurulum ve Çalıştırma

1. Repo'yu bilgisayarınıza kopyalayın:
   ```bash
   git clone https://github.com/KULLANICI_ADINIZ/PS_Salon_Yonetim.git
   ```
2. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
3. Uygulamayı çalıştırın (Windows veya Android/iOS emülatör seçili olmalıdır):
   ```bash
   flutter run
   ```

## 🔐 Supabase Uyarıları & Güvelik (Önemli)

Eğer kendi veritabanınızı bağlayıp sunucu olarak kullanacaksanız:
1. `lib/core/constants/supabase_constants.dart` dosyasındaki değerleri kendi Supabase **URL** ve **Anon Key** değerleriniz ile değiştirmelisiniz.
2. Açık kaynak kodlu (public) repolara yüklerken, veritabanınıza yetkisiz kişilerin işlem yapmaması için Supabase panelinizden **Row Level Security (RLS)** kurallarını `Aktif` (Enabled) yapmayı unutmayın!

## 🤝 Katkıda Bulunma
Herhangi bir hata bulursanız veya yeni bir özellik eklemek isterseniz "Pull Request" gönderebilir veya "Issue" açabilirsiniz.

