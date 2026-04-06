import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Kullanıcı profil bilgisi (kullanicilar tablosundan).
class KullaniciProfil {
  final String id;
  final String email;
  final String rol;
  final String? isletmeAdi;
  final bool isPremium;
  final DateTime? trialBaslangic;
  final int trialGunSayisi;

  KullaniciProfil({
    required this.id,
    required this.email,
    required this.rol,
    this.isletmeAdi,
    required this.isPremium,
    this.trialBaslangic,
    required this.trialGunSayisi,
  });

  factory KullaniciProfil.fromJson(Map<String, dynamic> json) =>
      KullaniciProfil(
        id: json['id'],
        email: json['email'] ?? '',
        rol: json['rol'] ?? 'kullanici',
        isletmeAdi: json['isletme_adi'],
        isPremium: json['is_premium'] ?? false,
        trialBaslangic: json['trial_baslangic'] != null
            ? DateTime.parse(json['trial_baslangic'])
            : null,
        trialGunSayisi: json['trial_gun_sayisi'] ?? 14,
      );

  bool get trialSuresiDoldu {
    if (isPremium) return false;
    if (trialBaslangic == null) return false;
    final bitis = trialBaslangic!.add(Duration(days: trialGunSayisi));
    return DateTime.now().isAfter(bitis);
  }

  int get kalanTrialGun {
    if (isPremium) return 999;
    if (trialBaslangic == null) return trialGunSayisi;
    final bitis = trialBaslangic!.add(Duration(days: trialGunSayisi));
    final kalan = bitis.difference(DateTime.now()).inDays;
    return kalan < 0 ? 0 : kalan;
  }
}

