// How numbers, money, days and times are shown – India, the site's clock (Asia/Kolkata, UTC+05:30, no summer time) – the same
// as the web's src/lib/fmt.ts.

const _ist = Duration(hours: 5, minutes: 30);
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// (23-11-2026, his word: "day night auto select asel server time asel") the SERVER's clock, not the phone's: the difference is
/// taken from FALCON's server (GET /api/start – core/clock.dart) and every "now" below follows it.
int skewMs = 0;
void setSkew(int serverMs, int sentAt, int gotAt) {
  if (gotAt < sentAt) return;
  skewMs = serverMs + ((gotAt - sentAt) ~/ 2) - gotAt;
}

/// Now on the site's clock (a DateTime whose fields are India's time).
DateTime istNow() => DateTime.now().add(Duration(milliseconds: skewMs)).toUtc().add(_ist);

/// A moment from the database (ISO, with its offset) on the site's clock.
DateTime? ist(String? ts) {
  if (ts == null || ts.isEmpty) return null;
  final d = DateTime.tryParse(ts);
  if (d == null) return null;
  return d.toUtc().add(_ist);
}

/// A day "YYYY-MM-DD" as a DateTime at noon (no time-zone surprise).
DateTime? dayOf(String? d) => d == null || d.length < 10 ? null : DateTime.tryParse('${d.substring(0, 10)}T12:00:00');

String _two(int n) => n.toString().padLeft(2, '0');

/// Today on the site's clock, "YYYY-MM-DD".
String today([int offsetDays = 0]) {
  final d = istNow().add(Duration(days: offsetDays));
  return '${d.year}-${_two(d.month)}-${_two(d.day)}';
}

String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

String nowHM() {
  final d = istNow();
  return '${_two(d.hour)}:${_two(d.minute)}';
}

String time(String? ts) {
  final d = ist(ts);
  return d == null ? '–' : '${_two(d.hour)}:${_two(d.minute)}';
}

/// "12:30:00" → "12:30"
String hm(String? t) => t == null || t.length < 5 ? '–' : t.substring(0, 5);

/// "23 Nov" – from a day or a moment.
String day(String? d) {
  if (d == null || d.isEmpty) return '–';
  final x = d.length == 10 ? dayOf(d) : ist(d);
  return x == null ? '–' : '${x.day} ${_months[x.month - 1]}';
}

/// "Mon 23 Nov"
String dayLong(String d) {
  final x = d.length == 10 ? dayOf(d) : ist(d);
  return x == null ? '–' : '${_days[x.weekday - 1]} ${x.day} ${_months[x.month - 1]}';
}

String monthName(String d) {
  final x = dayOf(d);
  return x == null ? '–' : '${_monthsLong[x.month - 1]} ${x.year}';
}

/// Indian grouping: 12,34,567 (the web's num())
String numf(num? n) {
  if (n == null) return '–';
  final neg = n < 0;
  final v = n.abs();
  final whole = v.truncate();
  final frac = v - whole;
  var s = whole.toString();
  if (s.length > 3) {
    final last = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last';
  }
  if (frac > 0.0001) {
    final f = (frac * 100).round();
    if (f > 0 && f < 100) s = '$s.${_two(f)}'.replaceAll(RegExp(r'0$'), '');
  }
  return (neg ? '-' : '') + s;
}

String inr(num? n) => n == null ? '–' : '₹${numf(n)}';

double toD(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int toI(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

String greeting() {
  final h = istNow().hour;
  return h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
}

String initials(String? name) {
  final w = (name ?? '?').split(RegExp(r'\s+')).where((x) => x.isNotEmpty).take(2).map((x) => x[0].toUpperCase());
  final s = w.join();
  return s.isEmpty ? '?' : s;
}

String firstName(String? name) {
  final w = (name ?? '').split(RegExp(r'\s+'));
  return w.isEmpty ? '' : w.first;
}

const meals = ['breakfast', 'lunch', 'snacks', 'dinner'];
String mealName(String? m) => m == null || m.isEmpty ? '' : m[0].toUpperCase() + m.substring(1);
const mealIcon = {'breakfast': 'coffee', 'lunch': 'soup', 'snacks': 'cookie', 'dinner': 'moon'};

int minutesLeft(String ts) {
  final d = DateTime.tryParse(ts);
  if (d == null) return 0;
  return (d.difference(DateTime.now()).inSeconds / 60).round();
}

String leftText(String ts) {
  final m = minutesLeft(ts);
  if (m < 0) return 'late by ${m > -60 ? '${-m} min' : '${(-m / 60).round()} h'}';
  return m < 60 ? '$m min left' : '${(m / 60).round()} h left';
}

String maskMobile(String? m) {
  if (m == null || m.length < 6) return '–';
  return '${m.substring(0, 3)} ${m.substring(3, 5)}XXX XX${m.substring(m.length - 3)}';
}

/// A 10-digit Indian mobile typed in any way → "+91XXXXXXXXXX", or null.
String? phoneE164(String typed) {
  final d = typed.replaceAll(RegExp(r'\D'), '');
  final ten = d.length >= 10 ? d.substring(d.length - 10) : '';
  if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(ten)) return null;
  return '+91$ten';
}
