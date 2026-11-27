import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_l10n_core/mc_l10n_core.dart';

/// What the user reads for a failed request, from the shared error copy.
/// The raw failure text goes to monitoring only (`McBloc`).
String failureMessage(ApiFailure failure, McL10nCoreL10n core) =>
    switch (failure) {
      ApiTimeout() => core.errorTimeout,
      ApiOffline() => core.errorNetwork,
      ApiServer() => core.errorServer,
      _ => core.errorGeneric,
    };
