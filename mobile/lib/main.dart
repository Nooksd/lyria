import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lyria/app/core/services/download/download_service.dart';
import 'package:lyria/app/core/services/http/dio_client.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/music/music_service.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/core/services/storege/shared_preferences_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/service_locator.dart';
import 'app/app_widget.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SharedPreferences.getInstance();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await Permission.notification.isDenied.then(
    (value) {
      if (value) {
        Permission.notification.request();
      }
    },
  );

  getIt.registerSingleton<MyLocalStorage>(SharedPreferencesClient());
  getIt.registerSingleton<MyHttpClient>(
    DioClient(storage: getIt<MyLocalStorage>()),
  );
  getIt.registerSingleton<DownloadService>(
      DownloadService(http: getIt<MyHttpClient>()));

  final audioHandler = await AudioService.init(
    builder: () => MusicService(
      storage: getIt<MyLocalStorage>(),
      downloadService: getIt<DownloadService>(),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.risadev.lyria.channel.audio',
      androidNotificationChannelName: 'music_player',
      androidNotificationIcon: 'drawable/ic_notification',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
      androidStopForegroundOnPause: true,
      notificationColor: Color(0xFF171717),
    ),
  );

  setupLocator(audioHandler);

  runApp(const AppWidget());
}
