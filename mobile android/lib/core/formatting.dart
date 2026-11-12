// Форматирование величин по-русски: запятая как разделитель, короткие
// единицы, склонения. Используется всеми экранами, чтобы цифры
// выглядели одинаково в списке, карточке и результате заплыва.
library;

import 'dart:math' as math;

String num(double value, [int fractionDigits = 1]) =>
    value.toStringAsFixed(fractionDigits).replaceAll('.', ',');

String distanceLabel(double meters, {int fractionDigits = 1}) {
  if (meters < 950) return '${meters.round()} м';
  return '${num(meters / 1000, fractionDigits)} км';
}

String speedLabel(double kph) => '${num(kph)} км/ч';

String paceLabel(double kph) {
  if (kph <= 0.05) return '—';
  final minutesPerKm = 60 / kph;
  final minutes = minutesPerKm.floor();
  final seconds = ((minutesPerKm - minutes) * 60).round();
  return '$minutes:${seconds.toString().padLeft(2, '0')} мин/км';
}

/// 2:45:32 — для трекинга и результата.
String clockLabel(Duration d) {
  final hours = d.inHours.toString().padLeft(2, '0');
  final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// Короткая длительность: 45 мин / 2 ч 45 мин.
String durationLabel(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds} с';
  if (d.inMinutes < 60) return '${d.inMinutes} мин';
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  return minutes == 0 ? '$hours ч' : '$hours ч $minutes мин';
}

String plural(int value, String one, String few, String many) {
  final mod100 = value % 100;
  final mod10 = value % 10;
  if (mod100 > 10 && mod100 < 20) return many;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}

String countLabel(int value, String one, String few, String many) =>
    '$value ${plural(value, one, few, many)}';

const _weekdaysShort = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
const _monthsShort = [
  'янв',
  'фев',
  'мар',
  'апр',
  'мая',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];

String timeLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

/// «Сб, 6 окт · 06:00»; если сегодня — только время.
String eventWhenLabel(DateTime value) {
  final now = DateTime.now();
  final sameDay = value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
  if (sameDay) return 'Сегодня, ${timeLabel(value)}';
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final isTomorrow = value.year == tomorrow.year &&
      value.month == tomorrow.month &&
      value.day == tomorrow.day;
  if (isTomorrow) return 'Завтра, ${timeLabel(value)}';
  return '${_weekdaysShort[value.weekday - 1]}, ${value.day} ${_monthsShort[value.month - 1]} · ${timeLabel(value)}';
}

String dayLabel(DateTime value) {
  final now = DateTime.now();
  final sameDay =
      value.year == now.year && value.month == now.month && value.day == now.day;
  if (sameDay) return 'Сегодня';
  return '${value.day} ${_monthsShort[value.month - 1]}';
}

String fullDateLabel(DateTime value) =>
    '${value.day} ${_monthsShort[value.month - 1]} ${value.year}';

/// «5 мин назад», «вчера», «3 дня назад», «12 окт».
String relativeTimeLabel(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inSeconds < 60) return 'только что';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} ${plural(diff.inMinutes, 'минуту', 'минуты', 'минут')} назад';
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} ${plural(diff.inHours, 'час', 'часа', 'часов')} назад';
  }
  if (diff.inDays == 1) return 'вчера';
  if (diff.inDays < 7) {
    return '${diff.inDays} ${plural(diff.inDays, 'день', 'дня', 'дней')} назад';
  }
  return dayLabel(value);
}

/// Оставшееся время до заплыва для главной экрана.
String countdownLabel(DateTime value) {
  final diff = value.difference(DateTime.now());
  if (diff.isNegative) return 'идёт сейчас';
  if (diff.inMinutes < 60) {
    return 'через ${diff.inMinutes} ${plural(diff.inMinutes, 'минуту', 'минуты', 'минут')}';
  }
  if (diff.inHours < 24) {
    return 'через ${diff.inHours} ${plural(diff.inHours, 'час', 'часа', 'часов')}';
  }
  return 'через ${diff.inDays} ${plural(diff.inDays, 'день', 'дня', 'дней')}';
}

/// Приветствие по времени суток (ТЗ §6.1).
String greetingLabel(String name) {
  final hour = DateTime.now().hour;
  final part = hour < 5
      ? 'Доброй ночи'
      : hour < 12
          ? 'Доброе утро'
          : hour < 18
              ? 'Добрый день'
              : 'Добрый вечер';
  return name.isEmpty ? part : '$part, $name';
}

/// Расчёт дистанции между точками (гаврусин, метры) — та же формула,
//  что на сервере в TracksService.computeStats.
double haversineMeters(
    double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double toRad(double deg) => deg * math.pi / 180;
  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(a)));
}
