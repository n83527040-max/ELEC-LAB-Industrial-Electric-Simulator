class IdFactory {
  IdFactory({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  int _counter = 0;

  String create(String prefix) {
    _counter++;
    return '${prefix}_${_clock().microsecondsSinceEpoch}_$_counter';
  }
}
