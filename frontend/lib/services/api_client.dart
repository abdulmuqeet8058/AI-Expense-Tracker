import 'package:dio/dio.dart';

import '../config.dart';
import '../models/expense.dart';
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

  Future<List<Expense>> getExpenses({
    String? category,
    DateTime? start,
    DateTime? end,
    String? search,
    bool? isIncome,
    int? limit,
    int? skip,
    String? sort,
  }) async {
    final query = <String, dynamic>{};
    if (category != null) query['category'] = category;
    if (start != null) query['start'] = start.toUtc().toIso8601String();
    if (end != null) query['end'] = end.toUtc().toIso8601String();
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (isIncome != null) query['is_income'] = isIncome;
    if (limit != null) query['limit'] = limit;
    if (skip != null) query['skip'] = skip;
    if (sort != null) query['sort'] = sort;

    final response = await _get('/expenses/', query: query);
    return _list(response.data).map(Expense.fromJson).toList();
  }

  Future<Expense> createExpense({
    required double amount,
    required String description,
    String? category,
    String? subCategory,
    DateTime? date,
    String paymentMethod = 'cash',
    Location? location,
    String? receiptUrl,
    bool isIncome = false,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'description': description,
      'payment_method': paymentMethod,
      'is_income': isIncome,
    };
    if (category != null) body['category'] = category;
    if (subCategory != null) body['sub_category'] = subCategory;
    if (date != null) body['date'] = date.toUtc().toIso8601String();
    if (location != null) body['location'] = location.toJson();
    if (receiptUrl != null) body['receipt_url'] = receiptUrl;

    final response = await _post('/expenses/', body);
    return Expense.fromJson(_map(response.data));
  }

  Future<Expense> updateExpense(
    String id, {
    double? amount,
    String? description,
    String? category,
    String? subCategory,
    DateTime? date,
    String? paymentMethod,
    Location? location,
    String? receiptUrl,
    bool? isIncome,
  }) async {
    final body = <String, dynamic>{};
    if (amount != null) body['amount'] = amount;
    if (description != null) body['description'] = description;
    if (category != null) body['category'] = category;
    if (subCategory != null) body['sub_category'] = subCategory;
    if (date != null) body['date'] = date.toUtc().toIso8601String();
    if (paymentMethod != null) body['payment_method'] = paymentMethod;
    if (location != null) body['location'] = location.toJson();
    if (receiptUrl != null) body['receipt_url'] = receiptUrl;
    if (isIncome != null) body['is_income'] = isIncome;

    final response = await _put('/expenses/$id', body);
    return Expense.fromJson(_map(response.data));
  }

  Future<bool> deleteExpense(String id) async {
    final response = await _delete('/expenses/$id');
    final data = response.data;
    if (data is Map && data['deleted'] != null) return data['deleted'] == true;
    return true;
  }

  Future<List<String>> getExpenseCategories() async {
    final response = await _get('/expenses/categories');
    final data = response.data;
    if (data is List) return data.map((item) => item.toString()).toList();
    return List<String>.from(kCategories);
  }

  Future<Map<String, dynamic>> getCategorySummary(String category) async {
    final response = await _get('/expenses/summary/$category');
    return _map(response.data);
  }

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _dio.get(path, queryParameters: query);
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

  Future<Response<dynamic>> _put(String path, dynamic body) async {
    try {
      return await _dio.put(path, data: body);
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  Future<Response<dynamic>> _delete(String path) async {
    try {
      return await _dio.delete(path);
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

List<Map<String, dynamic>> _list(dynamic data) =>
    (data is List ? data : const []).whereType<Map<String, dynamic>>().toList();
