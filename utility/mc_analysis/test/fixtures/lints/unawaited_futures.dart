Future<int> g() async => 1;

Future<void> f() async {
  g();
}
