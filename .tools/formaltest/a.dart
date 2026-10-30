class A {
  A({required this._x});
  final int _x;
  int get x => _x;
}

void main() {
  final a = A(x: 1);
  print(a.x);
}
