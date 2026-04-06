import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../../../logic/providers/auth_provider.dart';
import 'kayit_ekrani.dart';

/// Kullanıcı giriş ekranı.
class GirisEkrani extends StatefulWidget {
  const GirisEkrani({super.key});

  @override
  State<GirisEkrani> createState() => _GirisEkraniState();
}

class _GirisEkraniState extends State<GirisEkrani> with WindowListener {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _sifreCtrl = TextEditingController();
  bool _sifreGizli = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    _emailCtrl.dispose();
    _sifreCtrl.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (!mounted) return;
    final karar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.exit_to_app, size: 40, color: Colors.orange),
        title: const Text('Çıkmak istiyor musunuz?'),
        content: const Text('Uygulamadan çıkmak istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet, Çık'),
          ),
        ],
      ),
    );
    if (karar == true) exit(0);
  }

  Future<void> _girisYap() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final hata = await auth.girisYap(_emailCtrl.text, _sifreCtrl.text);
    if (hata != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hata),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _sifremiUnuttum() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final otpCtrl = TextEditingController();
    bool otpGonderildi = false;
    String geriEmail = '';
    String? hataMetni;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            icon: Icon(
              otpGonderildi
                  ? Icons.mark_email_read_outlined
                  : Icons.lock_reset,
              size: 44,
              color: Colors.blue,
            ),
            title: Text(otpGonderildi ? 'Kodu Girin' : 'Şifremi Unuttum'),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!otpGonderildi) ...[
                    const Text(
                      'E-posta adresinize doğrulama kodu '
                      'göndereceğiz. Kodu girerek giriş yapabilir, '
                      'ardından Ayarlar\'dan şifrenizi değiştirebilirsiniz.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-posta',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    Text(
                      '$geriEmail adresine doğrulama kodu gönderildi.\n'
                      'Gelen kutunuzu kontrol edip kodu giriniz.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: otpCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'Doğrulama Kodu',
                        prefixIcon: Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () => setDlgState(() {
                        otpGonderildi = false;
                        hataMetni = null;
                        otpCtrl.clear();
                      }),
                      icon: const Icon(Icons.arrow_back, size: 16),
                      label: const Text('E-postayı düzenle'),
                    ),
                  ],
                  if (hataMetni != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      hataMetni!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal'),
              ),
              FilledButton(
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  if (!otpGonderildi) {
                    final email = emailCtrl.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      setDlgState(
                          () => hataMetni = 'Geçerli bir e-posta giriniz.');
                      return;
                    }
                    setDlgState(() => hataMetni = null);
                    final hata = await auth.sifremiUnuttumOtpGonder(email);
                    if (!ctx.mounted) return;
                    if (hata != null) {
                      setDlgState(() => hataMetni = hata);
                    } else {
                      geriEmail = email;
                      setDlgState(() => otpGonderildi = true);
                    }
                  } else {
                    final kod = otpCtrl.text.trim();
                    if (kod.isEmpty) {
                      setDlgState(() =>
                          hataMetni = 'Lütfen kodu giriniz.');
                      return;
                    }
                    setDlgState(() => hataMetni = null);
                    final hata =
                        await auth.sifremiUnuttumOtpDogrula(geriEmail, kod);
                    if (!ctx.mounted) return;
                    if (hata != null) {
                      setDlgState(() => hataMetni = hata);
                    } else {
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Giriş yapıldı! Ayarlar > Şifre Değiştir\'den '
                            'yeni şifrenizi belirleyebilirsiniz.',
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 6),
                        ),
                      );
                    }
                  }
                },
                child: Text(otpGonderildi ? 'Doğrula ve Giriş Yap' : 'Kod Gönder'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final yukleniyor = context.select<AuthProvider, bool>((a) => a.yukleniyor);

    // E-posta doğrulama bildirimi — kull. doğrulama link'ine tıkladıktan sonra
    final emailDogrulandi = context.select<AuthProvider, bool>(
      (a) => a.emailDogrulandiBildir,
    );
    if (emailDogrulandi) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AuthProvider>().emailDogrulandiGoruldu();
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            icon: const Icon(
              Icons.verified_user,
              size: 48,
              color: Colors.green,
            ),
            title: const Text('E-posta Doğrulandı!'),
            content: const Text(
              'Hesabınız başarıyla doğrulandı. Artık giriş yapabilirsiniz.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam'),
              ),
            ],
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                _Logo(),
                const SizedBox(height: 40),

                // Kart
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Giriş Yap',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 24),

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
                              if (!v.contains('@')) {
                                return 'Geçerli bir e-posta giriniz';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Şifre
                          TextFormField(
                            controller: _sifreCtrl,
                            obscureText: _sifreGizli,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _girisYap(),
                            decoration: InputDecoration(
                              labelText: 'Şifre',
                              prefixIcon: const Icon(Icons.lock_outlined),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _sifreGizli
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                onPressed: () =>
                                    setState(() => _sifreGizli = !_sifreGizli),
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
                          const SizedBox(height: 28),

                          // Giriş butonu
                          FilledButton(
                            onPressed: yukleniyor ? null : _girisYap,
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
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Giriş Yap',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                          const SizedBox(height: 8),

                          // Şifremi unuttum
                          Center(
                            child: TextButton(
                              onPressed: _sifremiUnuttum,
                              child: const Text('Şifremi Unuttum'),
                            ),
                          ),

                          // Kayıt ol linki
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const KayitEkrani(),
                                ),
                              ),
                              child: const Text('Hesabın yok mu? Kayıt Ol'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Text(
                  'PlayLog v1.0',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colorScheme.outline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Logo dosyası varsa göster, yoksa ikon ile yedek
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            'assets/images/logo.png',
            width: 140,
            height: 140,
            errorBuilder: (_, _, _) => Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.sports_esports,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'PlayLog',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Salon Yönetim Sistemi',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}
