import 'package:dio/dio.dart';
import 'package:mudbase_showcase_social/core/mudbase_exception.dart';
import 'package:test/test.dart';

RequestOptions _requestOptions() => RequestOptions(path: '/api/test');

void main() {
  group('MudbaseException.fromDioException', () {
    test('reads the server\'s {error} message and status code', () {
      final error = DioException(
        requestOptions: _requestOptions(),
        response: Response<dynamic>(
          requestOptions: _requestOptions(),
          statusCode: 401,
          data: {'error': 'Authentication required'},
        ),
      );

      final exception = MudbaseException.fromDioException(error);

      expect(exception.statusCode, 401);
      expect(exception.message, 'Authentication required');
    });

    test(
      'reads a {code} field for callers that need to branch on it (e.g. EMAIL_VERIFICATION_REQUIRED)',
      () {
        final error = DioException(
          requestOptions: _requestOptions(),
          response: Response<dynamic>(
            requestOptions: _requestOptions(),
            statusCode: 403,
            data: {
              'error': 'Email verification required',
              'code': 'EMAIL_VERIFICATION_REQUIRED',
            },
          ),
        );

        final exception = MudbaseException.fromDioException(error);

        expect(exception.statusCode, 403);
        expect(exception.code, 'EMAIL_VERIFICATION_REQUIRED');
      },
    );

    test(
      'falls back to a generic message when the response body is not a JSON map',
      () {
        final error = DioException(
          requestOptions: _requestOptions(),
          response: Response<dynamic>(
            requestOptions: _requestOptions(),
            statusCode: 500,
            data: 'Internal Server Error',
          ),
        );

        final exception = MudbaseException.fromDioException(error);

        expect(exception.statusCode, 500);
        expect(exception.message, contains('500'));
      },
    );

    test(
      'produces a user-friendly message for a connection timeout with no response at all',
      () {
        final error = DioException(
          requestOptions: _requestOptions(),
          type: DioExceptionType.connectionTimeout,
        );

        final exception = MudbaseException.fromDioException(error);

        expect(exception.statusCode, 0);
        expect(exception.message, contains('timed out'));
      },
    );
  });
}
