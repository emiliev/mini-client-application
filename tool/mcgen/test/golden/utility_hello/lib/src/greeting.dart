// Scaffolded by mcgen from mcgen.yaml; edit the spec or a keep region.

import 'package:mc_hello/src/mood.dart';
import 'package:meta/meta.dart';

/// A greeting for one person.
@immutable
class Greeting {
  /// Creates a [Greeting].
  const Greeting({
    required this.name,
    this.mood = Mood.calm,
    this.excited = false,
  });

  /// Who is greeted.
  final String name;

  final Mood mood;

  final bool excited;

  /// This greeting as text.
  String render() {
    // mcgen:keep greeting.render
    return 'Welcome, Greeting(name: $name, mood: $mood, excited: $excited)';
    // mcgen:end greeting.render
  }
}
