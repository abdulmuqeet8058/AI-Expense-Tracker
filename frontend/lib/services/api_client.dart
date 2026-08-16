import 'package:dio/dio.dart';

import '../config.dart';
import '../models/user.dart';
import 'auth_storage.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class AuthResult {
  final String accessToken;
  final String refreshToken;
  final User user;

  AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['access_token'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
        user: User.fromJson(
          (json['user'] as Map<String, dynamic>?) ?? const {},
        ),
      );
}

class ApiClient {
  final Dio _dio;
  final AuthStorage _storage;

  ApiClient({AuthStorage? storage, Dio? dio})
      : _storage = storage ?? AuthStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: kBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {'Content-Type': 'application/json'},
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _storage.clear();
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<AuthResult> register({
    required String email,
    required String password,
    required String fullName,
    String currency = 'PKR',
  }) async {
    final response = await _post('/auth/register', {
      'email': email,
      'password': password,
      'full_name': fullName,
      'currency': currency,
    });
    return AuthResult.fromJson(_map(response.data));
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _post('/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(_map(response.data));
  }

  Future<User> getMe() async {
    final response = await _get('/auth/me');
    return User.fromJson(_map(response.data));
  }

  Future<void> logout() async {
    try {
      await _post('/auth/logout', const {});
    } on ApiException {
      // Logout is completed locally even if the backend is unavailable.
    }
  }

  Future<Response<dynamic>> _get(String path) async {
    try {
      return await _dio.get(path);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Response<dynamic>> _post(String path, dynamic body) async {
    try {
      return await _dio.post(path, data: body);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  ApiException _toApiException(DioException error) {
    final data = error.response?.data;
    if (data is Map && data['detail'] != null) {
      final detail = data['detail'];
      if (detail is List) {
        final message = detail
            .map((item) => item is Map
                ? (item['msg'] ?? item).toString()
                : item.toString())
            .join(', ');
        return ApiException(message, statusCode: error.response?.statusCode);
      }
      return ApiException(
        detail.toString(),
        statusCode: error.response?.statusCode,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return ApiException('Cannot reach the server. Check your connection.');
    }
    return ApiException(
      error.message ?? 'Something went wrong',
      statusCode: error.response?.statusCode,
    );
  }
}

Map<String, dynamic> _map(dynamic data) =>
    data is Map<String, dynamic> ? data : <String, dynamic>{};
