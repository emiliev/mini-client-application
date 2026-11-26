/// One account of the mock identity provider. The data is invented.
final class FixtureUser {
  const FixtureUser({
    required this.id,
    required this.email,
    required this.password,
    required this.displayName,
    this.seededFavourites = const [],
  });

  final String id;
  final String email;
  final String password;
  final String displayName;

  /// `kind/id` favourites the default set starts with.
  final List<String> seededFavourites;

  /// What the API shows; never the password.
  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
  };
}

/// The accounts every identity set knows, in id order.
const List<FixtureUser> fixtureUsers = [
  FixtureUser(
    id: 'u-100',
    email: 'reader@mini-client.test',
    password: 'marvelous',
    displayName: 'Rhea Reader',
    seededFavourites: ['character/100000', 'character/100001'],
  ),
  FixtureUser(
    id: 'u-101',
    email: 'collector@mini-client.test',
    password: 'vault-7',
    displayName: 'Cole Collector',
  ),
];
