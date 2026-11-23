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

/// (23-11-2026, his words: "pratek gost edit delet fromdate") in use on a day: between its From (valid_from) and its Till (valid_to) –
/// a mess, section or site removed in FALCON's web leaves the phone's lists from its date (the database's public.in_use).
bool inUse(Rec r, [String? day]) {
  final d = day ?? today(), f = r['valid_from'] as String?, t = r['valid_to'] as String?;
  return r['active'] != false && (f == null || f.compareTo(d) <= 0) && (t == null || t.compareTo(d) >= 0);
}

/// The messes this person may read (in use today); the one picked on this phone, else his site's, else the first.
Future<List<Mess>> messes() async => (await rows(sb.from('messes').select('id,name,site_id,contractor_id,counters,lat,lng,radius_m,active,valid_from,valid_to').eq('active', true).order('name')))
    .where((r) => inUse(r))
    .map(Mess.new)
    .toList();

Mess? myMess(List<Mess> list, String? homeSite) {
  final pick = Prefs.mess;
  return list.where((m) => m.id == pick).firstOrNull ?? list.where((m) => m.siteId == homeSite).firstOrNull ?? list.firstOrNull;
}

Future<List<Win>> windows(String? messId, String date) async {
  if (messId == null) return [];
  return (await rows(sb.from('meal_windows').select('meal,serve_from,serve_to,order_by,change_minutes').eq('mess_id', messId).isFilter('removed_at', null)
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
  // (Wolf 0017) only sections – no circle; each with its area (place + metres)
  return (await rows(sb.from('sections').select('id,code,name,km,place,lat,lng,radius_m,active,valid_from,valid_to').eq('site_id', siteId).eq('active', true).order('km').order('code')))
      .where((r) => inUse(r))
      .toList();
}

double? kmOf(Object? v) => v == null ? null : toD(v);

({List<MapSection> sections,}) toMap(List<Rec> secs) => (sections: [for (final s in secs) MapSection('${s['id']}', '${s['code']}', kmOf(s['km']))],);

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
