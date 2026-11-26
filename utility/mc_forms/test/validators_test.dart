import 'package:mc_forms/mc_forms.dart';
import 'package:test/test.dart';

FieldError? _err(ValidationCode code, {num? min, num? max}) =>
    FieldError(code, min: min, max: max);

void main() {
  group('T-0045-AC1 required', () {
    final rule = Validators.required<Object>();

    test('T-0045-AC1 null, blank and empty values fail', () {
      expect(rule(null), _err(ValidationCode.required));
      expect(rule(''), _err(ValidationCode.required));
      expect(rule('   '), _err(ValidationCode.required));
      expect(rule(<int>[]), _err(ValidationCode.required));
      expect(rule(<String, int>{}), _err(ValidationCode.required));
    });

    test('T-0045-AC1 present values pass', () {
      expect(rule('a'), isNull);
      expect(rule(0), isNull);
      expect(rule(false), isNull);
      expect(rule([1]), isNull);
      expect(rule({'a': 1}), isNull);
    });
  });

  group('T-0045-AC1 minLength', () {
    final rule = Validators.minLength(3);

    test('T-0045-AC1 shorter text fails with the limit', () {
      expect(rule('ab'), _err(ValidationCode.tooShort, min: 3));
    });

    test('T-0045-AC1 the boundary and longer text pass', () {
      expect(rule('abc'), isNull);
      expect(rule('abcd'), isNull);
    });

    test('T-0045-AC1 empty and null pass (optional field)', () {
      expect(rule(''), isNull);
      expect(rule(null), isNull);
    });
  });

  group('T-0045-AC1 maxLength', () {
    final rule = Validators.maxLength(3);

    test('T-0045-AC1 longer text fails with the limit', () {
      expect(rule('abcd'), _err(ValidationCode.tooLong, max: 3));
    });

    test('T-0045-AC1 the boundary, shorter, empty and null pass', () {
      expect(rule('abc'), isNull);
      expect(rule('a'), isNull);
      expect(rule(''), isNull);
      expect(rule(null), isNull);
    });
  });

  group('T-0045-AC1 pattern', () {
    final rule = Validators.pattern(RegExp('[a-z]+'));

    test('T-0045-AC1 text that does not match fails', () {
      expect(rule('ABC'), _err(ValidationCode.patternMismatch));
    });

    test('T-0045-AC1 the whole text must match, not a prefix or a part', () {
      expect(rule('abc1'), _err(ValidationCode.patternMismatch));
      expect(rule('1abc'), _err(ValidationCode.patternMismatch));
      expect(rule('abc'), isNull);
    });

    test('T-0045-AC1 empty and null pass', () {
      expect(rule(''), isNull);
      expect(rule(null), isNull);
    });

    test('T-0045-AC1 a custom code is used', () {
      final custom = Validators.pattern(
        RegExp(r'\d+'),
        code: ValidationCode.invalid,
      );
      expect(custom('x'), _err(ValidationCode.invalid));
    });
  });

  group('T-0045-AC1 range', () {
    final rule = Validators.range<int>(min: 1, max: 5);

    test('T-0045-AC1 below and above fail with both limits', () {
      expect(rule(0), _err(ValidationCode.belowMin, min: 1, max: 5));
      expect(rule(6), _err(ValidationCode.aboveMax, min: 1, max: 5));
    });

    test('T-0045-AC1 both limits are inclusive, null passes', () {
      expect(rule(1), isNull);
      expect(rule(5), isNull);
      expect(rule(3), isNull);
      expect(rule(null), isNull);
    });

    test('T-0045-AC1 a one-sided range checks only that side', () {
      expect(Validators.range<int>(min: 1)(1000), isNull);
      expect(Validators.range<int>(max: 1)(-1000), isNull);
      expect(
        Validators.range<double>(min: 0.5)(0.25),
        _err(ValidationCode.belowMin, min: 0.5),
      );
      expect(
        Validators.range<double>(max: 0.5)(0.75),
        _err(ValidationCode.aboveMax, max: 0.5),
      );
    });

    test('T-0045-AC1 an inverted range is a programming error', () {
      expect(() => Validators.range<int>(min: 5, max: 1), throwsArgumentError);
    });
  });

  group('T-0045-AC1 compose', () {
    test('T-0045-AC1 the first failing rule wins, in order', () {
      final rule = Validators.compose<String>([
        Validators.required(),
        Validators.minLength(3),
        Validators.maxLength(5),
      ]);
      expect(rule(''), _err(ValidationCode.required));
      expect(rule('ab'), _err(ValidationCode.tooShort, min: 3));
      expect(rule('abcdef'), _err(ValidationCode.tooLong, max: 5));
      expect(rule('abcd'), isNull);
    });

    test('T-0045-AC1 with two failing rules the earlier one is reported', () {
      final rule = Validators.compose<String>([
        Validators.minLength(10),
        Validators.maxLength(5),
      ]);
      expect(rule('abcdefg'), _err(ValidationCode.tooShort, min: 10));
    });

    test('T-0045-AC1 an empty composition passes', () {
      expect(Validators.compose<String>([])('x'), isNull);
    });

    test('T-0045-AC1 the list is copied: later edits do not change it', () {
      final rules = <Validator<String>>[Validators.minLength(3)];
      final rule = Validators.compose(rules);
      rules.clear();
      expect(rule('a'), _err(ValidationCode.tooShort, min: 3));
    });
  });

  group('T-0045-AC1 cross-field', () {
    final values = FormValues({'password': 'secret', 'confirm': 'secret'});

    test('T-0045-AC1 matches passes when the fields are equal', () {
      expect(Validators.matches<String>('password')('secret', values), isNull);
    });

    test('T-0045-AC1 matches fails with mismatch when they differ', () {
      expect(
        Validators.matches<String>('password')('other', values),
        _err(ValidationCode.mismatch),
      );
    });

    test('T-0045-AC1 matches on a missing value fails against a value', () {
      expect(
        Validators.matches<String>('password')(null, values),
        _err(ValidationCode.mismatch),
      );
    });

    test('T-0045-AC1 requiredWhen requires only when the condition holds', () {
      final rule = Validators.requiredWhen<String>(
        (v) => v.get<bool>('other') ?? false,
      );
      expect(
        rule(null, FormValues({'other': true})),
        _err(ValidationCode.required),
      );
      expect(rule('x', FormValues({'other': true})), isNull);
      expect(rule(null, FormValues({'other': false})), isNull);
    });

    test('T-0045-AC1 an unknown field name is an ArgumentError', () {
      expect(
        () => Validators.matches<String>('nope')('a', values),
        throwsArgumentError,
      );
    });
  });

  group('T-0045-AC1 typed error codes', () {
    test('T-0045-AC1 every rule reports a ValidationCode, never a string', () {
      final errors = <FieldError?>[
        Validators.required<String>()(null),
        Validators.minLength(2)('a'),
        Validators.maxLength(1)('ab'),
        Validators.pattern(RegExp('a'))('b'),
        Validators.range<int>(min: 1)(0),
        Validators.range<int>(max: 1)(2),
        Validators.matches<String>('x')('a', FormValues({'x': 'b'})),
      ];
      expect(errors.map((e) => e!.code).toSet(), {
        ValidationCode.required,
        ValidationCode.tooShort,
        ValidationCode.tooLong,
        ValidationCode.patternMismatch,
        ValidationCode.belowMin,
        ValidationCode.aboveMax,
        ValidationCode.mismatch,
      });
    });

    test('T-0045-AC1 FieldError has value equality and a readable string', () {
      expect(
        const FieldError(ValidationCode.tooShort, min: 2),
        const FieldError(ValidationCode.tooShort, min: 2),
      );
      expect(
        const FieldError(ValidationCode.tooShort, min: 2).hashCode,
        const FieldError(ValidationCode.tooShort, min: 2).hashCode,
      );
      expect(
        const FieldError(ValidationCode.tooShort, min: 2),
        isNot(const FieldError(ValidationCode.tooShort, min: 3)),
      );
      expect(
        const FieldError(ValidationCode.tooLong, max: 2),
        isNot(const FieldError(ValidationCode.tooLong, max: 3)),
      );
      expect(
        const FieldError(ValidationCode.tooLong),
        isNot(const FieldError(ValidationCode.required)),
      );
      expect(
        const FieldError(ValidationCode.required).toString(),
        contains('required'),
      );
    });
  });

  group('T-0045-AC1 FieldDef', () {
    test('T-0045-AC1 validators run before cross validators, first wins', () {
      final def = FieldDef<String>(
        'confirm',
        validators: [Validators.required()],
        crossValidators: [Validators.matches('password')],
      );
      final values = FormValues({'password': 'a', 'confirm': ''});
      expect(def.check('', values), _err(ValidationCode.required));
      expect(def.check('b', values), _err(ValidationCode.mismatch));
      expect(def.check('a', values), isNull);
    });
  });

  group('T-0045-AC1 FormValues', () {
    test('T-0045-AC1 a snapshot is read-only and typed', () {
      final source = {'a': 1};
      final values = FormValues(source);
      source['a'] = 2;
      expect(values.get<int>('a'), 1);
      expect(() => values.toMap()['a'] = 3, throwsUnsupportedError);
      expect(() => values.get<String>('a'), throwsA(isA<TypeError>()));
    });
  });
}
