import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'constants.dart';

enum DjangoApiErrorType {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  rateLimited,
  server,
  validation,
  unknown,
}

class DjangoApiException implements Exception {
  final String message;
  final int? statusCode;
  final DjangoApiErrorType type;
  final dynamic data;

  const DjangoApiException({
    required this.message,
    required this.type,
    this.statusCode,
    this.data,
  });

  bool get isUnauthorized => type == DjangoApiErrorType.unauthorized;
  bool get isNetwork => type == DjangoApiErrorType.network || type == DjangoApiErrorType.timeout;

  @override
  String toString() => 'DjangoApiException(statusCode: $statusCode, type: $type, message: $message)';
}

class DjangoApiClient {
  DjangoApiClient._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            headers: const {'Accept': 'application/json'},
          ),
        );

  static final DjangoApiClient _instance = DjangoApiClient._internal();
  factory DjangoApiClient() => _instance;

  final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const int _maxRetries = 2;
  static const List<int> _retryBackoffMs = [250, 500];

  Future<bool>? _refreshFuture;
  bool _interceptorsInitialized = false;

  void _initInterceptorsIfNeeded() {
    if (_interceptorsInitialized) return;
    _interceptorsInitialized = true;

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_requiresAuth(options) && (options.headers['Authorization'] == null)) {
            final token = await _storage.read(key: _accessTokenKey);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (err, handler) async {
          if (_shouldAttemptTokenRefresh(err)) {
            final refreshed = await _refreshAccessToken();
            if (refreshed) {
              try {
                final retried = await _retryWithFreshToken(err.requestOptions);
                handler.resolve(retried);
                return;
              } catch (_) {
                // Fall through and reject original request; outer layer maps error.
              }
            } else {
              await clearAuthTokens();
            }
          }
          handler.next(err);
        },
      ),
    );
  }

  Future<void> saveAuthTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearAuthTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool retryEnabled = true,
    CancelToken? cancelToken,
  }) {
    return _request(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      retryEnabled: retryEnabled,
      cancelToken: cancelToken,
    );
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool retryEnabled = false,
    CancelToken? cancelToken,
  }) {
    return _request(
      method: 'POST',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      retryEnabled: retryEnabled,
      cancelToken: cancelToken,
    );
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool retryEnabled = false,
    CancelToken? cancelToken,
  }) {
    return _request(
      method: 'PUT',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      retryEnabled: retryEnabled,
      cancelToken: cancelToken,
    );
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool retryEnabled = false,
    CancelToken? cancelToken,
  }) {
    return _request(
      method: 'PATCH',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      retryEnabled: retryEnabled,
      cancelToken: cancelToken,
    );
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool retryEnabled = false,
    CancelToken? cancelToken,
  }) {
    return _request(
      method: 'DELETE',
      path: path,
      data: data,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      retryEnabled: retryEnabled,
      cancelToken: cancelToken,
    );
  }

  Future<dynamic> postFormData(
    String path, {
    required FormData formData,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool retryEnabled = false,
    CancelToken? cancelToken,
  }) {
    return _request(
      method: 'POST',
      path: path,
      data: formData,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
      retryEnabled: retryEnabled,
      cancelToken: cancelToken,
      options: Options(contentType: Headers.multipartFormDataContentType),
    );
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    dynamic data,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
    bool retryEnabled = true,
    CancelToken? cancelToken,
    Options? options,
  }) async {
    _initInterceptorsIfNeeded();

    int attempt = 0;
    while (true) {
      try {
        final mergedExtra = <String, dynamic>{
          ...?options?.extra,
          'requiresAuth': requiresAuth,
          'retryEnabled': retryEnabled,
        };

        final requestOptions = (options ?? Options()).copyWith(
          method: method,
          extra: mergedExtra,
        );

        final response = await _dio.request<dynamic>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: requestOptions,
          cancelToken: cancelToken,
        );

        return response.data;
      } on DioException catch (e) {
        if (_shouldRetry(e, method, attempt, retryEnabled)) {
          final backoffMs = _retryBackoffMs[attempt.clamp(0, _retryBackoffMs.length - 1)];
          await Future.delayed(Duration(milliseconds: backoffMs));
          attempt += 1;
          continue;
        }
        throw _toApiException(e);
      }
    }
  }

  bool _requiresAuth(RequestOptions options) => options.extra['requiresAuth'] != false;

  bool _shouldAttemptTokenRefresh(DioException err) {
    final status = err.response?.statusCode;
    if (status != 401) return false;

    final options = err.requestOptions;
    if (!_requiresAuth(options)) return false;
    if (options.extra['skipTokenRefresh'] == true) return false;
    if (options.extra['__retried_after_refresh'] == true) return false;

    final path = options.path;
    if (path.contains('auth/login/') || path.contains('auth/refresh/')) return false;
    return true;
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshFuture != null) return _refreshFuture!;

    final completer = Completer<bool>();
    _refreshFuture = completer.future;

    try {
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(false);
        return false;
      }

      final response = await _dio.post<dynamic>(
        'auth/refresh/',
        data: {'refresh': refreshToken},
        options: Options(
          extra: const {
            'requiresAuth': false,
            'skipTokenRefresh': true,
            'retryEnabled': false,
          },
        ),
      );

      final data = response.data;
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        final newAccess = data['access']?.toString();
        final newRefresh = data['refresh']?.toString();

        if (newAccess != null && newAccess.isNotEmpty) {
          await _storage.write(key: _accessTokenKey, value: newAccess);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            await _storage.write(key: _refreshTokenKey, value: newRefresh);
          }
          completer.complete(true);
          return true;
        }
      }

      await clearAuthTokens();
      completer.complete(false);
      return false;
    } catch (_) {
      await clearAuthTokens();
      completer.complete(false);
      return false;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<Response<dynamic>> _retryWithFreshToken(RequestOptions original) async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final headers = Map<String, dynamic>.from(original.headers);
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final options = Options(
      method: original.method,
      headers: headers,
      responseType: original.responseType,
      contentType: original.contentType,
      receiveDataWhenStatusError: original.receiveDataWhenStatusError,
      followRedirects: original.followRedirects,
      validateStatus: original.validateStatus,
      sendTimeout: original.sendTimeout,
      receiveTimeout: original.receiveTimeout,
      extra: <String, dynamic>{
        ...original.extra,
        '__retried_after_refresh': true,
      },
    );

    return _dio.request<dynamic>(
      original.path,
      data: original.data,
      queryParameters: original.queryParameters,
      options: options,
      cancelToken: original.cancelToken,
      onReceiveProgress: original.onReceiveProgress,
      onSendProgress: original.onSendProgress,
    );
  }

  bool _shouldRetry(DioException error, String method, int attempt, bool retryEnabled) {
    if (!retryEnabled || !_isIdempotent(method) || attempt >= _maxRetries) return false;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        return status == HttpStatus.requestTimeout ||
            status == HttpStatus.tooManyRequests ||
            status == HttpStatus.badGateway ||
            status == HttpStatus.serviceUnavailable ||
            status == HttpStatus.gatewayTimeout;
      default:
        return false;
    }
  }

  bool _isIdempotent(String method) {
    final upper = method.toUpperCase();
    return upper == 'GET' || upper == 'HEAD' || upper == 'OPTIONS';
  }

  DjangoApiException _toApiException(DioException error) {
    final status = error.response?.statusCode;
    final data = error.response?.data;
    final message = _extractMessage(data, status, fallback: error.message);

    final type = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        DjangoApiErrorType.timeout,
      DioExceptionType.connectionError => DjangoApiErrorType.network,
      DioExceptionType.badResponse => _mapStatusCodeToErrorType(status),
      _ => _mapStatusCodeToErrorType(status),
    };

    return DjangoApiException(
      message: message,
      statusCode: status,
      type: type,
      data: data,
    );
  }

  DjangoApiErrorType _mapStatusCodeToErrorType(int? statusCode) {
    if (statusCode == null) return DjangoApiErrorType.unknown;
    if (statusCode == HttpStatus.unauthorized) return DjangoApiErrorType.unauthorized;
    if (statusCode == HttpStatus.forbidden) return DjangoApiErrorType.forbidden;
    if (statusCode == HttpStatus.notFound) return DjangoApiErrorType.notFound;
    if (statusCode == HttpStatus.tooManyRequests) return DjangoApiErrorType.rateLimited;
    if (statusCode >= 500) return DjangoApiErrorType.server;
    if (statusCode >= 400 && statusCode < 500) return DjangoApiErrorType.validation;
    return DjangoApiErrorType.unknown;
  }

  String _extractMessage(dynamic data, int? statusCode, {String? fallback}) {
    if (data is Map<String, dynamic>) {
      final nonField = data['non_field_errors'];
      if (nonField is List && nonField.isNotEmpty) return nonField.first.toString();
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
      final error = data['error'];
      if (error is String && error.trim().isNotEmpty) return error;
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    } else if (data is List && data.isNotEmpty) {
      return data.first.toString();
    } else if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    if (statusCode == HttpStatus.unauthorized) return 'Session expired. Please sign in again.';
    if (statusCode == HttpStatus.forbidden) return 'You do not have permission to do this.';
    if (statusCode == HttpStatus.notFound) return 'Requested resource was not found.';
    if (statusCode == HttpStatus.tooManyRequests) return 'Too many requests. Please wait and try again.';
    if (statusCode != null && statusCode >= 500) return 'Server error. Please try again shortly.';

    return fallback ?? 'Request failed. Please try again.';
  }
}

