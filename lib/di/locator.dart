import 'package:get_it/get_it.dart';

import '../core/network/api_client.dart';
import '../config/api.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/logout_usecase.dart';
import '../domain/usecases/get_profile_usecase.dart';
import '../domain/usecases/register_user_usecase.dart';
import '../domain/usecases/update_profile_usecase.dart';
import '../data/datasources/local_data_source.dart';
import '../data/datasources/remote_data_source.dart';
import '../domain/repositories/auth_repository.dart';
import '../data/repositories/auth_repository_impl.dart';

final GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  // Core / low level
  locator.registerLazySingleton<ApiClient>(() => ApiClient(baseUrl: baseUrl));

  // Data sources
  locator.registerLazySingleton<RemoteDataSource>(() => RemoteDataSourceImpl(client: locator()));
  locator.registerLazySingleton<LocalDataSource>(() => SharedPrefsLocalDataSource());

  // Repositories
  locator.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(remote: locator(), local: locator()));

  // Usecases (domain)
  locator.registerLazySingleton<LoginUseCase>(() => LoginUseCase(locator()));
  locator.registerLazySingleton<LogoutUseCase>(() => LogoutUseCase(locator()));
  locator.registerLazySingleton<GetProfileUseCase>(() => GetProfileUseCase(locator()));
  locator.registerLazySingleton<RegisterUserUseCase>(() => RegisterUserUseCase(locator()));
  locator.registerLazySingleton<UpdateProfileUseCase>(() => UpdateProfileUseCase(locator()));
}
