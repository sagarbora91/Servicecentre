import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/billing/domain/entities/estimate.dart';
import 'package:service_centre_app/features/billing/domain/entities/estimate_line.dart';
import 'package:service_centre_app/features/billing/domain/entities/estimate_status.dart';

void main() {
  Estimate build({
    List<EstimateLine> lines = const [],
    EstimateStatus status = EstimateStatus.draft,
  }) =>
      Estimate(
        id: 'e1',
        jobId: 'j1',
        branchId: 'b1',
        lines: lines,
        totalPaise: 0,
        status: status,
      );

  group('Estimate.computedTotalPaise', () {
    test('is zero for no lines', () {
      expect(build().computedTotalPaise, 0);
    });

    test('sums the line amounts in paise', () {
      final e = build(
        lines: const [
          EstimateLine(desc: 'Service', amountPaise: 150000),
          EstimateLine(desc: 'Battery', amountPaise: 25000),
          EstimateLine(desc: 'Strap', amountPaise: 49900),
        ],
      );

      expect(e.computedTotalPaise, 224900);
    });
  });

  group('Estimate.isApproved', () {
    test('is true only when status is approved', () {
      expect(build(status: EstimateStatus.approved).isApproved, isTrue);
      expect(build(status: EstimateStatus.draft).isApproved, isFalse);
      expect(build(status: EstimateStatus.sent).isApproved, isFalse);
      expect(build(status: EstimateStatus.declined).isApproved, isFalse);
    });
  });

  group('EstimateStatus wire round-trip', () {
    test('maps each value to/from its wire string', () {
      for (final s in EstimateStatus.values) {
        expect(EstimateStatus.fromWire(s.toWire), s);
      }
    });

    test('returns null for missing/unknown wire strings', () {
      expect(EstimateStatus.fromWire(null), isNull);
      expect(EstimateStatus.fromWire('nope'), isNull);
    });
  });
}
