// Basit bir RealtimeService örneği
class RealtimeService {
  // Buraya gerçek zamanlı servis ile ilgili fonksiyonlar eklenebilir
  void connect() {
    // Bağlantı kodu buraya
  }

  void listenAll({void Function(String table, dynamic data)? onChange}) {
    // Tüm kanalları dinleme kodu buraya
    // Örnek tetikleyici:
    if (onChange != null) {
      onChange('example_table', {'id': 1, 'value': 'örnek'});
    }
  }
}
