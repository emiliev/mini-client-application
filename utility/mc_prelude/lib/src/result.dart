import 'dart:async';

/// Errors as values. Every member of Tide's `Result` (utility layer article),
/// plus [guard] and a message-preserving [fromAsync] / [fromAction]
/// (plan 01 D-07).
sealed class Result<S, F> {
  const Result._();

  /// The only way to get a value out of a [Result]: applies [ifSuccess] or
  /// [ifFailure].
  B fold<B>(B Function(S s) ifSuccess, B Function(F f) ifFailure);

  /// Transforms the success value; a failure is propagated unchanged.
  Result<S2, F> map<S2>(S2 Function(S s) f) =>
      fold((S s) => success(f(s)), failure);

  /// Like [map], but [f] returns a [Result] because the transformation can fail.
  Result<S2, F> flatMap<S2>(Result<S2, F> Function(S s) f) => fold(f, failure);

  /// Asynchronous [flatMap].
  Future<Result<S2, F>> asyncFlatMap<S2>(
    Future<Result<S2, F>> Function(S s) f,
  ) => fold(f, (F error) => Future<Result<S2, F>>.value(failure(error)));

  /// Applies [f] for its side effects when this is a success.
  FutureOr<void> forEach<T>(FutureOr<T> Function(S) f) => fold(f, (_) {});

  /// The success value, or the result of [defaultValue] on a failure.
  S getOrElse(S Function() defaultValue) =>
      fold((S s) => s, (_) => defaultValue());

  /// The success value, or null on a failure.
  S? getOrNull() => fold((S s) => s, (_) => null);

  /// Runs [func]. A thrown [Exception] becomes the failure. A thrown [Error]
  /// becomes an [Exception] whose message keeps the error's type, its message
  /// and the stack trace (Tide kept only type and stack).
  static Future<Result<T, Exception>> fromAsync<T>(
    Future<T> Function() func,
  ) async {
    try {
      return success(await func());
    } on Exception catch (e) {
      return failure(e);
    } on Error catch (e, st) {
      return failure(_errorToException(e, st));
    }
  }

  /// Synchronous [fromAsync].
  static Result<T, Exception> fromAction<T>(T Function() func) {
    try {
      return success(func());
    } on Exception catch (e) {
      return failure(e);
    } on Error catch (e, st) {
      return failure(_errorToException(e, st));
    }
  }

  /// A success with [value], or the failure from [onError] when it is null.
  static Result<T, Exception> fromNullable<T>(
    T? value,
    Exception Function() onError,
  ) => value != null ? success(value) : failure(onError());

  /// A success from [onSuccess] when [condition] holds, else a failure from
  /// [onError].
  static Result<T, Exception> fromPredicate<T>(
    bool condition,
    T Function() onSuccess,
    Exception Function() onError,
  ) => condition ? success(onSuccess()) : failure(onError());

  /// Runs [body], catching every [Exception] **and** [Error] (a JSON-shape
  /// `TypeError` is a failure, as in Tide), and maps what was thrown to a
  /// domain failure with [mapError]. The error is handed over untouched, so
  /// its message survives.
  static Future<Result<T, F>> guard<T, F>(
    Future<T> Function() body,
    F Function(Object error) mapError,
  ) async {
    try {
      return success(await body());
    } on Exception catch (e) {
      return failure(mapError(e));
    } on Error catch (e) {
      return failure(mapError(e));
    }
  }

  static Exception _errorToException(Error e, StackTrace thrownAt) =>
      Exception('${e.runtimeType}: $e\n${e.stackTrace ?? thrownAt}');
}

/// The success case of [Result].
final class Success<S, F> extends Result<S, F> {
  const Success._(this._s) : super._();

  final S _s;

  /// The success value.
  S get value => _s;

  @override
  B fold<B>(B Function(S s) ifSuccess, B Function(F f) ifFailure) =>
      ifSuccess(_s);

  @override
  bool operator ==(Object other) => other is Success && other._s == _s;

  @override
  int get hashCode => _s.hashCode;

  @override
  String toString() => 'Success($_s)';
}

/// The failure case of [Result].
final class Failure<S, F> extends Result<S, F> {
  const Failure._(this._f) : super._();

  final F _f;

  /// The failure value.
  F get value => _f;

  @override
  B fold<B>(B Function(S s) ifSuccess, B Function(F f) ifFailure) =>
      ifFailure(_f);

  @override
  bool operator ==(Object other) => other is Failure && other._f == _f;

  @override
  int get hashCode => _f.hashCode;

  @override
  String toString() => 'Failure($_f)';
}

/// A failed [Result].
Result<S, F> failure<S, F>(F f) => Failure._(f);

/// A successful [Result].
Result<S, F> success<S, F>(S s) => Success._(s);
