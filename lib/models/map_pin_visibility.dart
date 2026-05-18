/// Profil istatistiklerinden haritaya geçerken hangi pinlerin gösterileceği.
enum MapPinVisibilityFilter { all, safeOnly, unsafeOnly }

/// Aynı filtreye tekrar basıldığında da dinleyicinin tetiklenmesi için benzersiz jeton.
class MapPinFilterIntent {
  const MapPinFilterIntent(this.filter, this.token);
  final MapPinVisibilityFilter filter;
  final int token;
}
