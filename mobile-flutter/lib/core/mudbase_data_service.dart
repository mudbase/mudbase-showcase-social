import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mudbase_sdk/mudbase_sdk.dart';

import 'mudbase_exception.dart';

/// Generic Collections CRUD (`/api/data/projects/:projectId/collections/
/// :collectionId/data`) for the `posts`/`comments`/`likes`/`follows`
/// collections.
///
/// Bypasses the generated `DataApi` wrapper for the same reason as
/// [AuthService] (see that file's header): `DataApi.listData`'s typed
/// response, `DataListResponseDataInner`, only declares
/// `_id`/`createdAt`/`updatedAt` - every field this app actually renders
/// (`authorName`, `content`, `likesCount`, ...) would be silently dropped
/// from a list read. Single-document reads/writes type their `data` as a
/// generic `JsonObject`, but this service stays on raw `dio` calls
/// throughout for one consistent, fully-tested code path. Ported from the
/// sibling ecommerce Flutter app's `core/mudbase_data_service.dart`.
class MudbaseDataService {
  const MudbaseDataService(this._sdk, this._projectId);

  final MudbaseSdk _sdk;
  final String _projectId;

  String _basePath(String collectionId, [String? documentId]) {
    final base =
        '/api/data/projects/$_projectId/collections/$collectionId/data';
    return documentId == null ? base : '$base/$documentId';
  }

  Options _authOptions(String token, {String? contentType}) {
    return Options(
      contentType: contentType,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<Map<String, dynamic>>> list(
    String collectionId, {
    required String token,
    Map<String, dynamic>? filter,
    String sort = '-createdAt',
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sort': sort,
      if (filter != null && filter.isNotEmpty) 'filter': jsonEncode(filter),
    };
    try {
      final response = await _sdk.dio.get<dynamic>(
        _basePath(collectionId),
        queryParameters: query,
        options: _authOptions(token),
      );
      final body = response.data;
      final items = body is Map<String, dynamic> ? body['data'] : null;
      if (items is! List) return const [];
      return items.whereType<Map<String, dynamic>>().toList(growable: false);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  /// Same as [list] but also returns the server's `pagination.hasMore` -
  /// used by paginated screens (the feed) that need to know whether a
  /// "Load more" affordance should show, rather than guessing from whether
  /// a page came back short.
  Future<({List<Map<String, dynamic>> items, bool hasMore})> listPage(
    String collectionId, {
    required String token,
    Map<String, dynamic>? filter,
    String sort = '-createdAt',
    int page = 1,
    int limit = 50,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sort': sort,
      if (filter != null && filter.isNotEmpty) 'filter': jsonEncode(filter),
    };
    try {
      final response = await _sdk.dio.get<dynamic>(
        _basePath(collectionId),
        queryParameters: query,
        options: _authOptions(token),
      );
      final body = response.data;
      final rawItems = body is Map<String, dynamic> ? body['data'] : null;
      final items = rawItems is List
          ? rawItems.whereType<Map<String, dynamic>>().toList(growable: false)
          : const <Map<String, dynamic>>[];
      final pagination = body is Map<String, dynamic>
          ? body['pagination']
          : null;
      final hasMore = pagination is Map<String, dynamic>
          ? pagination['hasMore'] as bool? ?? false
          : false;
      return (items: items, hasMore: hasMore);
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  /// Same as [list] but also returns the server's `pagination.total` - used
  /// wherever this app needs a count (follower/following/post counts)
  /// rather than the rows themselves, mirroring the web app's
  /// `useFollowCounts` (`res.pagination.total` on a `limit: 1` query).
  Future<int> count(
    String collectionId, {
    required String token,
    Map<String, dynamic>? filter,
  }) async {
    final query = <String, dynamic>{
      'page': 1,
      'limit': 1,
      if (filter != null && filter.isNotEmpty) 'filter': jsonEncode(filter),
    };
    try {
      final response = await _sdk.dio.get<dynamic>(
        _basePath(collectionId),
        queryParameters: query,
        options: _authOptions(token),
      );
      final body = response.data;
      if (body is! Map<String, dynamic>) return 0;
      final pagination = body['pagination'];
      if (pagination is! Map<String, dynamic>) return 0;
      return pagination['total'] as int? ?? 0;
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>?> getById(
    String collectionId,
    String documentId, {
    required String token,
  }) async {
    try {
      final response = await _sdk.dio.get<dynamic>(
        _basePath(collectionId, documentId),
        options: _authOptions(token),
      );
      return _unwrapDocument(response);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> create(
    String collectionId,
    Map<String, dynamic> body, {
    required String token,
  }) async {
    try {
      final response = await _sdk.dio.post<dynamic>(
        _basePath(collectionId),
        data: body,
        options: _authOptions(token, contentType: 'application/json'),
      );
      final document = _unwrapDocument(response);
      if (document == null) {
        throw const MudbaseException(
          'The server did not return the created document.',
          0,
        );
      }
      return document;
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> update(
    String collectionId,
    String documentId,
    Map<String, dynamic> body, {
    required String token,
  }) async {
    try {
      final response = await _sdk.dio.patch<dynamic>(
        _basePath(collectionId, documentId),
        data: body,
        options: _authOptions(token, contentType: 'application/json'),
      );
      final document = _unwrapDocument(response);
      if (document == null) {
        throw const MudbaseException(
          'The server did not return the updated document.',
          0,
        );
      }
      return document;
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Future<void> delete(
    String collectionId,
    String documentId, {
    required String token,
  }) async {
    try {
      await _sdk.dio.delete<dynamic>(
        _basePath(collectionId, documentId),
        options: _authOptions(token),
      );
    } on DioException catch (error) {
      throw MudbaseException.fromDioException(error);
    }
  }

  Map<String, dynamic>? _unwrapDocument(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map<String, dynamic>) return null;
    final data = body['data'];
    return data is Map<String, dynamic> ? data : null;
  }
}