/// Oturum yönetimi provider'ı.
class AuthProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  late final StreamSubscription<AuthState> _authSub;
  bool _disposed = false;

  Session? _session;
  KullaniciProfil? _profil;
  bool _yukleniyor = false;
  String? _hata;

  /// Çıkış işlemi devam ediyorsa true.
  bool _cikisYapiliyor = false;

  /// OTP ile şifre sıfırlama oturumunda ise true (eski şifre doğrulaması atlanır).
  bool _sifirlamaOturumu = false;
  bool get sifirlamaOturumu => _sifirlamaOturumu;

  /// Provider başlatıldığı an — email doğrulama bildirimini yalnızca bu andan
  /// sonra onaylananlar için göstermek amacıyla kullanılır.
  final DateTime _baslangicZamani = DateTime.now();

  // Kayıt durumu
  bool _kayitBasarili = false;
  bool get kayitBasarili => _kayitBasarili;

  /// E-posta doğrulama link'i tıklanıp giriş yapıldıysa true (bir kez).
  bool _emailDogrulandiBildir = false;
  bool get emailDogrulandiBildir => _emailDogrulandiBildir;
  void emailDogrulandiGoruldu() {
    _emailDogrulandiBildir = false;
    // notifyListeners gerekmez — sadece flag sıfırlanıyor
  }

  Session? get session => _session;
  KullaniciProfil? get profil => _profil;
  bool get yukleniyor => _yukleniyor;
  String? get hata => _hata;
  bool get girisYapildi => _session != null;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  AuthProvider() {
    _session = _client.auth.currentSession;
    if (_session != null) _profilYukle();

    _authSub = _client.auth.onAuthStateChange.listen((data) {
      final oncekiSession = _session;
      _session = data.session;

      if (_session == null) {
        _profil = null;
      } else if (oncekiSession?.user.id != _session!.user.id) {
        _profil = null;
        _profilYukle();
      }

      // E-posta doğrulama bildirimi — yalnızca bu oturumda TAZEce doğrulandıysa
      // (emailConfirmedAt provider başladıktan sonra ise = yeni onay)
      final confirmedAtStr = _session?.user.emailConfirmedAt;
      final confirmedAt = confirmedAtStr != null
          ? DateTime.tryParse(confirmedAtStr)
          : null;
      if (data.event == AuthChangeEvent.signedIn &&
          oncekiSession == null &&
          _session != null &&
          confirmedAt != null &&
          confirmedAt.isAfter(_baslangicZamani)) {
        _emailDogrulandiBildir = true;
      }

      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _profilYukle() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;
      final response = await _client
          .from('kullanicilar')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (response != null) {
        _profil = KullaniciProfil.fromJson(response);
        notifyListeners();
      }
    } catch (_) {
      // profil yüklenemese app devam eder
    }
  }

  /// E-posta ve şifre ile giriş yap. Hata varsa Türkçe mesaj döner, null → başarılı.
  Future<String?> girisYap(String email, String sifre) async {
    if (_cikisYapiliyor) {
      for (var i = 0; i < 20 && _cikisYapiliyor; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    _yukleniyor = true;
    _hata = null;
    _kayitBasarili = false;
    notifyListeners();
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: sifre,
      );
      return null;
    } on AuthException catch (e) {
      _hata = _tercumeHata(e.message);
      return _hata;
    } catch (_) {
      _hata = 'Bağlantı hatası. Lütfen tekrar deneyin.';
      return _hata;
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Yeni hesap oluştur. Null döner = başarılı (doğrulama e-postası gönderildi).
  Future<String?> kayitOl({
    required String email,
    required String sifre,
    required String isletmeAdi,
  }) async {
    _yukleniyor = true;
    _hata = null;
    _kayitBasarili = false;
    notifyListeners();
    try {
      await _client.auth.signUp(
        email: email.trim(),
        password: sifre,
        data: {'isletme_adi': isletmeAdi.trim()},
      );
      _kayitBasarili = true;
      return null;
    } on AuthException catch (e) {
      _hata = _tercumeHataKayit(e.message);
      return _hata;
    } catch (_) {
      _hata = 'Bağlantı hatası. Lütfen tekrar deneyin.';
      return _hata;
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  Future<void> cikisYap() async {
    _cikisYapiliyor = true;
    try {
      _client.removeAllChannels();
      await _client.auth.signOut();
      _yukleniyor = false;
      _hata = null;
      _kayitBasarili = false;
    } catch (_) {
      _session = null;
      _profil = null;
      notifyListeners();
    } finally {
      _cikisYapiliyor = false;
    }
  }

  /// Şifremi unuttum — e-postaya 6 haneli OTP kodu gönder.
  /// Null döner = başarılı, string döner = hata mesajı.
  Future<String?> sifremiUnuttumOtpGonder(String email) async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: false,
      );
      return null;
    } on AuthException catch (e) {
      return _tercumeHata(e.message);
    } catch (_) {
      return 'Bağlantı hatası. Lütfen tekrar deneyin.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// OTP kodunu doğrula ve oturumu başlat.
  /// Başarılı olursa sifirlamaOturumu = true olur (eski şifre doğrulaması atlanır).
  /// Null döner = başarılı, string döner = hata mesajı.
  Future<String?> sifremiUnuttumOtpDogrula(String email, String token) async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.email,
      );
      _sifirlamaOturumu = true;
      return null;
    } on AuthException catch (e) {
      return _tercumeHata(e.message);
    } catch (_) {
      return 'Bağlantı hatası. Lütfen tekrar deneyin.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Oturumdaki kullanıcının şifresini değiştir.
  /// OTP şıfırlama oturumunda eski şifre doğrulaması atlanır.
  /// Null döner = başarılı, string döner = hata mesajı.
  Future<String?> sifreDegistir(String eskiSifre, String yeniSifre) async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();

    if (!_sifirlamaOturumu) {
      // Normal akış: eski şifreyle yeniden doğrula
      try {
        final email = _client.auth.currentUser?.email;
        if (email == null) {
          _yukleniyor = false;
          notifyListeners();
          return 'Kullanıcı oturumu bulunamadı.';
        }
        await _client.auth.signInWithPassword(
          email: email,
          password: eskiSifre,
        );
      } on AuthException {
        _yukleniyor = false;
        notifyListeners();
        return 'Mevcut şifre hatalı.';
      } catch (_) {
        _yukleniyor = false;
        notifyListeners();
        return 'Bağlantı hatası. Lütfen tekrar deneyin.';
      }
    }

    // Yeni şifreyi kaydet
    try {
      await _client.auth.updateUser(UserAttributes(password: yeniSifre));
      _sifirlamaOturumu = false;
      return null;
    } on AuthException catch (e) {
      return _tercumeHata(e.message);
    } catch (_) {
      return 'Şifre değiştirilemedi. Lütfen tekrar deneyin.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  /// Kullanıcı profilini güncelle (e-posta).
  /// Null döner = başarılı.
  Future<String?> emailDegistir(String yeniEmail) async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();
    try {
      await _client.auth.updateUser(UserAttributes(email: yeniEmail.trim()));
      return null;
    } on AuthException catch (e) {
      return _tercumeHata(e.message);
    } catch (_) {
      return 'E-posta değiştirilemedi. Lütfen tekrar deneyin.';
    } finally {
      _yukleniyor = false;
      notifyListeners();
    }
  }

  String _tercumeHata(String msg) {
    if (msg.contains('Invalid login credentials')) {
      return 'E-posta veya şifre hatalı.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'E-posta adresiniz henüz doğrulanmamış. Lütfen gelen kutunuzu kontrol edin.';
    }
    if (msg.contains('Too many requests') ||
        msg.contains('rate limit') ||
        msg.contains('over_email_send_rate_limit') ||
        msg.contains('security purposes') ||
        msg.contains('only request this') ||
        msg.contains('Email rate limit')) {
      return 'E-posta gönderme limitine ulaşıldı. Saatte en fazla 3 e-posta gönderilebilir. Lütfen 1 saat sonra tekrar deneyin.';
    }
    if (msg.contains('unexpected_failure') || msg.contains('Error sending')) {
      return 'E-posta gönderilemedi. SMTP ayarlarınızı kontrol edin (Gmail için App Password gereklidir).';
    }
    if (msg.contains('Token has expired') ||
        msg.contains('token has expired') ||
        msg.contains('OTP') && msg.contains('invalid')) {
      return 'Kod geçersiz veya süresi dolmuş. Lütfen yeni bir kod isteyin.';
    }
    if (msg.contains('User not found') || msg.contains('user_not_found')) {
      return 'Bu e-posta adresiyle kayıtlı hesap bulunamadı.';
    }
    if (msg.contains('Signups not allowed') || msg.contains('otp_disabled') ||
        msg.contains('OTP disabled')) {
      return 'E-posta OTP devre dışı. Supabase Dashboard > Authentication > Email sekmesinde OTP\'yi etkinleştirin.';
    }
    return msg;
  }

  String _tercumeHataKayit(String msg) {
    if (msg.contains('User already registered') ||
        msg.contains('already been registered')) {
      return 'Bu e-posta adresi zaten kayıtlı.';
    }
    if (msg.contains('Password should be at least')) {
      return 'Şifre en az 6 karakter olmalıdır.';
    }
    if (msg.contains('Unable to validate email')) {
      return 'Geçersiz e-posta adresi.';
    }
    if (msg.contains('Too many requests')) {
      return 'Çok fazla deneme yapıldı. Lütfen bir süre bekleyin.';
    }
    return msg;
  }
}

