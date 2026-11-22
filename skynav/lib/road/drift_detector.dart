// Kayma (drift) algılayıcı: ivmeölçer + jiroskop + GPS hızı tutarlılığı.
// Saf Dart; sensör akışı UI katmanında bağlanır.
//
// Fikir: araç bir yay üzerinde dönerken beklenen yanal ivme = hız × yaw rate.
// Ölçülen yanal ivme bundan belirgin biçimde sapıyorsa araç kayıyor olabilir.
//
// Birimler: ivme m/s² (yerçekimi dahil ham okuma), jiroskop rad/s,
// hız m/s, buzlanma riski 0-1.
import 'dart:math' as math;

import '../data/phrases.dart';

/// Tüm eşikler burada, sabit ve belgeli.
class DriftConfig {
  DriftConfig._();

  /// Bu hızın altında kayma tespiti yapılmaz (~18 km/sa).
  static const double minSpeedMs = 5.0;

  /// Kuru yolda temel eşik: |ölçülen - beklenen| yanal ivme > 1.8 m/s² (~0.18 g).
  static const double baseThresholdMs2 = 1.8;

  /// Buzlanma riski 1.0 iken eşik bu oranda düşer (1.8 -> 1.08 m/s²).
  static const double icyReduction = 0.4;

  /// Eşik aşımının bu süre (sn) sürmesi gerekir; sensör gürültüsünü süzer.
  static const double suspectHoldS = 0.3;

  /// Bir olaydan sonra yeni olay üretilmeyen bekleme (sn).
  static const double cooldownS = 3.0;

  /// Yerçekimi tahmini için düşük geçiren filtre katsayısı (~50 Hz'de ~2 sn).
  static const double gravityAlpha = 0.99;

  /// Bu aralıktan (sn) uzun boşlukta örnek atlanır ve durum sıfırlanır.
  static const double maxGapS = 1.0;

  /// GPS ivmesi bu eşiği (m/s²) aşınca ileri eksen öğrenmesi yapılır.
  static const double forwardLearnAccelMs2 = 0.6;

  static const double gravity = 9.80665;

  /// Olay mesajları Kanki listesinden: şiddet 1-2 için "kayma hissedildi" cümlesi,
  /// şiddet 3 için "panik yapma" cümlesi.
  static final String messageMild = Kanki.kayganYolUyari[1];
  static final String messageSevere = Kanki.kayganYolUyari[8];
}

class DriftEvent {
  /// 1 (hafif) .. 3 (ciddi).
  final int severity;
  final String message;
  /// Eşiği aşan yanal ivme farkı (m/s², mutlak).
  final double mismatchMs2;
  final double speedMs;
  final DateTime at;
  const DriftEvent({
    required this.severity,
    required this.message,
    required this.mismatchMs2,
    required this.speedMs,
    required this.at,
  });
}

enum DriftState { stable, suspect, cooldown }

typedef _V3 = List<double>;

