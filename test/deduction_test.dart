import 'dart:convert';

import 'package:depositguard/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = DeductionEngine();

  InspectionItem item(Condition inC, Condition outC) =>
      InspectionItem(room: 'Test', name: 'Wall', repairCost: 9000, moveIn: inC, moveOut: outC);

  group('DeductionEngine', () {
    test('wear & tear within allowance is free', () {
      expect(engine.evaluate(item(Condition.good, Condition.fair), 17).amount, 0);
    });

    test('decline beyond allowance is charged pro-rata', () {
      // 3 levels of decline, 1 allowed → 2/3 of ₹9000
      expect(engine.evaluate(item(Condition.good, Condition.damaged), 17).amount, 6000);
    });

    test('short tenancy gets no allowance', () {
      expect(engine.evaluate(item(Condition.good, Condition.fair), 5).amount, 3000);
    });

    test('improvement is never charged', () {
      expect(engine.evaluate(item(Condition.worn, Condition.good), 3).amount, 0);
    });

    test('demo tenancy totals', () {
      final t = demoTenancy();
      final months = t.monthsAt(DateTime(2026, 11, 26));
      expect(months, 17);
      expect(engine.damage(t.items, months), 12666);
      expect(t.unpaidRent, 25000);
    });
  });

  group('Evidence seal', () {
    test('demo tenancy is sealed and intact', () {
      final t = demoTenancy();
      expect(t.isSealed, isTrue);
      expect(t.sealIntact, isTrue);
    });

    test('editing move-in evidence breaks the seal', () {
      final t = demoTenancy();
      t.items.first.photos.removeLast();
      expect(t.sealIntact, isFalse);
    });

    test('recording move-out data keeps the seal intact', () {
      final t = demoTenancy();
      t.items.first.moveOut = Condition.damaged;
      t.items.first.photos.add(PhotoEvidence.fromBytes([1, 2, 3], stage: 'move-out'));
      expect(t.sealIntact, isTrue);
    });
  });

  test('tenancy survives a JSON round-trip', () {
    final t = demoTenancy();
    final copy = Tenancy.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
    expect(fingerprintOf(copy), fingerprintOf(t));
    expect(copy.sealIntact, isTrue);
    expect(copy.signatures.length, 2);
  });
}
