class A {
  void m() {}
}

class B extends A {
  @override
  void m() => super.m();
}
