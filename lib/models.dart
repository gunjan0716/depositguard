import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Condition of an item, recorded at move-in and again at move-out.
enum Condition { good, fair, worn, damaged }

extension ConditionX on Condition {
  String get label => switch (this) {
        Condition.good => 'Good',
        Condition.fair => 'Fair',
        Condition.worn => 'Worn',
        Condition.damaged => 'Damaged',
      };
}

Condition? _cond(Object? v) =>
    v == null ? null : Condition.values.byName(v as String);

/// A photo is stored as its SHA-256 hash + capture time. The hash goes into
/// the evidence seal, so swapping a photo later is detectable.
class PhotoEvidence {
  const PhotoEvidence({required this.hash, required this.takenAt, this.stage = 'move-in'});

  final String hash;
  final DateTime takenAt;
  final String stage; // 'move-in' | 'move-out'

  factory PhotoEvidence.fromBytes(List<int> bytes, {String stage = 'move-in', DateTime? at}) =>
      PhotoEvidence(
          hash: sha256.convert(bytes).toString(),
          takenAt: at ?? DateTime.now(),
          stage: stage);

  Map<String, dynamic> toJson() =>
      {'hash': hash, 'takenAt': takenAt.toIso8601String(), 'stage': stage};

  factory PhotoEvidence.fromJson(Map<String, dynamic> j) => PhotoEvidence(
      hash: j['hash'] as String,
      takenAt: DateTime.parse(j['takenAt'] as String),
      stage: (j['stage'] as String?) ?? 'move-in');
}

/// One inspectable item in a room (a wall, a fan, a geyser, a window...).
class InspectionItem {
  InspectionItem({
    required this.room,
    required this.name,
    required this.repairCost,
    required this.moveIn,
    this.moveOut,
    List<PhotoEvidence>? photos,
    this.note = '',
  }) : photos = photos ?? [];

  final String room;
  final String name;

  /// Typical cost (in ₹) to restore this item from "damaged" to "good".
  final int repairCost;
  final Condition moveIn;
  Condition? moveOut;
  final List<PhotoEvidence> photos;
  String note;

  int photosAt(String stage) => photos.where((p) => p.stage == stage).length;

  /// The part of an item that is frozen by the move-in seal.
  Map<String, dynamic> moveInJson() => {
        'room': room,
        'name': name,
        'repairCost': repairCost,
        'moveIn': moveIn.name,
        'photos': [
          for (final p in photos.where((p) => p.stage == 'move-in')) p.toJson()
        ],
      };

  Map<String, dynamic> toJson() => {
        ...moveInJson(),
        'photos': [for (final p in photos) p.toJson()],
        'moveOut': moveOut?.name,
        'note': note,
      };

  factory InspectionItem.fromJson(Map<String, dynamic> j) => InspectionItem(
        room: j['room'] as String,
        name: j['name'] as String,
        repairCost: j['repairCost'] as int,
        moveIn: Condition.values.byName(j['moveIn'] as String),
        moveOut: _cond(j['moveOut']),
        photos: [
          for (final p in (j['photos'] as List? ?? const []))
            PhotoEvidence.fromJson(Map<String, dynamic>.from(p as Map))
        ],
        note: (j['note'] as String?) ?? '',
      );
}

/// Result of the fair-deduction engine for a single item.
class ItemDeduction {
  const ItemDeduction(this.item, this.amount, this.reason);
  final InspectionItem item;
  final int amount;
  final String reason;
}

/// Rule-based, explainable deduction calculator.
///
///  * Normal wear & tear is never charged: one condition level of decline is
///    allowed for every [monthsPerWearLevel] months of tenancy.
///  * Decline beyond the allowance is charged pro-rata of the repair cost
///    (3 levels of decline = full repair cost).
///  * Unpaid rent and other dues are added as-is.
class DeductionEngine {
  const DeductionEngine({this.monthsPerWearLevel = 12});

  final int monthsPerWearLevel;

  int wearAllowance(int tenancyMonths) =>
      (tenancyMonths ~/ monthsPerWearLevel).clamp(0, 3);

  ItemDeduction evaluate(InspectionItem item, int tenancyMonths) {
    final out = item.moveOut;
    if (out == null) return ItemDeduction(item, 0, 'Not inspected yet');
    final decline = out.index - item.moveIn.index;
    if (decline <= 0) return ItemDeduction(item, 0, 'Same or better than move-in');
    final allowed = wearAllowance(tenancyMonths);
    final chargeable = decline - allowed;
    if (chargeable <= 0) {
      return ItemDeduction(item, 0, 'Normal wear & tear ($allowed level allowed)');
    }
    final amount = (item.repairCost * chargeable / 3).round();
    return ItemDeduction(item, amount,
        '$chargeable level(s) beyond wear & tear → $chargeable/3 of ₹${item.repairCost}');
  }

