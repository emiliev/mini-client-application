import 'package:flutter/widgets.dart';

/// What the typed routes build (R15). The route file imports only this
/// interface, so the code generator reads no feature barrel;
/// `RouteTargetsImpl` (unannotated) imports the barrels and is registered by
/// `UniverseWiringDIInitializer`.
abstract interface class RouteTargets {
  /// The characters list: `/characters`.
  Widget characters(BuildContext context);

  /// The details of one character: `/characters/:id`. A placeholder until
  /// `characters_details` exists.
  Widget characterDetails(BuildContext context, int id);
}
