import 'package:flutter_test/flutter_test.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_outcome.dart';
import 'package:service_centre_app/features/jobs/domain/entities/job_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/payment_status.dart';
import 'package:service_centre_app/features/jobs/domain/entities/warranty_type.dart';

void main() {
  group('JobStatus wire mapping', () {
    const wires = <JobStatus, String>{
      JobStatus.received: 'received',
      JobStatus.diagnosed: 'diagnosed',
      JobStatus.awaitingPart: 'awaiting_part',
      JobStatus.inRepair: 'in_repair',
      JobStatus.qc: 'qc',
      JobStatus.ready: 'ready',
      JobStatus.delivered: 'delivered',
      JobStatus.returned: 'returned',
    };

    test('toWire matches the stored snake_case string', () {
      for (final entry in wires.entries) {
        expect(entry.key.toWire, entry.value);
        expect(entry.key.wireName, entry.value);
      }
    });

    test('fromWire round-trips every value', () {
      for (final entry in wires.entries) {
        expect(JobStatus.fromWire(entry.value), entry.key);
      }
    });

    test('fromWire returns null for unknown or missing values', () {
      expect(JobStatus.fromWire('shipped'), isNull);
      expect(JobStatus.fromWire(null), isNull);
      expect(JobStatus.fromWire(''), isNull);
    });
  });

  group('JobOutcome wire mapping', () {
    const wires = <JobOutcome, String>{
      JobOutcome.repaired: 'repaired',
      JobOutcome.declined: 'declined',
      JobOutcome.beyondRepair: 'beyond_repair',
      JobOutcome.returned: 'returned',
    };

    test('toWire matches the stored string', () {
      for (final entry in wires.entries) {
        expect(entry.key.toWire, entry.value);
      }
    });

    test('fromWire round-trips every value and rejects unknown/null', () {
      for (final entry in wires.entries) {
        expect(JobOutcome.fromWire(entry.value), entry.key);
      }
      expect(JobOutcome.fromWire('exploded'), isNull);
      expect(JobOutcome.fromWire(null), isNull);
    });
  });

  group('WarrantyType wire mapping', () {
    const wires = <WarrantyType, String>{
      WarrantyType.inWarranty: 'in_warranty',
      WarrantyType.paid: 'paid',
      WarrantyType.goodwill: 'goodwill',
    };

    test('toWire matches the stored string', () {
      for (final entry in wires.entries) {
        expect(entry.key.toWire, entry.value);
      }
    });

    test('fromWire round-trips every value and rejects unknown/null', () {
      for (final entry in wires.entries) {
        expect(WarrantyType.fromWire(entry.value), entry.key);
      }
      expect(WarrantyType.fromWire('lifetime'), isNull);
      expect(WarrantyType.fromWire(null), isNull);
    });
  });

  group('PaymentStatus wire mapping', () {
    const wires = <PaymentStatus, String>{
      PaymentStatus.unbilled: 'unbilled',
      PaymentStatus.unpaid: 'unpaid',
      PaymentStatus.partial: 'partial',
      PaymentStatus.paid: 'paid',
    };

    test('toWire matches the stored string', () {
      for (final entry in wires.entries) {
        expect(entry.key.toWire, entry.value);
      }
    });

    test('fromWire round-trips every value and rejects unknown/null', () {
      for (final entry in wires.entries) {
        expect(PaymentStatus.fromWire(entry.value), entry.key);
      }
      expect(PaymentStatus.fromWire('refunded'), isNull);
      expect(PaymentStatus.fromWire(null), isNull);
    });
  });
}
