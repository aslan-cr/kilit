import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../data/models.dart';
import 'shared_state.dart';
import 'store.dart';

enum LocStatus { ok, denied, deniedForever, serviceOff, weakSignal }

class LocResult {
  final GeoPoint2 point; final LocStatus status;
  const LocResult(this.point, this.status);
}

class LocationService {
  static const fallback = GeoPoint2(41.0082, 28.9784, name: 'İstanbul');

  static GeoPoint2? get lastKnown {
    final s = Store.prefs.get('last_place') as String?;
    if (s == null) return null;
    try { return GeoPoint2.fromJson((jsonDecode(s) as Map).cast<String, dynamic>()); } catch (_) { return null; }
  }
  static Future<void> remember(GeoPoint2 p) async {
    final j = jsonEncode(p.toJson());
    await Store.put('last_place', j);
    await (await SharedState.get()).setString('sn_last_place', j); // arka plan görevi için
  }

  /// GPS (bestForNavigation) + gerçek rakım. İzin yoksa/sinyal zayıfsa kilitlenmeden son/yakın konuma düşer.
  static Future<LocResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return LocResult(lastKnown ?? fallback, LocStatus.serviceOff);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return LocResult(lastKnown ?? fallback, LocStatus.deniedForever);
      if (perm == LocationPermission.denied) return LocResult(lastKnown ?? fallback, LocStatus.denied);
      try {
        final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, timeLimit: Duration(seconds: 12)));
        final g = GeoPoint2(p.latitude, p.longitude, elevation: p.altitude != 0 ? p.altitude : null, name: 'Konumum');
        await remember(g);
        return LocResult(g, LocStatus.ok);
      } catch (_) {
        // İçeride sinyal zayıf: son bilinen konum
        final lk = await Geolocator.getLastKnownPosition();
        if (lk != null) {
          return LocResult(GeoPoint2(lk.latitude, lk.longitude, elevation: lk.altitude != 0 ? lk.altitude : null, name: 'Konumum'), LocStatus.weakSignal);
        }
        return LocResult(lastKnown ?? fallback, LocStatus.weakSignal);
      }
    } catch (_) {
      return LocResult(lastKnown ?? fallback, LocStatus.weakSignal);
    }
  }

  // Kayıtlı konumlar (Evim, Anneannem...)
  static List<GeoPoint2> saved() => places();
  static List<GeoPoint2> places() => Store.places.values
      .map((e) => GeoPoint2.fromJson((jsonDecode(e as String) as Map).cast<String, dynamic>())).toList();
  static Future<void> savePlace(GeoPoint2 p) => Store.places.put(p.name, jsonEncode(p.toJson()));
  static Future<void> deletePlace(String name) => Store.places.delete(name);
}
