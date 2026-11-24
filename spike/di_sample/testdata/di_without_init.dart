// T-0028-AC4 negative fixture: an "init" file whose @InjectableInit was
// removed, so the config generator emits nothing. Not part of any library.
import 'package:get_it/get_it.dart';

Future<void> init(GetIt getIt, String? environment) async {}