double _n(_V3 v) => math.sqrt(v[0] * v[0] + v[1] * v[1] + v[2] * v[2]);
double _dot(_V3 a, _V3 b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
_V3 _sub(_V3 a, _V3 b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
_V3 _mul(_V3 a, double k) => [a[0] * k, a[1] * k, a[2] * k];
_V3 _cross(_V3 a, _V3 b) => [
      a[1] * b[2] - a[2] * b[1],
      a[2] * b[0] - a[0] * b[2],
      a[0] * b[1] - a[1] * b[0],
    ];
_V3 _unit(_V3 v) {
  final m = _n(v);
  return m < 1e-9 ? const [0, 0, 1] : _mul(v, 1 / m);
}

class DriftDetector {
  _V3 _gravity = const [0, 0, 0];
  bool _hasGravity = false;
  bool _calibrated = false;
  _V3 _fwdAcc = const [0, 0, 0];

  DateTime? _lastT;
  double? _lastSpeed;
  DriftState _state = DriftState.stable;
  DateTime? _suspectSince;
  DateTime? _cooldownUntil;

  double _gForce = 0, _lateralG = 0, _longitudinalG = 0;

  /// Toplam dinamik G (yerçekimi çıkarılmış ivme / 9.81).
  double get gForce => _gForce;
  /// Yanal G (ileri eksene dik, yatay düzlem). Pozitif = aracın solu
  /// (eksen: yukarı × ileri).
  double get lateralG => _lateralG;
  /// Boylamsal G (ileri/geri; ivmelenme pozitif, frenleme negatif).
  double get longitudinalG => _longitudinalG;
  bool get isCalibrated => _calibrated;
  DriftState get state => _state;

  /// Telefon düz dururken (ekran yukarı) okunan yerçekimi vektörü ile kalibrasyon.
  /// Yerçekimi tahminini başlatır ve "yukarı" yönünü sabitler. Magnitüd
  /// 5-15 m/s² dışındaysa (sensör hatası ya da düz değil) yok sayılır.
  void setOrientationCalibration({
    required double gx,
    required double gy,
    required double gz,
  }) {
    final v = <double>[gx, gy, gz];
    final m = _n(v);
    if (m < 5 || m > 15) return;
    _gravity = v;
    _hasGravity = true;
    _calibrated = true;
  }

  /// Durumu sıfırlar (yerçekimi ve kalibrasyon korunur).
  void reset() {
    _fwdAcc = const [0, 0, 0];
    _lastT = null;
    _lastSpeed = null;
    _state = DriftState.stable;
    _suspectSince = null;
    _cooldownUntil = null;
    _gForce = _lateralG = _longitudinalG = 0;
  }

  /// Bir örnek işler. Olay üretirse [DriftEvent], üretmezse null döner.
  /// [time] verilmezse şimdiki zaman kullanılır (test için verilmesi önerilir).
  DriftEvent? addSample({
    required double ax,
    required double ay,
    required double az,
    required double gx,
    required double gy,
    required double gz,
    required double speedMs,
    double icyRisk = 0,
    DateTime? time,
  }) {
    final t = time ?? DateTime.now();
    final raw = <double>[ax, ay, az];
    final lastT = _lastT;
    final lastSpeed = _lastSpeed;
    _lastT = t;
    _lastSpeed = speedMs;

    if (!_hasGravity) {
      _gravity = raw;
      _hasGravity = true;
    } else {
      const a = DriftConfig.gravityAlpha;
      _gravity = [
        for (var i = 0; i < 3; i++) a * _gravity[i] + (1 - a) * raw[i],
      ];
    }
    if (lastT == null) return null;

    final dt = t.difference(lastT).inMicroseconds / 1e6;
    if (dt <= 0 || dt > DriftConfig.maxGapS) {
      _suspectSince = null;
      if (_state == DriftState.suspect) _state = DriftState.stable;
      return null;
    }

    final up = _unit(_gravity);
    final lin = _sub(raw, _gravity);
    _gForce = _n(lin) / DriftConfig.gravity;

    // Yatay düzlemdeki ivme bileşeni (yukarı eksene dik).
    final hor = _sub(lin, _mul(up, _dot(lin, up)));

    // İleri eksen öğrenimi: GPS hız değişimi (ivmelenme/frenleme) ile.
    if (lastSpeed != null) {
      final dv = (speedMs - lastSpeed) / dt;
      if (dv.abs() >= DriftConfig.forwardLearnAccelMs2 &&
          speedMs >= DriftConfig.minSpeedMs) {
        final sign = dv > 0 ? 1.0 : -1.0;
        _fwdAcc = [
          for (var i = 0; i < 3; i++) 0.98 * _fwdAcc[i] + sign * hor[i],
        ];
      }
    }
    final fwd = _forwardAxis(up);
    final lat = _unit(_cross(up, fwd));

    final latAcc = _dot(lin, lat);
    final longAcc = _dot(lin, fwd);
    _lateralG = latAcc / DriftConfig.gravity;
    _longitudinalG = longAcc / DriftConfig.gravity;

    final yawRate = gx * up[0] + gy * up[1] + gz * up[2]; // rad/s, dikey eksen
    final expectedLat = speedMs * yawRate;
    final mismatch = (latAcc.abs() - expectedLat.abs()).abs();
    final icy = icyRisk.clamp(0.0, 1.0);
    final threshold =
        DriftConfig.baseThresholdMs2 * (1 - DriftConfig.icyReduction * icy);
    final exceed = speedMs >= DriftConfig.minSpeedMs && mismatch > threshold;

    return _step(t, exceed, mismatch, threshold, speedMs);
  }

  DriftEvent? _step(DateTime t, bool exceed, double mismatch, double threshold,
      double speedMs) {
    switch (_state) {
      case DriftState.cooldown:
        if (!t.isBefore(_cooldownUntil!)) _state = DriftState.stable;
        return null;
      case DriftState.stable:
        if (exceed) {
          _state = DriftState.suspect;
          _suspectSince = t;
        }
        return null;
      case DriftState.suspect:
        if (!exceed) {
          _state = DriftState.stable;
          _suspectSince = null;
          return null;
        }
        final held = t.difference(_suspectSince!).inMicroseconds / 1e6;
        if (held < DriftConfig.suspectHoldS) return null;
        final ratio = mismatch / threshold;
        final severity = ratio < 1.5 ? 1 : (ratio < 2.5 ? 2 : 3);
        _state = DriftState.cooldown;
        _cooldownUntil =
            t.add(Duration(milliseconds: (DriftConfig.cooldownS * 1000).round()));
        _suspectSince = null;
        return DriftEvent(
          severity: severity,
          message: severity == 3
              ? DriftConfig.messageSevere
              : DriftConfig.messageMild,
          mismatchMs2: mismatch,
          speedMs: speedMs,
          at: t,
        );
    }
  }

  /// İleri eksen (yatay düzlemde, birim). Öğrenilmemişse telefonun Y ekseni.
  _V3 _forwardAxis(_V3 up) {
    var f = _sub(_fwdAcc, _mul(up, _dot(_fwdAcc, up)));
    if (_n(f) < 1.0) {
      f = _sub(const [0, 1, 0], _mul(up, up[1]));
    }
    if (_n(f) < 1e-6) return const [1, 0, 0];
    return _unit(f);
  }

  /// Şiddete göre olay mesajı.
  static String messageFor(int severity) =>
      severity >= 3 ? DriftConfig.messageSevere : DriftConfig.messageMild;
}
