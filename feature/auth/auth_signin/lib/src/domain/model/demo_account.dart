/// An account the form can fill in for the user ("Use a demo account"). The
/// app passes them in; the feature knows no fixtures.
final class DemoAccount {
  const DemoAccount({
    required this.email,
    required this.password,
    required this.displayName,
  });

  final String email;
  final String password;
  final String displayName;

  @override
  bool operator ==(Object other) =>
      other is DemoAccount &&
      other.email == email &&
      other.password == password &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(email, password, displayName);

  @override
  String toString() => 'DemoAccount($email)';
}
