/// Registers this feature's types in its flow's own container (Tide's
/// boilerplate shape; plan 01 §3.3).
class {{{pascal}}}DIInitializer extends «McDIInitializer» {
  const {{{pascal}}}DIInitializer() : super(_init);
}

@«InjectableInit»()
FutureOr<«GetIt»> _init(«GetIt» getIt, String? environment) =>
    getIt.init(environment: environment);
