import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../logic/providers/auth_provider.dart';

/// Yeni hesap oluşturma ekranı.
class KayitEkrani extends StatefulWidget {
  const KayitEkrani({super.key});

  @override
  State<KayitEkrani> createState() => _KayitEkraniState();
}

class _KayitEkraniState extends State<KayitEkrani> {
  final _formKey = GlobalKey<FormState>();
  final _isletmeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sifreCtrl = TextEditingController();
  final _sifreTekrarCtrl = TextEditingController();
  bool _sifreGizli = true;
  bool _sifreTekrarGizli = true;

  @override
  void dispose() {
    _isletmeCtrl.dispose();
    _emailCtrl.dispose();
    _sifreCtrl.dispose();
    _sifreTekrarCtrl.dispose();
    super.dispose();
  }

  Future<void> _kayitOl() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final hata = await auth.kayitOl(
      email: _emailCtrl.text,
      sifre: _sifreCtrl.text,
      isletmeAdi: _isletmeCtrl.text,
    );
    if (!mounted) return;
    if (hata != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hata),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } else {
      // Kayıt başarılı — mailin doğrulanmasını anlatan ekran
      _basariEkraniniGoster();
    }
  }

  void _basariEkraniniGoster() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.mark_email_read_outlined,
            size: 48, color: Colors.green),
        title: const Text('Kayıt Tamamlandı!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hesabınız oluşturuldu. Giriş yapabilmek için e-posta adresinize gönderilen doğrulama linkine tıklayın.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _emailCtrl.text.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Spam klasörünü de kontrol etmeyi unutmayın.',
              style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.outline,
                  ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Giriş ekranına geri dön
            },
            child: const Text('Giriş Ekranına Git'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final yukleniyor =
        context.select<AuthProvider, bool>((a) => a.yukleniyor);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 110,
                    height: 110,
                    errorBuilder: (_, _, _) => Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.sports_esports,
                          size: 64, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'PlayLog',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 28),

                // Kart
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Yeni Hesap Oluştur',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 20),

                          // İşletme adı
                          TextFormField(
                            controller: _isletmeCtrl,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'İşletme / Salon Adı',
                              prefixIcon: Icon(Icons.store_outlined),
                              hintText: 'Örn: Galaxy Gaming Cafe',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'İşletme adı giriniz';
                              }
                              if (v.trim().length < 2) {
                                return 'En az 2 karakter olmalıdır';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // E-posta
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'E-posta',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'E-posta giriniz';
                              }
                              if (!v.contains('@') || !v.contains('.')) {
                                return 'Geçerli bir e-posta giriniz';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Şifre
                          TextFormField(
                            controller: _sifreCtrl,
                            obscureText: _sifreGizli,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(_sifreGizli
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                    () => _sifreGizli = !_sifreGizli),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Şifre giriniz';
                              }
                              if (v.length < 6) {
                                return 'Şifre en az 6 karakter olmalıdır';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Şifre tekrar
                          TextFormField(
                            controller: _sifreTekrarCtrl,
                            obscureText: _sifreTekrarGizli,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _kayitOl(),
                            decoration: InputDecoration(
                              labelText: 'Şifre Tekrar',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_sifreTekrarGizli
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() =>
                                    _sifreTekrarGizli = !_sifreTekrarGizli),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Şifreyi tekrar giriniz';
                              }
                              if (v != _sifreCtrl.text) {
                                return 'Şifreler eşleşmiyor';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Kayıt ol butonu
                          FilledButton(
                            onPressed: yukleniyor ? null : _kayitOl,
                            style: FilledButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: yukleniyor
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white),
                                  )
                                : const Text('Hesap Oluştur',
                                    style: TextStyle(fontSize: 16)),
                          ),
                          const SizedBox(height: 16),

                          // Giriş ekranına dön
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Zaten hesabım var → Giriş Yap'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                Text(
                  'Hesap oluşturduktan sonra e-postanızdaki\ndoğrulama linkine tıklamanız gerekmektedir.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
