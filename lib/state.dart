import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

enum Role { tenant, landlord }

/// Single source of truth for the app. Every change is persisted locally
/// (localStorage on web, SharedPreferences on Android/iOS,
/// a JSON file in AppData on Windows).
class AppState extends ChangeNotifier {
  AppState._(this._prefs);

  static const _key = 'depositguard.v1';
  final SharedPreferences _prefs;

  Tenancy? tenancy;
  Role role = Role.tenant;
  ThemeMode themeMode = ThemeMode.light;
  int monthsPerWearLevel = 12;

  /// "Today" can be pinned for demos; null means the real clock.
  DateTime? pinnedNow;
  DateTime get now => pinnedNow ?? DateTime.now();

  DeductionEngine get engine => DeductionEngine(monthsPerWearLevel: monthsPerWearLevel);

  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final s = AppState._(prefs);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s.role = Role.values.byName((j['role'] as String?) ?? 'tenant');
        s.themeMode = ThemeMode.values.byName((j['theme'] as String?) ?? 'light');
        s.monthsPerWearLevel = (j['wear'] as int?) ?? 12;
        final pinned = j['pinnedNow'] as String?;
        s.pinnedNow = pinned == null ? null : DateTime.parse(pinned);
        final t = j['tenancy'];
        if (t != null) s.tenancy = Tenancy.fromJson(Map<String, dynamic>.from(t as Map));
      } catch (_) {
        // Corrupt data: start fresh rather than crash.
        s.tenancy = null;
      }
    }
    return s;
  }

  Future<void> _save() => _prefs.setString(
        _key,
        jsonEncode({
          'role': role.name,
          'theme': themeMode.name,
          'wear': monthsPerWearLevel,
          'pinnedNow': pinnedNow?.toIso8601String(),
          'tenancy': tenancy?.toJson(),
        }),
      );

  /// Call after mutating anything inside [tenancy].
  void changed() {
    notifyListeners();
    _save();
  }

  void loadDemo() {
    tenancy = demoTenancy();
    pinnedNow = DateTime(2026, 11, 26);
    changed();
  }

  void createTenancy(Tenancy t) {
    tenancy = t;
    pinnedNow = null;
    // Pre-fill rent schedule from start month to the current month.
    final n = DateTime.now();
    var m = DateTime(t.start.year, t.start.month);
    while (!m.isAfter(DateTime(n.year, n.month))) {
      t.payments.add(RentPayment(month: m, amount: t.rent));
      m = DateTime(m.year, m.month + 1);
    }
    changed();
  }

  void reset() {
    tenancy = null;
    pinnedNow = null;
    changed();
  }

  void setRole(Role r) {
    role = r;
    changed();
  }

  void setTheme(ThemeMode m) {
    themeMode = m;
    changed();
  }

  void setWearRule(int months) {
    monthsPerWearLevel = months;
    changed();
  }

  void addItem(InspectionItem item) {
    tenancy!.items.add(item);
    changed();
  }

  void removeItem(InspectionItem item) {
    tenancy!.items.remove(item);
    changed();
  }

  void sign(Signature s) {
    final t = tenancy!;
    t.signatures.removeWhere((x) => x.role == s.role);
    t.signatures.add(s);
    if (t.signedBy('tenant') && t.signedBy('landlord')) {
      t.sealedFingerprint = fingerprintOf(t);
    }
    changed();
  }

  // ---- Photo storage -------------------------------------------------------
  // Photos are resized on capture and stored under their SHA-256 hash, so a
  // stored photo can always be re-checked against the hash in the seal.

  Uint8List? photo(String hash) {
    final b = _prefs.getString('photo.$hash');
    return b == null ? null : base64Decode(b);
  }

  Future<void> addPhoto(InspectionItem item, Uint8List bytes, String stage) async {
    final p = PhotoEvidence.fromBytes(bytes, stage: stage);
    await _prefs.setString('photo.${p.hash}', base64Encode(bytes));
    item.photos.add(p);
    changed();
  }

  /// True when the stored bytes still match the hash recorded at capture.
  bool photoIntact(PhotoEvidence p) {
    final b = photo(p.hash);
    return b != null && PhotoEvidence.fromBytes(b).hash == p.hash;
  }

  void addMonthlyRent() {
    final t = tenancy!;
    final last = t.payments.isEmpty
        ? DateTime(t.start.year, t.start.month - 1)
        : t.payments.last.month;
    t.payments.add(RentPayment(month: DateTime(last.year, last.month + 1), amount: t.rent));
    changed();
  }
}

/// Makes [AppState] available to the widget tree and rebuilds dependants.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
