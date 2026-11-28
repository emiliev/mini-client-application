/// What the user reads for a failed request, from the shared error copy.
/// The raw failure text goes to monitoring only (`McBloc`).
String failureMessage(«ApiFailure» failure, «McL10nCoreL10n» core) =>
    switch (failure) {
      «ApiTimeout»() => core.errorTimeout,
      «ApiOffline»() => core.errorNetwork,
      «ApiServer»() => core.errorServer,
      _ => core.errorGeneric,
    };
