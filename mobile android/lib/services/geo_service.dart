// Доступ к GPS (geolocator).
//
// Отдельный сервис нужен по двум причинам: правами надо управлять
// человеческим языком (ТЗ §28), и трекing должен отличать
// «нет сигнала» от «нет разрешения» от «службы геолокации выключены».
import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum GeoAvailability {
  ok,
  serviceDisabled,
  denied,
  deniedForever,
}

class GeoResult {
  final GeoAvailability availability;
  const GeoResult(this.availability);

  bool get isOk => availability == GeoAvailability.ok;

  String get message => switch (availability) {
        GeoAvailability.ok => '',
        GeoAvailability.serviceDisabled =>
          'Службы геолокации выключены. Включите геолокацию в настройках устройства.',
        GeoAvailability.denied =>
          'Без доступа к геолокации заплыв не записать. Разрешите её в настройках приложения.',
        GeoAvailability.deniedForever =>
          'Доступ к геолокации запрещён навсегда. Разрешите его в настройках приложения.',
      };
}

class GeoService {
  const GeoService();

  /// Запрашивает разрешения так, чтобы экран мог показать внятную причину.
  Future<GeoResult> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const GeoResult(GeoAvailability.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always => const GeoResult(GeoAvailability.ok),
      LocationPermission.whileInUse => const GeoResult(GeoAvailability.ok),
      LocationPermission.denied => const GeoResult(GeoAvailability.denied),
      LocationPermission.deniedForever =>
        const GeoResult(GeoAvailability.deniedForever),
      _ => const GeoResult(GeoAvailability.denied),
    };
  }

  Future<Position?> current() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } on Exception {
      return null;
    }
  }

  /// Поток точек. distanceFilter = 3 м: для сапсёрфинга это примерно
  /// секунда движения, меньше — только шум.
  Stream<Position> watch() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 3,
        ),
      );

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();
}
