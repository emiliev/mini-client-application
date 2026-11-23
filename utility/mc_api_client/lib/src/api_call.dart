import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_prelude/mc_prelude.dart';

/// Runs [body] (a retrofit call, say) and returns the outcome as a value.
/// Anything thrown, a Dio error or a `TypeError` from a bad JSON shape, is
/// mapped by [ApiFailure.from]; nothing escapes.
Future<Result<T, ApiFailure>> apiCall<T>(Future<T> Function() body) =>
    Result.guard<T, ApiFailure>(body, ApiFailure.from);
