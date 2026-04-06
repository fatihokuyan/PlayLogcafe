import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/supabase_constants.dart';

import 'app.dart';
import 'logic/services/realtime_service.dart';

Future<void> main() async {
  debugPrint('Başlangıç: main fonksiyonu');
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('Başlangıç: initializeDateFormatting');
  await initializeDateFormatting('tr_TR', null);
  debugPrint('Bitti: initializeDateFormatting');

  // Mobilde (Android/iOS) yatay kullanıma zorla, masaüstünde serbest bırak
  if (Platform.isAndroid || Platform.isIOS) {
    debugPrint('Başlangıç: SystemChrome.setPreferredOrientations');
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    debugPrint('Bitti: SystemChrome.setPreferredOrientations');
  }

  // Masaüstü: pencere kapatma butonu için onay dialogu + ikon
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    debugPrint('Başlangıç: windowManager.ensureInitialized');
    await windowManager.ensureInitialized();
    debugPrint('Bitti: windowManager.ensureInitialized');
    debugPrint('Başlangıç: windowManager.setPreventClose');
    await windowManager.setPreventClose(true);
    debugPrint('Bitti: windowManager.setPreventClose');
    debugPrint('Başlangıç: windowManager.setIcon');
    await windowManager.setIcon('assets/images/logo.png');
    debugPrint('Bitti: windowManager.setIcon');
  }

  debugPrint('Başlangıç: Supabase.initialize');
  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );
  debugPrint('Bitti: Supabase.initialize');

  // Sadece kullanıcı login ise realtime dinlemeyi başlat
  if (Supabase.instance.client.auth.currentUser != null) {
    debugPrint('Başlangıç: RealtimeService.listenAll');
    RealtimeService().listenAll(
      onChange: (table, data) {
        debugPrint('Realtime değişiklik: $table -> $data');
        // Burada ilgili state yönetimi ile arayüzü güncelleyebilirsin
      },
    );
    debugPrint('Bitti: RealtimeService.listenAll');
  }

  debugPrint('runApp başlatılıyor');
  runApp(const MyApp());
}
