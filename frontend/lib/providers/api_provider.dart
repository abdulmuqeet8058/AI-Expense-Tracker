import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/auth_storage.dart';
import '../services/local_cache.dart';

/// One AuthStorage instance shared by the ApiClient and the auth notifier so
/// the token they read/write is always the same.
final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(authStorageProvider));
});

final localCacheProvider = Provider<LocalCache>((ref) => LocalCache());
