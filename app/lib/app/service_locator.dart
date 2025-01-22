import 'package:get_it/get_it.dart';
import 'package:lyria/app/core/services/http/dio_client.dart';
import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/core/services/storege/shared_preferences_client.dart';
import 'package:lyria/app/modules/auth/data/mongo_auth_repo.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_cubit.dart';

final getIt = GetIt.instance;

void setupLocator() {
  // Serviços
  getIt.registerSingleton<MyLocalStorage>(SharedPreferencesClient());
  getIt.registerSingleton<MyHttpClient>(
    DioClient(storage: getIt<MyLocalStorage>()),
  );

  // Repositórios
  getIt.registerLazySingleton(() => MongoAuthRepo(
        http: getIt<MyHttpClient>(),
        storage: getIt<MyLocalStorage>(),
      ));

  // Cubits
  getIt.registerSingleton<AuthCubit>(
    AuthCubit(authRepo: getIt<MongoAuthRepo>()),
  );
}
