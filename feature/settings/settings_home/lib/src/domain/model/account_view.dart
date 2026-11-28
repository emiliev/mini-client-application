/// Who the account section shows (pure Dart, so the bloc stays Flutter-free,
/// R15).
sealed class AccountView {
  const AccountView();
}

/// Nobody is signed in: "Not signed in", with Sign in.
final class SignedOutAccount extends AccountView {
  const SignedOutAccount();

  @override
  bool operator ==(Object other) => other is SignedOutAccount;

  @override
  int get hashCode => (SignedOutAccount).hashCode;

  @override
  String toString() => 'SignedOutAccount()';
}

/// Someone is signed in: [userId] is known from the session at once; the
/// [profile] arrives with a read of the account and is null before it, and
/// when that read failed (the page then names the user by id).
final class SignedInAccount extends AccountView {
  const SignedInAccount(this.userId, {this.profile});

  final String userId;
  final UserProfile? profile;

  /// The name the page shows: the profile's display name, else the id.
  String get name => profile?.displayName ?? userId;

  @override
  bool operator ==(Object other) =>
      other is SignedInAccount &&
      other.userId == userId &&
      other.profile == profile;

  @override
  int get hashCode => Object.hash(SignedInAccount, userId, profile);

  @override
  String toString() => 'SignedInAccount($userId, $profile)';
}

/// What `GET v1/me` says about the signed-in user.
final class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
  });

  /// Reads the body of `GET v1/me`. Throws a [FormatException] when a field
  /// is missing or not a string.
  factory UserProfile.fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'email': final String email,
      'displayName': final String name,
    }) {
      return UserProfile(id: id, email: email, displayName: name);
    }
    throw FormatException('Not a user: $json');
  }

  final String id;
  final String email;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(UserProfile, id, email, displayName);

  @override
  String toString() => 'UserProfile($id, $email, $displayName)';
}
