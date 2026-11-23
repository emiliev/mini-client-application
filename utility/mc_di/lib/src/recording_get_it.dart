import 'dart:async';

import 'package:get_it/get_it.dart';

/// One recorded `register*` call: the registered type and how to resolve it.
class RecordedRegistration {
  const RecordedRegistration(this.type, this.instanceName, this.resolve);

  final Type type;
  final String? instanceName;

  /// Resolves the registration once; `null` for factories that need
  /// parameters (they cannot be resolved without arguments).
  final Future<void> Function()? resolve;

  @override
  String toString() =>
      instanceName == null ? '$type' : '$type(name: $instanceName)';
}

/// A [GetIt] that forwards everything to [_inner] and records each
/// `register*` call, so `ChildDIContainer.debugResolveAll` can resolve every
/// registration (plan 01 §4.5). Used only while a child container is built.
class RecordingGetIt implements GetIt {
  RecordingGetIt(this._inner);

  final GetIt _inner;
  final List<RecordedRegistration> recorded = [];

  void _record<T extends Object>(
    String? name,
    Future<void> Function()? resolve,
  ) => recorded.add(RecordedRegistration(T, name, resolve));

  Future<void> Function() _sync<T extends Object>(String? name) =>
      () async => _inner.get<T>(instanceName: name);

  Future<void> Function() _async<T extends Object>(String? name) =>
      () async => _inner.getAsync<T>(instanceName: name);

