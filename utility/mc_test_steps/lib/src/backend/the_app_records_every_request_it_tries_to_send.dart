import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mc_di/mc_di.dart';
import 'package:mc_test_steps/src/request_attempts.dart';
import 'package:mc_test_utils/mc_test_utils.dart';

/// Usage: the app records every request it tries to send
///
/// A hook at the front of the root `Dio` notes each request as it enters the
/// interceptor chain. `the app tried to send {0} requests for {...}` then
/// tells a request that was never started from one that the auth interceptor
/// rejected (which `the backend received` cannot: it sees neither).
Future<void> theAppRecordsEveryRequestItTriesToSend(
  WidgetTester tester,
) async {
  final attempts = requestsTheAppTriedToSend();
  diContainer<Dio>().interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        attempts.add(
          RecordedRequest(
            method: options.method,
            path: options.uri.path,
            query: options.uri.queryParameters,
          ),
        );
        handler.next(options);
      },
    ),
  );
}
