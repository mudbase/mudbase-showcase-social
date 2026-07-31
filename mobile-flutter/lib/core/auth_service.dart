import 'package:built_value/serializer.dart';
import 'package:dio/dio.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';

import 'mudbase_exception.dart';

/// Auth calls against the real Mudbase project/Multi-Role feature. Ported
/// from the sibling ecommerce Flutter app's `core/auth_service.dart` -
/// same reasoning, same bypass of the generated wrapper classes:
///
/// 1. `MultiRoleFeatureApi.registerWithRole` (`POST
///    /api/auth/local/signup/{role}`) is typed to return `void` in the
///    bundled OpenAPI spec even though the live endpoint returns a JSON body
///    with `token`/`refreshToken`/`user` - see
///    `mudbase-sdk/dart/lib/src/api/multi_role_feature_api.dart`. There is
///    no typed response to deserialize into.
/// 2. Every response model the SDK *does* type for auth
///    (`LoginLocalUser200Response`, `CreateAnonymousSession200Response`,
///    `User`, ...) declares `role` but not `customRole`/`isAnonymous`.
///    built_value's standard JSON deserializer silently drops unknown
///    fields rather than erroring, so calling through the typed wrapper
///    would silently lose exactly the field this app gates every write on.
///
/// Request bodies still use the SDK's real generated builder classes
/// (`RegisterWithRoleRequest`, `LoginLocalUserRequest`) and its own
/// `Serializers` to produce the wire payload, so the request shape is
/// guaranteed to match what the generated code would have sent - only the
/// response side is handled manually.
class AuthService {
  const AuthService(this._sdk, this._projectId);

  final MudbaseSdk _sdk;
  final String _projectId;

  Future<Map<String, dynamic>> registerWithRole({
    required String role,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required bool agreedToTerms,
  }) async {
    // `RegisterWithRoleRequest.agreedToTerms` is a non-nullable builder
    // field on the currently-vendored SDK generation - leaving it unset
    // throws inside the builder's own `build()` before this ever reaches
    // the network, not a server-side rejection. The live signup validator
    // requires `agreedToTerms` in the body regardless (confirmed by the web
    // app's own hand-rolled client, `web/src/lib/mudbase.ts`'s
    // `RegisterParams`), so it's set on the builder directly.
    final request = RegisterWithRoleRequest(
      (b) => b
        ..email = email
        ..password = password
        ..firstName = firstName
        ..lastName = lastName
        ..projectId = _projectId
        ..agreedToTerms = agreedToTerms,
    );
    final serialized = _sdk.serializers.serialize(
      request,
      specifiedType: const FullType(RegisterWithRoleRequest),
    );
    final body = serialized as Map<String, dynamic>;
    try {
      final response = await _sdk.dio.post<dynamic>(
        '/api/auth/local/signup/${Uri.encodeComponent(role)}',
        data: body,
        options: Options(contentType: 'application/json'),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final request = LoginLocalUserRequest(
      (b) => b
        ..email = email
        ..password = password
        ..projectId = _projectId,
    );
    final body = _sdk.serializers.serialize(
      request,
      specifiedType: const FullType(LoginLocalUserRequest),
    );
    try {
      final response = await _sdk.dio.post<dynamic>(
        '/api/auth/local/login',
        data: body,
        options: Options(contentType: 'application/json'),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  /// `POST /api/auth/refresh` - exchanges a still-valid refresh token for a
  /// new access/refresh pair. Confirmed live in this build's own smoke test:
  /// returns `{ message, token, refreshToken, expiresIn }` with a distinct
  /// new `token`. No generated builder class exists for this request (the
  /// bundled OpenAPI spec has no refresh endpoint at all), so the body is
  /// constructed by hand, same as the ecommerce port.
  Future<Map<String, dynamic>> refreshSession(String refreshToken) async {
    try {
      final response = await _sdk.dio.post<dynamic>(
        '/api/auth/refresh',
        data: {'refreshToken': refreshToken},
        options: Options(contentType: 'application/json'),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  /// `GET /api/auth/session` - both org- and project-scoped bearer tokens
  /// are accepted by this endpoint, so it works the same right after a
  /// local login as it does on cold-start session restore.
  Future<Map<String, dynamic>> getSession(String token) async {
    try {
      final response = await _sdk.dio.get<dynamic>(
        '/api/auth/session',
        queryParameters: {'projectId': _projectId},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return _asJsonMap(response);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<void> logout(String token) async {
    try {
      await _sdk.dio.post<dynamic>(
        '/api/auth/logout',
        data: {'projectId': _projectId},
        options: Options(
          contentType: 'application/json',
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } on DioException catch (error) {
      // Logout is a best-effort server-side revoke - the client clears its
      // own token regardless (see AuthController.logout), so a failed
      // revoke call must not block the local sign-out.
      if (error.response?.statusCode == 401) return;
      throw MudbaseException.fromDioException(error);
    }
  }

  Map<String, dynamic> _asJsonMap(Response<dynamic> response) {
    final data = response.data;
    if (data is Map<String, dynamic>) return data;
    throw const MudbaseException(
      'Unexpected response shape from the server.',
      0,
    );
  }
}
