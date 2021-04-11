class Event {
  List<void Function()> _handlers = List<void Function()>.empty(growable: true);
  void add(void Function() handler) {
    _handlers.add(handler);
  }

  void remove(void Function() handler) {
    _handlers.remove(handler);
  }

  void invoke() {
    _handlers.forEach((handler) {
      handler();
    });
  }
}
