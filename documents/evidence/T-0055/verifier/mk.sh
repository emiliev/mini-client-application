#!/bin/bash
set -e
D=<scratch>/proj/app/mini_client/integration_test
mk(){ cat > $D/$1.dart <<EOF
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
$2
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('$1 ran', (t) async { $3 });
}
EOF
}
mk zz_good_test "" "expect(1, 1);"
mk zz_broken_test "" "final int x = 'not an int'; expect(x, 1);"
mk zz_fail_test "" "expect(1, 2);"
mk zz_missingimport_test "import 'package:does_not_exist/nope.dart';" "expect(1,1);"
mk zz_syntax_test "" "expect(1,1)"
ls $D
