/// The pair a sign-in or a refresh hands out. The access token goes on every
/// request; the refresh token only goes to the refresh endpoint.
final class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  /// Null unless [json] is a map with two non-empty string tokens.
  static AuthTokens? fromJson(Object? json) {
    if (json case {
      'accessToken': final String access,
      'refreshToken': final String refresh,
    } when access.isNotEmpty && refresh.isNotEmpty) {
      return AuthTokens(accessToken: access, refreshToken: refresh);
    }
    return null;
  }

  final String accessToken;
  final String refreshToken;

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };

  @override
  bool operator ==(Object other) =>
      other is AuthTokens &&
      other.accessToken == accessToken &&
      other.refreshToken == refreshToken;

  @override
  int get hashCode => Object.hash(accessToken, refreshToken);

  /// Never prints the secrets.
  @override
  String toString() => 'AuthTokens(***)';
}
