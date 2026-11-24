import 'package:di_sample/src/clock.dart';
import 'package:injectable/injectable.dart';

/// A badge with a caller-supplied label (a factory parameter).
@injectable
class Badge {
  Badge(@factoryParam this.label, this._clock);

  final String? label;
  final Clock _clock;

  String render() => '[$label ${_clock.now().year}]';
}
