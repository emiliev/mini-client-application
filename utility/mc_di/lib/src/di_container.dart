import 'package:get_it/get_it.dart';
import 'package:mc_di/src/di_initializer.dart';
import 'package:mc_di/src/recording_get_it.dart';

/// Resolves registered types. `call` maps to get_it's `get`, so only one
/// factory parameter is exposed (as in Tide's `DIContainer`).
abstract class DIContainer {
  T call<T extends Object>({dynamic parameter, String? name});

  bool isRegistered<T extends Object>({String? name});
}

/// The root container. Resolves against whatever [initializeDIContainer]
/// last published; before that it is empty.
final DIContainer diContainer = _GetItContainer(() => _root);

GetIt _root = GetIt.asNewInstance();
bool _published = false;
bool _initializing = false;

/// Runs [initializers] in order and publishes the result as the root
/// container.
///
/// Transactional: registrations go to a staging container, which replaces the
/// root only when every initializer succeeded. If one throws, the staging
/// container is discarded (disposing what it created), the root is unchanged,
/// and the error is rethrown, so a retry registers each type exactly once.
///
/// Production init never resets: a second call after success throws. Tests
/// isolate themselves with [resetDIContainer].
Future<DIContainer> initializeDIContainer(
  List<McDIInitializer> initializers,
) async {
  if (_published) {
    throw StateError(
      'The DI container is already initialised. Production code never '
      'resets it; tests call resetDIContainer() in setUp.',
    );
  }
  if (_initializing) {
    throw StateError('initializeDIContainer is already running.');
  }
  _initializing = true;
  final staged = GetIt.asNewInstance();
  try {
    for (final initializer in initializers) {
      await initializer.init(staged);
    }
  } catch (_) {
    await staged.reset();
    rethrow;
  } finally {
    _initializing = false;
  }
  _root = staged;
  _published = true;
  return diContainer;
}

/// Empties the root container, disposing its singletons. For test `setUp`
/// only; production init never calls it.
Future<void> resetDIContainer() async {
  if (_initializing) {
    throw StateError(
      'resetDIContainer() was called while initializeDIContainer is running; '
      'await the initialisation first.',
    );
  }
  final previous = _root;
  _root = GetIt.asNewInstance();
  _published = false;
  await previous.reset();
}

/// Declares that a child container needs [T] from the root container
/// (R17). The child gets a forwarding registration, so `T` resolves to the
/// root's registration (the root singleton, for a singleton; factory
/// parameters are passed on). The forwarder reads the current root on every
/// resolve, so it follows [resetDIContainer] and re-initialisation.
class RootImport<T extends Object> {
  const RootImport({this.name});

  /// The root registration's instance name, if it has one.
  final String? name;

  void _forward(GetIt root, GetIt child) {
    if (!root.isRegistered<T>(instanceName: name)) {
      throw StateError(
        'RootImport<$T>${name == null ? '' : '(name: $name)'} is not '
        'registered in the root container.',
      );
    }
    // Reads the current root at resolve time (a reset in between is seen)
    // and passes both factory parameters on.
    child.registerFactoryParam<T, Object?, Object?>(
      (Object? param1, Object? param2) =>
          _root.get<T>(instanceName: name, param1: param1, param2: param2),
      instanceName: name,
    );
  }

  @override
  String toString() => 'RootImport<$T>';
}

/// A scope of its own: it sees only what its initializers registered and
/// what its [RootImport]s forward from the root. Types registered here are
/// invisible to the root and to other child containers.
class ChildDIContainer implements DIContainer {
  ChildDIContainer._(this._getIt, this._recorded);

  final GetIt _getIt;
  final List<RecordedRegistration> _recorded;

  @override
  T call<T extends Object>({dynamic parameter, String? name}) =>
      _getIt<T>(param1: parameter, instanceName: name);

  @override
  bool isRegistered<T extends Object>({String? name}) =>
      _getIt.isRegistered<T>(instanceName: name);

  /// Resolves every registration the initializers made (plan 01 §4.5), so a
  /// missing dependency fails here instead of at first use. Factories that
  /// take parameters are skipped. Throws a [StateError] naming the registered
  /// type and the underlying error, which names the missing dependency.
  Future<void> debugResolveAll() async {
    for (final registration in _recorded) {
      final resolve = registration.resolve;
      if (resolve == null) {
        continue;
      }
      try {
        await resolve();
      } on Object catch (error) {
        throw StateError(
          'debugResolveAll: resolving $registration failed: $error',
        );
      }
    }
  }

  /// Disposes what this container registered. The root is untouched.
  Future<void> dispose() => _getIt.reset();
}

/// Creates a child container over the current root container.
///
/// Throws a [StateError] naming `T` when a [RootImport] has no root
/// registration. If an initializer throws, the half-built child is disposed.
Future<ChildDIContainer> createChildContainer({
  List<RootImport<Object>> rootImports = const <RootImport<Object>>[],
  List<McDIInitializer> initializers = const <McDIInitializer>[],
}) async {
  final child = GetIt.asNewInstance();
  final recording = RecordingGetIt(child);
  try {
    for (final import in rootImports) {
      import._forward(_root, child);
    }
    for (final initializer in initializers) {
      await initializer.init(recording);
    }
  } catch (_) {
    await child.reset();
    rethrow;
  }
  return ChildDIContainer._(child, recording.recorded);
}

class _GetItContainer implements DIContainer {
  const _GetItContainer(this._getIt);

  final GetIt Function() _getIt;

  @override
  T call<T extends Object>({dynamic parameter, String? name}) =>
      _getIt()<T>(param1: parameter, instanceName: name);

  @override
  bool isRegistered<T extends Object>({String? name}) =>
      _getIt().isRegistered<T>(instanceName: name);
}
