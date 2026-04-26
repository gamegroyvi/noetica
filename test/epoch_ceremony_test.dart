import 'package:flutter_test/flutter_test.dart';

import 'package:noetica/data/models.dart';
import 'package:noetica/features/self/epoch_ceremony.dart';

void main() {
  LifeAxis axis(String id) => LifeAxis(
        id: id,
        name: id,
        symbol: '•',
        position: 0,
        createdAt: DateTime(2024, 1, 1),
      );

  AxisScore score(String id, double v) => AxisScore(
        axis: axis(id),
        value: v,
        rawXp: 0,
      );

  group('EpochCeremony.pentagonFull', () {
    test('is false while any axis is under 95', () {
      expect(
        EpochCeremony.pentagonFull([
          score('a', 100),
          score('b', 100),
          score('c', 94.9),
          score('d', 100),
          score('e', 100),
        ]),
        isFalse,
      );
    });

    test('is true once every axis is at or above 95', () {
      expect(
        EpochCeremony.pentagonFull([
          score('a', 95),
          score('b', 100),
          score('c', 98.5),
          score('d', 100),
          score('e', 99),
        ]),
        isTrue,
      );
    });

    test('refuses to trigger for under-3-axis pentagons', () {
      expect(
        EpochCeremony.pentagonFull([
          score('a', 100),
          score('b', 100),
        ]),
        isFalse,
      );
    });
  });
}
