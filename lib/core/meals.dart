// What the meal screens share – the mess of this person, its meal times, the things sold, the sections of the road – the same as
// the web's shared part of src/screens/employee.tsx.
import '../ui/road_map.dart';
import 'db.dart';
import 'fmt.dart';
import 'prefs.dart';

class Mess {
  Mess(Rec r)
      : id = '${r['id']}', name = '${r['name']}', siteId = '${r['site_id']}', contractorId = r['contractor_id'] as String?, counters = r['counters'] as int?,
        lat = r['lat'] == null ? null : toD(r['lat']), lng = r['lng'] == null ? null : toD(r['lng']), radiusM = r['radius_m'] == null ? null : toI(r['radius_m']);
  final String id, name, siteId;
  final String? contractorId;
  final int? counters;
  // (23-11-2026) where the mess is and its area – "at the mess" is inside it
  final double? lat, lng;
  final int? radiusM;
}

class Win {
  Win(Rec r) : meal = '${r['meal']}', serveFrom = hm(r['serve_from'] as String?), serveTo = hm(r['serve_to'] as String?), orderBy = hm(r['order_by'] as String?), changeMinutes = toI(r['change_minutes']);
  final String meal, serveFrom, serveTo, orderBy;
  final int changeMinutes;
}

/// The messes this person may read; the one picked on this phone, else his site's, else the first.
Future<List<Mess>> messes() async => (await rows(sb.from('messes').select('id,name,site_id,contractor_id,counters,lat,lng,radius_m').eq('active', true).order('name'))).map(Mess.new).toList();

Mess? myMess(List<Mess> list, String? homeSite) {
  final pick = Prefs.mess;
  return list.where((m) => m.id == pick).firstOrNull ?? list.where((m) => m.siteId == homeSite).firstOrNull ?? list.firstOrNull;
}

Future<List<Win>> windows(String? messId, String date) async {
  if (messId == null) return [];
  return (await rows(sb.from('meal_windows').select('meal,serve_from,serve_to,order_by,change_minutes').eq('mess_id', messId)
          .lte('valid_from', date).or('valid_to.is.null,valid_to.gte.$date')))
      .map(Win.new)
      .toList();
}

class WinState {
  const WinState(this.open, this.label);
  final bool open;
  final String label;
}

WinState winState(Win? w, String date, String kind) {
  if (w == null) return const WinState(false, 'Not served');
  if (date.compareTo(today()) > 0) return WinState(true, 'from ${w.serveFrom}');
  final now = nowHM(), end = kind == 'meal' ? w.serveTo : w.orderBy;
  if (now.compareTo(end) > 0) return const WinState(false, 'Closed');
  return WinState(true, now.compareTo(w.serveFrom) >= 0 ? 'till $end' : w.serveFrom);
}

String currentMeal(List<Win> wins) {
  final now = nowHM();
  final s = [...wins]..sort((a, b) => a.serveFrom.compareTo(b.serveFrom));
  return s.where((w) => now.compareTo(w.serveTo) <= 0).firstOrNull?.meal ?? 'lunch';
}

Future<List<Rec>> items() => rows(sb.from('items').select('id,code,name,kind,meal').eq('active', true).order('name'));

Future<List<Rec>> sections(String? siteId) async {
  if (siteId == null) return [];
  return rows(sb.from('sections').select('id,code,name,km,place,circle_id,lat,lng,circles(code,km_from,km_to)').eq('site_id', siteId).eq('active', true).order('km'));
}

double? kmOf(Object? v) => v == null ? null : toD(v);

({List<MapSection> sections, List<MapCircle> circles}) toMap(List<Rec> secs) {
  final circles = <String, MapCircle>{};
  for (final s in secs) {
    final c = s['circles'];
    if (c is Map) circles['${c['code']}'] = MapCircle('${c['code']}', kmOf(c['km_from']), kmOf(c['km_to']));
  }
  final cs = circles.values.toList()..sort((a, b) => a.code.compareTo(b.code));
  return (
    sections: [for (final s in secs) MapSection('${s['id']}', '${s['code']}', kmOf(s['km']), circle: (s['circles'] as Map?)?['code'] as String?)],
    circles: cs,
  );
}

const stateWords = {
  'requested': 'asked', 'accepted': 'accepted', 'preparing': 'being made', 'ready': 'ready', 'dispatched': 'on the way',
  'delivered': 'delivered', 'refused': 'refused', 'cancelled': 'cancelled', 'failed': 'not delivered',
};
String stateWord(String s) => stateWords[s] ?? s;

/// A guest's open visit (the same screens serve him).
Future<Rec?> guestVisit(String? personId, String kind) async {
  if (kind != 'guest' || personId == null) return null;
  return one(sb.from('guest_visits').select('id,site_id,section_id,purpose,started_at,host_role,host_id').eq('person_id', personId).isFilter('ended_at', null).limit(1));
}

/// The section picked for a parcel (this run of the app).
String? pickedSection;
