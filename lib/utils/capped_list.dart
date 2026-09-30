/// Fixed-size history buffer helper.
extension CappedList<T> on List<T> {
  /// Appends [value], dropping the oldest entry once the list exceeds [max].
  void pushCapped(T value, int max) {
    add(value);
    if (length > max) removeAt(0);
  }
}
