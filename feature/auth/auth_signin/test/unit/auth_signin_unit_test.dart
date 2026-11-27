// T-0066-AC1: the pure logic, as plain unit tests (ADR-0015): the reason
// codes, the form's rules and the failure mapping. Reaches `src/` (R7).
import 'package:auth_signin/src/domain/model/demo_account.dart';
import 'package:auth_signin/src/domain/model/sign_in_failure.dart';
import 'package:auth_signin/src/domain/model/sign_in_reason.dart';
import 'package:auth_signin/src/presentation/form/auth_signin_form.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_forms/mc_forms.dart';

FieldError? _check(String field, String? value) {
  final spec = signInFields().firstWhere((f) => f.name == field);
  return spec.check(value, FormValues({field: value}));
}

void main() {
  group('T-0066-AC1 SignInReason.parse', () {
    test('every reason is read from its own name', () {
      for (final reason in SignInReason.values) {
        expect(SignInReason.parse(reason.name), reason);
      }
      expect(
        SignInReason.values.map((r) => r.name),
        [
          'favourites',
          'readingLists',
          'cart',
          'triviaResults',
          'appearanceSync',
        ],
      );
    });

    test('null, an empty, a wrong-case and a hostile code are no reason', () {
      expect(SignInReason.parse(null), isNull);
      expect(SignInReason.parse(''), isNull);
      expect(SignInReason.parse('Favourites'), isNull);
      expect(SignInReason.parse(' favourites'), isNull);
      expect(
        SignInReason.parse('Your account is locked, call 555-0100'),
        isNull,
      );
    });
  });

  group('T-0066-AC1 the form rules', () {
    test('the email is required, and blank counts as empty', () {
      expect(
        _check(SignInFields.email, ''),
        const FieldError(ValidationCode.required),
      );
      expect(
        _check(SignInFields.email, '   '),
        const FieldError(ValidationCode.required),
      );
      expect(
        _check(SignInFields.email, null),
        const FieldError(ValidationCode.required),
      );
    });

    test('the email must look like an address, judged on the trimmed text', () {
      for (final bad in [
        'reader',
        'reader@',
        '@mini-client.test',
        'a@b',
        'a b@c.d',
        'a@@b.c',
      ]) {
        expect(
          _check(SignInFields.email, bad),
          const FieldError(ValidationCode.patternMismatch),
          reason: bad,
        );
      }
      for (final good in [
        'reader@mini-client.test',
        '  reader@mini-client.test ',
        'READER@MINI-CLIENT.TEST',
        'a+b@c.de',
      ]) {
        expect(_check(SignInFields.email, good), isNull, reason: good);
      }
    });

    test('the password is only required', () {
      expect(
        _check(SignInFields.password, ''),
        const FieldError(ValidationCode.required),
      );
      expect(_check(SignInFields.password, 'x'), isNull);
      expect(_check(SignInFields.password, '  spaces kept  '), isNull);
    });
  });

  group('T-0066-AC1 SignInFailure.of', () {
    test('a 401 is the credentials', () {
      expect(
        SignInFailure.of(const ApiFailure.unauthorized()),
        isA<InvalidCredentials>(),
      );
    });

    test('every other failure is one the user may retry, with its cause', () {
      final causes = <ApiFailure>[
        const ApiFailure.server(500),
        const ApiFailure.offline(),
        const ApiFailure.timeout(),
        const ApiFailure.malformed(),
        const ApiFailure.notFound(),
        const ApiFailure.clientError(400),
        const ApiFailure.unexpected(),
      ];
      for (final cause in causes) {
        final failure = SignInFailure.of(cause);
        expect(failure, isA<SignInUnavailable>(), reason: '$cause');
        expect((failure as SignInUnavailable).cause, same(cause));
      }
    });
  });

  test('T-0066-AC1 demo accounts are equal by value', () {
    const a = DemoAccount(email: 'a@b.c', password: 'p', displayName: 'A');
    const b = DemoAccount(email: 'a@b.c', password: 'p', displayName: 'A');
    const c = DemoAccount(email: 'a@b.c', password: 'q', displayName: 'A');
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
