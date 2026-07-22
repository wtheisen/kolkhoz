import 'dart:convert';

class RemoteRequestException implements Exception {
  const RemoteRequestException({
    required this.statusCode,
    required this.uri,
    required this.responseBody,
    required this.sentAuthorization,
  });

  final int statusCode;
  final Uri uri;
  final String responseBody;
  final bool sentAuthorization;

  String get message {
    if (responseBody.isNotEmpty) {
      try {
        final decoded = jsonDecode(responseBody);
        if (decoded is Map) {
          final detail = decoded['detail'] ?? decoded['error'];
          if (detail is String && detail.isNotEmpty) {
            return detail;
          }
        }
      } catch (_) {
        // Fall through to the raw response body.
      }
    }
    return responseBody.isEmpty ? 'Remote request failed' : responseBody;
  }

  @override
  String toString() {
    final auth = sentAuthorization ? 'sent' : 'missing';
    return 'RemoteRequestException: $message '
        '(status $statusCode, auth $auth), uri = $uri';
  }
}
