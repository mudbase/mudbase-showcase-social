import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/env_config.dart';
import 'auth_service.dart';
import 'mudbase_data_service.dart';
import 'mudbase_sdk_provider.dart';
import 'mudbase_socket_service.dart';
import 'secure_token_storage.dart';

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  return SecureTokenStorage();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(mudbaseSdkProvider), EnvConfig.mudbaseProjectId);
});

final mudbaseDataServiceProvider = Provider<MudbaseDataService>((ref) {
  return MudbaseDataService(
    ref.watch(mudbaseSdkProvider),
    EnvConfig.mudbaseProjectId,
  );
});

/// One shared socket connection for the whole app's lifetime - created once,
/// disposed only when the provider container itself is disposed (never, in
/// practice, since it's rooted at `ProviderScope`). `AuthController` drives
/// its connect/disconnect lifecycle alongside the session it manages.
final mudbaseSocketServiceProvider = Provider<MudbaseSocketService>((ref) {
  final service = MudbaseSocketService();
  ref.onDispose(service.disconnect);
  return service;
});
