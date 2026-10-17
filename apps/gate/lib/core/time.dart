/// Times are stored in UTC and shown in Africa/Blantyre (CAT, UTC+2, no daylight
/// saving), whatever time zone the phone is set to.
const _cat = Duration(hours: 2);

DateTime toCat(DateTime t) => t.toUtc().add(_cat);

String _two(int n) => n.toString().padLeft(2, '0');

/// "08:42"
String formatTime(DateTime t) {
  final c = toCat(t);
  return '${_two(c.hour)}:${_two(c.minute)}';
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "17 Oct 2027"
String formatDate(DateTime t) {
  final c = toCat(t);
  return '${c.day} ${_months[c.month - 1]} ${c.year}';
}

/// "1 h 05 min", "12 min", "under a minute"
String formatDuration(Duration d) {
  if (d.inMinutes < 1) return 'under a minute';
  if (d.inHours == 0) return '${d.inMinutes} min';
  return '${d.inHours} h ${_two(d.inMinutes % 60)} min';
}

/// "BT4521" → "BT 4521", matching the portal.
String displayPlate(String plate) {
  final m = RegExp(r'^([A-Z]+)(\d.*)$').firstMatch(plate);
  return m == null ? plate : '${m[1]} ${m[2]}';
}

/// "Chikondi Banda" → "CB"
String initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}
