import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'logic/providers/auth_provider.dart';
import 'logic/providers/masa_provider.dart';
import 'logic/providers/oturum_provider.dart';
import 'logic/providers/urun_provider.dart';
import 'logic/providers/satis_provider.dart';
import 'logic/providers/muhasebe_provider.dart';
import 'logic/providers/kasa_provider.dart';
import 'logic/providers/ayarlar_provider.dart';
import 'logic/providers/rapor_provider.dart';
import 'ui/screens/ana_ekran.dart';
import 'ui/screens/auth/giris_ekrani.dart';

/// Global ScaffoldMessenger key — provider'lardan SnackBar göstermek için.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Uygulamanın kök widget'ı.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Consumer<AuthProvider>(
        builder: (_, auth, _)  {
          if (!auth.girisYapildi) {
            return MaterialApp(
              scaffoldMessengerKey: rootScaffoldMessengerKey,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: ThemeMode.system,
              locale: const Locale('tr', 'TR'),
              supportedLocales: const [Locale('tr', 'TR')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const GirisEkrani(),
            );
          }

          // Oturum açık — veri provider'larını yükle (key ile user değişince yeniden oluşturulur)
          return MultiProvider(
            key: ValueKey(auth.session!.user.id),
            providers: [
              ChangeNotifierProvider(create: (_) {
                final p = AyarlarProvider(userId: auth.session!.user.id);
                Future.microtask(p.baslat);
                return p;
              }),
              ChangeNotifierProvider(create: (_) {
                final p = MasaProvider();
                Future.microtask(p.masalariYukle);
                return p;
              }),
              ChangeNotifierProvider(create: (_) {
                final p = OturumProvider();
                Future.microtask(p.aktifOturumlariYukle);
                return p;
              }),
              ChangeNotifierProvider(create: (_) {
                final p = UrunProvider();
                Future.microtask(p.urunleriYukle);
                return p;
              }),
              ChangeNotifierProvider(create: (_) {
                final p = SatisProvider();
                Future.microtask(p.bugunSatislariYukle);
                return p;
              }),
              ChangeNotifierProvider(create: (_) {
                final p = MuhasebeProvider();
                Future.microtask(p.aylikKayitlariYukle);
                return p;
              }),
              ChangeNotifierProvider(create: (_) {
                final p = KasaProvider();
                Future.microtask(p.ayiYukle);
                return p;
              }),
              ChangeNotifierProvider(create: (_) {
                final p = RaporProvider();
                Future.microtask(p.raporlariYukle);
                return p;
              }),
            ],
            child: Selector<AyarlarProvider,
                ({ThemeMode temaMode, String isletmeAdi, bool hazir})>(
              selector: (_, a) => (
                temaMode: a.hazir ? a.temaMode : ThemeMode.light,
                isletmeAdi: a.hazir ? a.isletmeAdi : 'PlayLog',
                hazir: a.hazir,
              ),
              builder: (context, data, child) {
                return MaterialApp(
                  key: ValueKey(data.temaMode),
                  scaffoldMessengerKey: rootScaffoldMessengerKey,
                  title: data.isletmeAdi,
                  debugShowCheckedModeBanner: false,
                  themeAnimationDuration: Duration.zero,
                  theme: AppTheme.light,
                  darkTheme: AppTheme.dark,
                  themeMode: data.temaMode,
                  locale: const Locale('tr', 'TR'),
                  supportedLocales: const [Locale('tr', 'TR')],
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  home: child,
                );
              },
              child: const AnaEkran(),
            ),
          );
        },
      ),
    );
  }
}
