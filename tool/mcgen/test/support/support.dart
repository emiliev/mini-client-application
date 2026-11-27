// Shared helpers for mcgen's tests. Nothing here depends on the working
// directory: paths come from the package's own location.

import 'dart:io';
import 'dart:isolate';

import 'package:mcgen/mcgen.dart';
import 'package:path/path.dart' as p;

/// tool/mcgen.
final String mcgenDir = p.dirname(
  p.dirname(
    Isolate.resolvePackageUriSync(Uri.parse('package:mcgen/mcgen.dart'))!
        .toFilePath(),
  ),
);

/// The repository checkout tool/mcgen is in.
final String repoRoot = p.dirname(p.dirname(mcgenDir));

String fixture(String rel) => p.join(mcgenDir, 'test', 'fixtures', rel);

String readFixture(String rel) => File(fixture(rel)).readAsStringSync();

/// The reference spec.
String get helloSpec => readFixture('utility_hello/mcgen.yaml');

/// A fresh temp root, deleted after the test. [tag] names the directory so
/// two roots in one test have different absolute paths.
Directory tempRoot(String tag) {
  final d = Directory.systemTemp.createTempSync('mc-T-0065-$tag-');
  return Directory(d.resolveSymbolicLinksSync());
}

/// Writes [text] as `<root>/<rel>`.
File writeFile(Directory root, String rel, String text) {
  final f = File(p.join(root.path, rel));
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(text);
  return f;
}

String readFile(Directory root, String rel) =>
    File(p.join(root.path, rel)).readAsStringSync();

/// A root holding the reference spec at utility/mc_hello.
Directory helloRoot(String tag, {String? spec}) {
  final root = tempRoot(tag);
  writeFile(root, 'utility/mc_hello/mcgen.yaml', spec ?? helloSpec);
  return root;
}

class Run {
  Run(this.code, this.out, this.err);

  final int code;
  final String out;
  final String err;

  @override
  String toString() => 'exit $code\n--- out\n$out--- err\n$err';
}

/// Runs mcgen in process.
Run mcgen(List<String> args, {String? cwd}) {
  final out = StringBuffer();
  final err = StringBuffer();
  final code = runMcgen(args, out: out, err: err, cwd: cwd ?? mcgenDir);
  return Run(code, '$out', '$err');
}

/// Every file under [dir] (relative) -> its bytes as a string.
Map<String, String> snapshot(String dir) => {
  for (final rel in listTree(dir))
    rel: File(p.join(dir, rel)).readAsStringSync(),
};

/// The schema, config and a generator, for tests that skip the CLI.
SpecSchema get schema =>
    SpecSchema.load(p.join(mcgenDir, 'schema', 'mcgen-1.json'));

McgenConfig get config => ToolLayout(mcgenDir).loadConfig();
