import 'package:flutter_test/flutter_test.dart';

import 'package:health_app/data/health_repository.dart';
import 'package:health_app/models/gym.dart';
import 'package:health_app/state/gym_store.dart';
import 'package:health_app/state/health_store.dart';

void main() {
  // A Wednesday.
  var now = DateTime(2026, 10, 14, 18, 0);
  late InMemoryHealthRepository repo;
  late HealthStore health;
  late GymStore gym;

  const card = GymMembership(
    gym: 'Iron Works',
    memberName: 'Sam Lee',
    memberNumber: 'IW-0042',
    plan: 'Monthly',
    code: '0042123456',
    format: CardFormat.code128,
  );

  setUp(() async {
    now = DateTime(2026, 10, 14, 18, 0);
    repo = InMemoryHealthRepository();
    health = HealthStore(repo, clock: () => now);
    await health.load();
    gym = GymStore(health);
    await gym.load();
  });

  Future<GymStore> reloaded() async {
    final again = GymStore(health);
    await again.load();
    return again;
  }

  group('membership', () {
    test('starts empty', () {
      expect(gym.membership, isNull);
      expect(gym.visits, isEmpty);
    });

    test('is saved and survives a restart', () async {
      await gym.saveMembership(
        card.copyWith(expires: DateTime(2027, 1, 31), notes: 'Locker 12'),
      );

      final again = await reloaded();

      expect(again.membership, gym.membership);
      expect(again.membership?.expires, DateTime(2027, 1, 31));
      expect(again.membership?.format, CardFormat.code128);
    });

    test('can be removed', () async {
      await gym.saveMembership(card);
      await gym.saveMembership(null);

      expect((await reloaded()).membership, isNull);
    });

    test('knows when it has expired', () {
      final today = DateTime(2026, 10, 14);
      expect(card.isExpired(today), isFalse);
      expect(
        card.copyWith(expires: DateTime(2026, 10, 13)).isExpired(today),
        isTrue,
      );
      expect(
        card.copyWith(expires: DateTime(2026, 10, 14)).isExpired(today),
        isFalse,
      );
    });

    test('a membership saved by a newer app with an odd format reads', () {
      final read = GymMembership.fromJson({
        'gym': 'Iron Works',
        'code': '123',
        'format': 'holographic',
      });
      expect(read?.format, CardFormat.code128);
      expect(GymMembership.fromJson('junk'), isNull);
    });
  });

  group('checking in', () {
    test('logs a visit, once per visit', () async {
      expect(await gym.checkIn(), isTrue);
      now = now.add(const Duration(minutes: 30));
      expect(await gym.checkIn(), isFalse);

      expect(gym.visits, [DateTime(2026, 10, 14, 18, 0)]);
      expect(gym.checkedInToday, isTrue);
      expect(gym.justCheckedIn, isTrue);
    });

    test('a later visit the same day counts again', () async {
      await gym.checkIn();
      now = now.add(GymStore.sameVisit + const Duration(minutes: 1));

      expect(await gym.checkIn(), isTrue);
      expect(gym.visits, hasLength(2));
    });

    test('visits survive a restart, newest first', () async {
      await gym.checkIn();
      now = DateTime(2026, 10, 15, 7, 0);
      await gym.checkIn();

      final again = await reloaded();

      expect(again.visits, [
        DateTime(2026, 10, 15, 7, 0),
        DateTime(2026, 10, 14, 18, 0),
      ]);
      expect(again.lastVisit, DateTime(2026, 10, 15, 7, 0));
    });

    test('a visit can be removed', () async {
      await gym.checkIn();

      await gym.removeVisit(DateTime(2026, 10, 14, 18, 0));

      expect(gym.visits, isEmpty);
      expect(gym.checkedInToday, isFalse);
    });
  });

  group('stats', () {
    Future<void> visitOn(DateTime at) async {
      now = at;
      await gym.checkIn();
    }

    test('counts this week (from Monday) and this month', () async {
      await visitOn(DateTime(2026, 9, 30, 9)); // last month
      await visitOn(DateTime(2026, 10, 9, 9)); // last week
      await visitOn(DateTime(2026, 10, 12, 9)); // Monday
      await visitOn(DateTime(2026, 10, 14, 9));

      expect(gym.thisWeek, 2);
      expect(gym.thisMonth, 3);
      expect(gym.total, 4);
    });

    test('a streak counts weeks in a row with a visit', () async {
      await visitOn(DateTime(2026, 9, 15, 9)); // then a week without
      await visitOn(DateTime(2026, 10, 1, 9));
      await visitOn(DateTime(2026, 10, 8, 9));
      await visitOn(DateTime(2026, 10, 14, 9));

      expect(gym.weekStreak, 3);
    });

    test('a streak holds until this week ends without a visit', () async {
      await visitOn(DateTime(2026, 10, 1, 9));
      await visitOn(DateTime(2026, 10, 8, 9));
      now = DateTime(2026, 10, 14, 9);

      expect(gym.weekStreak, 2);
    });

    test('visits are kept for a few years only', () async {
      await visitOn(DateTime(2022, 1, 1, 9));
      await visitOn(DateTime(2026, 10, 14, 9));

      final again = await reloaded();

      expect(again.visits, [DateTime(2026, 10, 14, 9)]);
    });
  });

  test(
    'a visit logged "in the future" (clock moved back) does not block',
    () async {
      await gym.checkIn();
      now = now.subtract(const Duration(hours: 3));

      expect(gym.justCheckedIn, isFalse);
      expect(await gym.checkIn(), isTrue);
    },
  );

  test('when its data could not be read, it saves nothing over it', () async {
    await repo.saveDocument(GymStore.docKey, {'visits': 'not a list'});
    final broken = _ThrowingLoad(health);
    await broken.load();

    expect(broken.readable, isFalse);
    expect(await broken.checkIn(), isFalse);
    expect(broken.visits, isEmpty);
    await expectLater(broken.saveMembership(card), throwsStateError);
  });

  test('Erase All clears it', () async {
    await gym.saveMembership(card);
    await gym.checkIn();

    gym.reset();

    expect(gym.membership, isNull);
    expect(gym.visits, isEmpty);
  });
}

/// A gym store whose saved data can't be read.
class _ThrowingLoad extends GymStore {
  _ThrowingLoad(super.health);

  @override
  Future<Map<String, Object?>?> readDocument() async =>
      throw const FormatException('damaged');
}
