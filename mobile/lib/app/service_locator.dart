import 'package:audio_service/audio_service.dart';
import 'package:get_it/get_it.dart';
import 'package:lyria/app/core/services/http/dio_client.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/core/services/storege/shared_preferences_client.dart';
import 'package:lyria/app/core/themes/theme_cubit.dart';
import 'package:lyria/app/modules/auth/data/api_auth_repo.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';
import 'package:lyria/app/modules/explorer/data/api_search_repo.dart';
import 'package:lyria/app/modules/explorer/presentation/cubits/search_cubit.dart';
import 'package:lyria/app/modules/music/presentation/cubits/music_cubit.dart';

final getIt = GetIt.instance;

Future<void> setupLocator(AudioHandler audioHandler) async {
  // Serviços
  getIt.registerSingleton<MyLocalStorage>(SharedPreferencesClient());
  getIt.registerSingleton<MyHttpClient>(
    DioClient(storage: getIt<MyLocalStorage>()),
  );
  getIt.registerSingleton<AudioHandler>(audioHandler);

  // Repositórios
  getIt.registerLazySingleton(() => ApiAuthRepo(
        http: getIt<MyHttpClient>(),
        storage: getIt<MyLocalStorage>(),
      ));
  getIt.registerLazySingleton(() => ApiSearchRepo(
        http: getIt<MyHttpClient>(),
        storage: getIt<MyLocalStorage>(),
      ));

  // Cubits
  getIt.registerSingleton<AuthCubit>(
    AuthCubit(authRepo: getIt<ApiAuthRepo>()),
  );
  getIt.registerSingleton<ThemeCubit>(
    ThemeCubit(),
  );
  getIt.registerSingleton<SearchCubit>(
    SearchCubit(searchRepo: getIt<ApiSearchRepo>()),
  );
  getIt.registerSingleton<MusicCubit>(
    MusicCubit(getIt<ThemeCubit>(), getIt<AudioHandler>()),
  );
}