  @override
  void registerFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) {
    _inner.registerFactory<T>(factoryFunc, instanceName: instanceName);
    _record<T>(instanceName, _sync<T>(instanceName));
  }

  @override
  void registerCachedFactory<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
  }) {
    _inner.registerCachedFactory<T>(factoryFunc, instanceName: instanceName);
    _record<T>(instanceName, _sync<T>(instanceName));
  }

  @override
  void registerFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) {
    _inner.registerFactoryParam<T, P1, P2>(
      factoryFunc,
      instanceName: instanceName,
    );
    _record<T>(instanceName, null);
  }

  @override
  void registerCachedFactoryParam<T extends Object, P1, P2>(
    FactoryFuncParam<T, P1, P2> factoryFunc, {
    String? instanceName,
  }) {
    _inner.registerCachedFactoryParam<T, P1, P2>(
      factoryFunc,
      instanceName: instanceName,
    );
    _record<T>(instanceName, null);
  }

  @override
  void registerFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  }) {
    _inner.registerFactoryAsync<T>(factoryFunc, instanceName: instanceName);
    _record<T>(instanceName, _async<T>(instanceName));
  }

  @override
  void registerCachedFactoryAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
  }) {
    _inner.registerCachedFactoryAsync<T>(
      factoryFunc,
      instanceName: instanceName,
    );
    _record<T>(instanceName, _async<T>(instanceName));
  }

  @override
  void registerFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  }) {
    _inner.registerFactoryParamAsync<T, P1, P2>(
      factoryFunc,
      instanceName: instanceName,
    );
    _record<T>(instanceName, null);
  }

  @override
  void registerCachedFactoryParamAsync<T extends Object, P1, P2>(
    FactoryFuncParamAsync<T, P1?, P2?> factoryFunc, {
    String? instanceName,
  }) {
    _inner.registerCachedFactoryParamAsync<T, P1, P2>(
      factoryFunc,
      instanceName: instanceName,
    );
    _record<T>(instanceName, null);
  }

  @override
  T registerSingleton<T extends Object>(
    T instance, {
    String? instanceName,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    final result = _inner.registerSingleton<T>(
      instance,
      instanceName: instanceName,
      signalsReady: signalsReady,
      dispose: dispose,
    );
    _record<T>(instanceName, _sync<T>(instanceName));
    return result;
  }

  @override
  T registerSingletonIfAbsent<T extends Object>(
    T Function() factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
  }) {
    final result = _inner.registerSingletonIfAbsent<T>(
      factoryFunc,
      instanceName: instanceName,
      dispose: dispose,
    );
    _record<T>(instanceName, _sync<T>(instanceName));
    return result;
  }

  @override
  void registerSingletonWithDependencies<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    required Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
  }) {
    _inner.registerSingletonWithDependencies<T>(
      factoryFunc,
      instanceName: instanceName,
      dependsOn: dependsOn,
      signalsReady: signalsReady,
      dispose: dispose,
    );
    _record<T>(instanceName, _async<T>(instanceName));
  }

  @override
  void registerSingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    Iterable<Type>? dependsOn,
    bool? signalsReady,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
  }) {
    _inner.registerSingletonAsync<T>(
      factoryFunc,
      instanceName: instanceName,
      dependsOn: dependsOn,
      signalsReady: signalsReady,
      dispose: dispose,
      onCreated: onCreated,
    );
    _record<T>(instanceName, _async<T>(instanceName));
  }

  @override
  void registerLazySingleton<T extends Object>(
    FactoryFunc<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
    bool useWeakReference = false,
  }) {
    _inner.registerLazySingleton<T>(
      factoryFunc,
      instanceName: instanceName,
      dispose: dispose,
      onCreated: onCreated,
      useWeakReference: useWeakReference,
    );
    _record<T>(instanceName, _sync<T>(instanceName));
  }

  @override
  void registerLazySingletonAsync<T extends Object>(
    FactoryFuncAsync<T> factoryFunc, {
    String? instanceName,
    DisposingFunc<T>? dispose,
    void Function(T instance)? onCreated,
    bool useWeakReference = false,
  }) {
    _inner.registerLazySingletonAsync<T>(
      factoryFunc,
      instanceName: instanceName,
      dispose: dispose,
      onCreated: onCreated,
      useWeakReference: useWeakReference,
    );
    _record<T>(instanceName, _async<T>(instanceName));
  }

  // Everything below forwards unchanged.

  @override
  void Function(bool pushed)? get onScopeChanged => _inner.onScopeChanged;
  @override
  set onScopeChanged(void Function(bool pushed)? value) =>
      _inner.onScopeChanged = value;

  @override
  bool get allowReassignment => _inner.allowReassignment;
  @override
  set allowReassignment(bool value) => _inner.allowReassignment = value;

  // Test-only switches in get_it; not forwarded, since initializers never
  // set them.
  @override
  bool skipDoubleRegistration = false;

  @override
  bool allowRegisterMultipleImplementationsOfoneType = false;

  @override
  void enableRegisteringMultipleInstancesOfOneType() =>
      _inner.enableRegisteringMultipleInstancesOfOneType();

  @override
  T get<T extends Object>({
    dynamic param1,
    dynamic param2,
    String? instanceName,
    Type? type,
  }) => _inner.get<T>(
    param1: param1,
    param2: param2,
    instanceName: instanceName,
    type: type,
  );

  @override
  T? maybeGet<T extends Object>({
    dynamic param1,
    dynamic param2,
    String? instanceName,
    Type? type,
  }) => _inner.maybeGet<T>(
    param1: param1,
    param2: param2,
    instanceName: instanceName,
    type: type,
  );

  @override
  Future<T> getAsync<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) => _inner.getAsync<T>(
    instanceName: instanceName,
    param1: param1,
    param2: param2,
    type: type,
  );

  @override
  Iterable<T> getAll<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
    String? onlyInScope,
  }) => _inner.getAll<T>(
    param1: param1,
    param2: param2,
    fromAllScopes: fromAllScopes,
    onlyInScope: onlyInScope,
  );

  @override
  Future<Iterable<T>> getAllAsync<T extends Object>({
    dynamic param1,
    dynamic param2,
    bool fromAllScopes = false,
    String? onlyInScope,
  }) => _inner.getAllAsync<T>(
    param1: param1,
    param2: param2,
    fromAllScopes: fromAllScopes,
    onlyInScope: onlyInScope,
  );

  @override
  List<T> findAll<T extends Object>({
    bool includeSubtypes = true,
    bool inAllScopes = false,
    String? onlyInScope,
    bool includeMatchedByRegistrationType = true,
    bool includeMatchedByInstance = true,
    bool instantiateLazySingletons = false,
    bool callFactories = false,
  }) => _inner.findAll<T>(
    includeSubtypes: includeSubtypes,
    inAllScopes: inAllScopes,
    onlyInScope: onlyInScope,
    includeMatchedByRegistrationType: includeMatchedByRegistrationType,
    includeMatchedByInstance: includeMatchedByInstance,
    instantiateLazySingletons: instantiateLazySingletons,
    callFactories: callFactories,
  );

  @override
  T call<T extends Object>({
    String? instanceName,
    dynamic param1,
    dynamic param2,
    Type? type,
  }) => _inner.call<T>(
    instanceName: instanceName,
    param1: param1,
    param2: param2,
    type: type,
  );

  @override
  void releaseInstance(Object instance) => _inner.releaseInstance(instance);

  @override
  ObjectRegistration? findFirstObjectRegistration<T extends Object>({
    Object? instance,
    String? instanceName,
  }) => _inner.findFirstObjectRegistration<T>(
    instance: instance,
    instanceName: instanceName,
  );

  @override
  bool isRegistered<T extends Object>({
    Object? instance,
    String? instanceName,
    Type? type,
  }) => _inner.isRegistered<T>(
    instance: instance,
    instanceName: instanceName,
    type: type,
  );

  @override
  void changeTypeInstanceName<T extends Object>({
    String? instanceName,
    required String newInstanceName,
    T? instance,
  }) => _inner.changeTypeInstanceName<T>(
    instanceName: instanceName,
    newInstanceName: newInstanceName,
    instance: instance,
  );

  @override
  Future<void> reset({bool dispose = true}) => _inner.reset(dispose: dispose);

  @override
  Future<void> resetScope({bool dispose = true}) =>
      _inner.resetScope(dispose: dispose);

  @override
  void pushNewScope({
    void Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
    bool isFinal = false,
  }) => _inner.pushNewScope(
    init: init,
    scopeName: scopeName,
    dispose: dispose,
    isFinal: isFinal,
  );

  @override
  Future<void> pushNewScopeAsync({
    Future<void> Function(GetIt getIt)? init,
    String? scopeName,
    ScopeDisposeFunc? dispose,
  }) => _inner.pushNewScopeAsync(
    init: init,
    scopeName: scopeName,
    dispose: dispose,
  );

  @override
  Future<void> popScope() => _inner.popScope();

  @override
  Future<bool> popScopesTill(String name, {bool inclusive = true}) =>
      _inner.popScopesTill(name, inclusive: inclusive);

  @override
  Future<void> dropScope(String scopeName) => _inner.dropScope(scopeName);

  @override
  bool hasScope(String scopeName) => _inner.hasScope(scopeName);

  @override
  String? get currentScopeName => _inner.currentScopeName;

  @override
  FutureOr<dynamic> resetLazySingleton<T extends Object>({
    T? instance,
    String? instanceName,
    FutureOr<dynamic> Function(T)? disposingFunction,
  }) => _inner.resetLazySingleton<T>(
    instance: instance,
    instanceName: instanceName,
    disposingFunction: disposingFunction,
  );

  @override
  Future<void> resetLazySingletons({
    bool dispose = true,
    bool inAllScopes = false,
    String? onlyInScope,
  }) => _inner.resetLazySingletons(
    dispose: dispose,
    inAllScopes: inAllScopes,
    onlyInScope: onlyInScope,
  );

  @override
  bool checkLazySingletonInstanceExists<T extends Object>({
    String? instanceName,
  }) => _inner.checkLazySingletonInstanceExists<T>(instanceName: instanceName);

  @override
  FutureOr<dynamic> unregister<T extends Object>({
    Object? instance,
    String? instanceName,
    FutureOr<dynamic> Function(T)? disposingFunction,
    bool ignoreReferenceCount = false,
  }) => _inner.unregister<T>(
    instance: instance,
    instanceName: instanceName,
    disposingFunction: disposingFunction,
    ignoreReferenceCount: ignoreReferenceCount,
  );

  @override
  Future<void> allReady({
    Duration? timeout,
    bool ignorePendingAsyncCreation = false,
  }) => _inner.allReady(
    timeout: timeout,
    ignorePendingAsyncCreation: ignorePendingAsyncCreation,
  );

  @override
  Future<void> isReady<T extends Object>({
    Object? instance,
    String? instanceName,
    Duration? timeout,
    Object? callee,
  }) => _inner.isReady<T>(
    instance: instance,
    instanceName: instanceName,
    timeout: timeout,
    callee: callee,
  );

  @override
  bool isReadySync<T extends Object>({
    Object? instance,
    String? instanceName,
  }) => _inner.isReadySync<T>(instance: instance, instanceName: instanceName);

  @override
  bool allReadySync([bool ignorePendingAsyncCreation = false]) =>
      _inner.allReadySync(ignorePendingAsyncCreation);

  @override
  void signalReady(Object? instance) => _inner.signalReady(instance);
}
