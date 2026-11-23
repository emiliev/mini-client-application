import 'package:mc_prelude/mc_prelude.dart';
import 'package:test/test.dart';

Result<int, String> _divide(int a, int b) =>
    b == 0 ? failure('Cannot divide by zero') : success(a ~/ b);

void main() {
  group('T-0017-AC5 Result', () {
    test('T-0017-AC5 fold applies the success branch', () {
      final sut = _divide(6, 3);

      final actual = sut.fold((int s) => 's$s', (String f) => 'f$f');

      expect(actual, 's2');
    });

    test('T-0017-AC5 fold applies the failure branch', () {
      final sut = _divide(1, 0);

      final actual = sut.fold((int s) => 's$s', (String f) => 'f$f');

      expect(actual, 'fCannot divide by zero');
    });

    test('T-0017-AC5 success and failure expose value, equality, hashCode', () {
      final ok = success<int, String>(1) as Success<int, String>;
      final bad = failure<int, String>('x') as Failure<int, String>;

      expect(ok.value, 1);
      expect(bad.value, 'x');
      expect(ok, success<int, String>(1));
      expect(ok.hashCode, success<int, String>(1).hashCode);
      expect(ok, isNot(success<int, String>(2)));
      expect(ok, isNot(failure<int, int>(1)));
      expect(bad, failure<int, String>('x'));
      expect(bad.hashCode, failure<int, String>('x').hashCode);
      expect(bad, isNot(failure<int, String>('y')));
      expect(ok.toString(), 'Success(1)');
      expect(bad.toString(), 'Failure(x)');
    });

    test('T-0017-AC5 map transforms success, propagates failure', () {
      expect(_divide(6, 3).map((int s) => s * 10), success<int, String>(20));
      expect(
        _divide(1, 0).map((int s) => s * 10),
        failure<int, String>('Cannot divide by zero'),
      );
    });

    test('T-0017-AC5 flatMap chains, propagates failure', () {
      expect(
        _divide(12, 3).flatMap((int s) => _divide(s, 2)),
        success<int, String>(2),
      );
      expect(
        _divide(12, 3).flatMap((int s) => _divide(s, 0)),
        failure<int, String>('Cannot divide by zero'),
      );
      expect(
        _divide(1, 0).flatMap((int s) => _divide(s, 2)),
        failure<int, String>('Cannot divide by zero'),
      );
    });

    test('T-0017-AC5 asyncFlatMap chains, propagates failure', () async {
      final ok = await _divide(
        12,
        3,
      ).asyncFlatMap((int s) async => _divide(s, 2));
      final bad = await _divide(
        1,
        0,
      ).asyncFlatMap((int s) async => _divide(s, 2));

      expect(ok, success<int, String>(2));
      expect(bad, failure<int, String>('Cannot divide by zero'));
    });

    test('T-0017-AC5 forEach runs on success only', () {
      final seen = <int>[];

      _divide(6, 3).forEach(seen.add);
      _divide(1, 0).forEach(seen.add);

      expect(seen, <int>[2]);
    });

    test('T-0017-AC5 getOrElse', () {
      expect(_divide(6, 3).getOrElse(() => -1), 2);
      expect(_divide(1, 0).getOrElse(() => -1), -1);
    });

    test('T-0017-AC5 getOrNull', () {
      expect(_divide(6, 3).getOrNull(), 2);
      expect(_divide(1, 0).getOrNull(), isNull);
    });

    test('T-0017-AC5 fromAsync success', () async {
      final actual = await Result.fromAsync(() async => 7);

      expect(actual, success<int, Exception>(7));
    });

    test('T-0017-AC5 fromAsync keeps a thrown Exception', () async {
      final boom = Exception('boom');

      final actual = await Result.fromAsync<int>(() async => throw boom);

      expect(actual.fold((int _) => null, (Exception e) => e), same(boom));
    });

    test(
      'T-0017-AC5 fromAsync over a thrown Error keeps the message',
      () async {
        final actual = await Result.fromAsync<int>(
          () async => throw StateError('the message'),
        );

        final message = actual.fold((int _) => '', (Exception e) => '$e');
        expect(message, contains('StateError'));
        expect(message, contains('the message'));
      },
    );

    test('T-0017-AC5 fromAction success and thrown values', () {
      final boom = Exception('boom');

      expect(Result.fromAction(() => 1), success<int, Exception>(1));
      expect(
        Result.fromAction<int>(() => throw boom)
            .fold((int _) => null, (Exception e) => e),
        same(boom),
      );
      final error = Result.fromAction<int>(() => throw ArgumentError('bad arg'))
          .fold((int _) => '', (Exception e) => '$e');
      expect(error, contains('ArgumentError'));
      expect(error, contains('bad arg'));
    });

    test('T-0017-AC5 fromNullable', () {
      final missing = Exception('missing');

      expect(
        Result.fromNullable<int>(3, () => missing),
        success<int, Exception>(3),
      );
      expect(
        Result.fromNullable<int>(null, () => missing),
        failure<int, Exception>(missing),
      );
    });

    test('T-0017-AC5 fromPredicate', () {
      final no = Exception('no');

      expect(
        Result.fromPredicate<int>(true, () => 1, () => no),
        success<int, Exception>(1),
      );
      expect(
        Result.fromPredicate<int>(false, () => 1, () => no),
        failure<int, Exception>(no),
      );
    });

    test('T-0017-AC5 guard returns a success', () async {
      final actual = await Result.guard<int, String>(
        () async => 5,
        (Object e) => 'mapped $e',
      );

      expect(actual, success<int, String>(5));
    });

    test('T-0017-AC5 guard maps a thrown Exception', () async {
      final actual = await Result.guard<int, String>(
        () async => throw const FormatException('bad json'),
        (Object e) => 'mapped $e',
      );

      expect(actual, failure<int, String>('mapped FormatException: bad json'));
    });

    test('T-0017-AC5 guard over a TypeError keeps the message', () async {
      final actual = await Result.guard<int, String>(
        () async => <String, Object?>{'a': 'text'}['a']! as int,
        (Object e) => 'mapped: $e',
      );

      final message = actual.fold((int _) => '', (String f) => f);
      expect(message, startsWith('mapped: '));
      expect(message, contains("type 'String' is not a subtype of type 'int'"));
    });
  });
}