  List<ItemDeduction> evaluateAll(List<InspectionItem> items, int months) =>
      [for (final i in items) evaluate(i, months)];

  int damage(List<InspectionItem> items, int months) =>
      evaluateAll(items, months).fold<int>(0, (s, d) => s + d.amount);
}

class Signature {
  const Signature({required this.name, required this.role, required this.at, required this.strokes});
  final String name;
  final String role; // 'tenant' | 'landlord'
  final DateTime at;

  /// Pen strokes as lists of [x, y] points, so the signature can be redrawn.
  final List<List<List<double>>> strokes;

  Map<String, dynamic> toJson() =>
      {'name': name, 'role': role, 'at': at.toIso8601String(), 'strokes': strokes};

  factory Signature.fromJson(Map<String, dynamic> j) => Signature(
        name: j['name'] as String,
        role: j['role'] as String,
        at: DateTime.parse(j['at'] as String),
        strokes: [
          for (final s in (j['strokes'] as List))
            [
              for (final p in (s as List))
                [((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()]
            ]
        ],
      );
}

/// Builds the canonical text that the seal fingerprint is computed over.
/// Only move-in facts are included, so recording move-out data later does
/// not break the seal — but editing any move-in fact or photo does.
String sealPayload(Tenancy t) => jsonEncode({
      'address': t.address,
      'tenant': t.tenant,
      'landlord': t.landlord,
      'deposit': t.deposit,
      'rent': t.rent,
      'start': t.start.toIso8601String(),
      'items': [for (final i in t.items) i.moveInJson()],
    });

String fingerprintOf(Tenancy t) => sha256.convert(utf8.encode(sealPayload(t))).toString();

class RentPayment {
  RentPayment({required this.month, required this.amount, this.paidOn, this.mode = 'UPI'});
  final DateTime month; // first day of the rent month
  final int amount;
  DateTime? paidOn;
  String mode;
  bool get paid => paidOn != null;

  Map<String, dynamic> toJson() => {
        'month': month.toIso8601String(),
        'amount': amount,
        'paidOn': paidOn?.toIso8601String(),
        'mode': mode,
      };

  factory RentPayment.fromJson(Map<String, dynamic> j) => RentPayment(
        month: DateTime.parse(j['month'] as String),
        amount: j['amount'] as int,
        paidOn: j['paidOn'] == null ? null : DateTime.parse(j['paidOn'] as String),
        mode: (j['mode'] as String?) ?? 'UPI',
      );
}

class Tenancy {
  Tenancy({
    required this.address,
    required this.tenant,
    required this.landlord,
    required this.deposit,
    required this.rent,
    required this.start,
    List<InspectionItem>? items,
    List<RentPayment>? payments,
    List<Signature>? signatures,
    this.sealedFingerprint,
    this.otherDues = 0,
  })  : items = items ?? [],
        payments = payments ?? [],
        signatures = signatures ?? [];

  String address;
  String tenant;
  String landlord;
  int deposit;
  int rent;
  DateTime start;
  final List<InspectionItem> items;
  final List<RentPayment> payments;
  final List<Signature> signatures;

  /// Fingerprint stored at the moment both parties signed.
  String? sealedFingerprint;

  /// Electricity / maintenance dues agreed at move-out.
  int otherDues;

  int monthsAt(DateTime now) =>
      ((now.year - start.year) * 12 + now.month - start.month).clamp(0, 1200);

  int get unpaidRent => payments.where((p) => !p.paid).fold(0, (s, p) => s + p.amount);
  int get paidRent => payments.where((p) => p.paid).fold(0, (s, p) => s + p.amount);
  int get totalDues => unpaidRent + otherDues;

  bool get isSealed => sealedFingerprint != null;
  bool get sealIntact => sealedFingerprint == fingerprintOf(this);
  bool signedBy(String role) => signatures.any((s) => s.role == role);

  Map<String, dynamic> toJson() => {
        'address': address,
        'tenant': tenant,
        'landlord': landlord,
        'deposit': deposit,
        'rent': rent,
        'start': start.toIso8601String(),
        'items': [for (final i in items) i.toJson()],
        'payments': [for (final p in payments) p.toJson()],
        'signatures': [for (final s in signatures) s.toJson()],
        'sealedFingerprint': sealedFingerprint,
        'otherDues': otherDues,
      };

  factory Tenancy.fromJson(Map<String, dynamic> j) => Tenancy(
        address: j['address'] as String,
        tenant: j['tenant'] as String,
        landlord: j['landlord'] as String,
        deposit: j['deposit'] as int,
        rent: j['rent'] as int,
        start: DateTime.parse(j['start'] as String),
        items: [
          for (final i in (j['items'] as List? ?? const []))
            InspectionItem.fromJson(Map<String, dynamic>.from(i as Map))
        ],
        payments: [
          for (final p in (j['payments'] as List? ?? const []))
            RentPayment.fromJson(Map<String, dynamic>.from(p as Map))
        ],
        signatures: [
          for (final s in (j['signatures'] as List? ?? const []))
            Signature.fromJson(Map<String, dynamic>.from(s as Map))
        ],
        sealedFingerprint: j['sealedFingerprint'] as String?,
        otherDues: (j['otherDues'] as int?) ?? 0,
      );
}

/// Standard checklist used when a new tenancy is created.
List<InspectionItem> defaultChecklist() {
  InspectionItem i(String room, String name, int cost) =>
      InspectionItem(room: room, name: name, repairCost: cost, moveIn: Condition.good);
  return [
    i('Living room', 'Walls & paint', 18000),
    i('Living room', 'Ceiling fan', 2500),
    i('Living room', 'Switches & sockets', 1500),
    i('Kitchen', 'Chimney / exhaust', 9000),
    i('Kitchen', 'Sink & tap', 3000),
    i('Bedroom', 'Wardrobe doors', 8000),
    i('Bedroom', 'Window glass', 3500),
    i('Bathroom', 'Geyser', 7000),
    i('Bathroom', 'Tiles & fittings', 6000),
  ];
}

/// Demo data so the app is explorable on first launch.
Tenancy demoTenancy() {
  final signedAt = DateTime(2025, 6, 1, 10, 51);
  InspectionItem i(String room, String name, int cost, Condition inC,
      Condition outC, int photos) {
    return InspectionItem(
      room: room,
      name: name,
      repairCost: cost,
      moveIn: inC,
      moveOut: outC,
      photos: [
        for (var n = 0; n < photos; n++)
          PhotoEvidence(
            hash: sha256.convert(utf8.encode('$room/$name/$n')).toString(),
            takenAt: DateTime(2025, 6, 1, 10, 20 + n),
          ),
      ],
    );
  }

  final t = Tenancy(
    address: 'Flat 304, Green Residency, HSR Layout, Bengaluru',
    tenant: 'Aarav Sharma',
    landlord: 'R. Krishnan',
    deposit: 150000,
    rent: 25000,
    start: DateTime(2025, 6, 1),
    items: [
      i('Living room', 'Walls & paint', 18000, Condition.good, Condition.fair, 6),
      i('Living room', 'Ceiling fan', 2500, Condition.good, Condition.good, 2),
      i('Living room', 'Sofa (furnished)', 22000, Condition.fair, Condition.damaged, 4),
      i('Kitchen', 'Chimney', 9000, Condition.good, Condition.worn, 3),
      i('Kitchen', 'Granite counter', 12000, Condition.good, Condition.good, 3),
      i('Bedroom', 'Wardrobe doors', 8000, Condition.fair, Condition.fair, 4),
      i('Bedroom', 'Window glass', 3500, Condition.good, Condition.damaged, 2),
      i('Bathroom', 'Geyser', 7000, Condition.fair, Condition.worn, 2),
    ],
    payments: [
      for (var m = 6; m <= 10; m++)
        RentPayment(month: DateTime(2026, m), amount: 25000, paidOn: DateTime(2026, m, 3)),
      RentPayment(month: DateTime(2026, 11), amount: 25000),
    ],
  );
  const wave = [
    [
      [10.0, 40.0], [30.0, 10.0], [50.0, 45.0], [70.0, 12.0], [90.0, 40.0], [120.0, 25.0]
    ]
  ];
  t.signatures
    ..add(Signature(name: t.tenant, role: 'tenant', at: signedAt, strokes: wave))
    ..add(Signature(
        name: t.landlord,
        role: 'landlord',
        at: signedAt.add(const Duration(minutes: 16)),
        strokes: wave));
  t.sealedFingerprint = fingerprintOf(t);
  return t;
}
