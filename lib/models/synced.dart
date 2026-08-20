/// Data + kung naka-sync na ba ito sa cloud.
///
/// Offline-first tayo, kaya hindi sapat ang data lang — kailangang makita
/// ng QM kung may naka-pending pang isusulat. Ito ang nagpapagana sa
/// "not yet synced" indicator nang hindi nagsasabog ng Firestore types
/// sa buong UI layer.
class Synced<T> {
  const Synced({
    required this.data,
    required this.hasPendingWrites,
    required this.isFromCache,
  });

  const Synced.settled(this.data)
      : hasPendingWrites = false,
        isFromCache = false;

  final T data;

  /// May local na sulat na hindi pa naaabot ang server.
  final bool hasPendingWrites;

  /// Galing sa local cache ang snapshot na ito (karaniwan kapag offline).
  final bool isFromCache;

  /// Ang tanging tanong na mahalaga sa QM: "nakaligtas na ba ang gabi ko?"
  bool get isFullySynced => !hasPendingWrites;

  Synced<R> map<R>(R Function(T value) transform) => Synced<R>(
        data: transform(data),
        hasPendingWrites: hasPendingWrites,
        isFromCache: isFromCache,
      );
}
