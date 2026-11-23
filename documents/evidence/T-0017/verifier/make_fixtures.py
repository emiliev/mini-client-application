import os, shutil, sys

S = sys.argv[1]
shutil.rmtree(S, ignore_errors=True)

F = {
# 1: feature -> feature (nested domain layout, double quotes, multi-line show)
"ff/feature/comics/comics_list/pubspec.yaml": "name: comics_list\ndependencies:\n  mc_x:\n    path: ../../../utility/mc_x\n",
"ff/feature/comics/comics_list/lib/comics_list.dart": "export 'package:comics_list/src/flow/comics_list_flow.dart' show ComicsListFlow;\n",
"ff/feature/comics/comics_list/lib/src/flow/comics_list_flow.dart": "import \"package:characters_details/characters_details.dart\"\n    show CharactersDetailsFlow;\nclass ComicsListFlow {}\n",
"ff/feature/characters/characters_details/pubspec.yaml": "name: characters_details\n",
"ff/feature/characters/characters_details/lib/characters_details.dart": "export 'package:characters_details/src/flow/characters_details_flow.dart' show CharactersDetailsFlow;\n",
"ff/utility/mc_x/pubspec.yaml": "name: mc_x\n",
"ff/utility/mc_x/lib/mc_x.dart": "\n",
# 1b: feature -> feature via pubspec dev dep only
"ffpub/feature/a/a_one/pubspec.yaml": "name: a_one\ndev_dependencies:\n  b_two:\n    path: ../../b/b_two\n",
"ffpub/feature/b/b_two/pubspec.yaml": "name: b_two\n",
# 1c: utility -> feature, import from a test file only
"uf/utility/mc_y/pubspec.yaml": "name: mc_y\n",
"uf/utility/mc_y/test/y_test.dart": "import 'package:shop_cart/shop_cart.dart';\n",
"uf/feature/shop/shop_cart/pubspec.yaml": "name: shop_cart\n",
# 2: src import from another package (utility -> utility src, nested path)
"src/utility/mc_a/pubspec.yaml": "name: mc_a\ndependencies:\n  mc_b:\n    path: ../mc_b\n",
"src/utility/mc_a/lib/src/a.dart": "import 'package:mc_b/src/internal/secret.dart' show Secret;\n",
"src/utility/mc_b/pubspec.yaml": "name: mc_b\n",
"src/utility/mc_b/lib/src/internal/secret.dart": "class Secret {}\n",
# 2b: export of another package's src from a barrel
"srcexp/utility/mc_c/pubspec.yaml": "name: mc_c\n",
"srcexp/utility/mc_c/lib/mc_c.dart": "export 'package:mc_b/src/internal/secret.dart';\n",
"srcexp/utility/mc_b/pubspec.yaml": "name: mc_b\n",
# 4: barrel exporting a bloc (show), a DI initializer (show), a page (whole file)
"barrel/feature/comics/comics_detail/pubspec.yaml": "name: comics_detail\n",
"barrel/feature/comics/comics_detail/lib/comics_detail.dart": (
    "export 'package:comics_detail/src/flow/comics_detail_flow.dart' show ComicsDetailFlow;\n"
    "export 'package:comics_detail/src/presentation/bloc/comics_detail_bloc.dart'\n"
    "    show ComicsDetailEvent, ComicsDetailBloc;\n"
    "export 'package:comics_detail/src/di/di_initializer.dart' show ComicsDetailDIInitializer;\n"
    "export 'package:comics_detail/src/presentation/page/comics_detail_page.dart';\n"),
# 4b: bypass attempts: relative export, hide combinator
"barrel2/feature/comics/comics_x/pubspec.yaml": "name: comics_x\n",
"barrel2/feature/comics/comics_x/lib/comics_x.dart": (
    "export 'src/presentation/bloc/comics_x_bloc.dart' show ComicsXBloc;\n"
    "export 'package:comics_x/src/presentation/page/comics_x_page.dart' hide Unused;\n"),
# 4d: R4 bypass: every forbidden export written as a relative URI (the `dart create` barrel idiom)
"barrel3/feature/comics/comics_y/pubspec.yaml": "name: comics_y\n",
"barrel3/feature/comics/comics_y/lib/comics_y.dart": (
    "export 'src/flow/comics_y_flow.dart' show ComicsYFlow;\n"
    "export 'src/presentation/bloc/comics_y_bloc.dart' show ComicsYBloc;\n"
    "export 'src/presentation/page/comics_y_page.dart';\n"
    "export 'src/di/di_initializer.dart' show ComicsYDIInitializer;\n"),
# --- re-verification (873500c) ---
# 4e: wildcard export (package: and relative), even of a flow file
"wild/feature/comics/comics_w/pubspec.yaml": "name: comics_w\n",
"wild/feature/comics/comics_w/lib/comics_w.dart": (
    "export 'package:comics_w/src/flow/comics_w_flow.dart';\n"
    "export 'src/presentation/comics_w_stuff.dart';\n"),
"wild/feature/comics/comics_w/lib/src/presentation/comics_w_stuff.dart": "class ComicsWBloc {}\nclass ComicsWPage {}\nclass Helper {}\n",
# 4f: conditional-import alternatives: feature -> feature and src/ via `if (...)`
"cond/feature/a/a_cond/pubspec.yaml": "name: a_cond\n",
"cond/feature/a/a_cond/lib/src/use.dart": (
    "import 'package:mc_u/mc_u.dart'\n"
    "    if (dart.library.io) 'package:b_cond/b_cond.dart'\n"
    "    if (dart.library.js_interop) 'package:mc_u/src/web.dart';\n"),
"cond/feature/b/b_cond/pubspec.yaml": "name: b_cond\n",
"cond/utility/mc_u/pubspec.yaml": "name: mc_u\n",
# 4g: RouteTargets getter / nullable getter / field returning non-Flow
"rtget/app/wiring/w_wiring/pubspec.yaml": "name: w_wiring\n",
"rtget/app/wiring/w_wiring/lib/src/routes/route_targets.dart": (
    "abstract interface class RouteTargets {\n"
    "  CharsFlow get chars;\n"
    "  CharsPage get page;\n"
    "  Widget? get maybe;\n"
    "  CharsFlow? optionalFlow();\n"
    "}\n"),
# 4h: no false positive: relative exports with show of a flow and a navigator
"okrel/feature/comics/comics_ok/pubspec.yaml": "name: comics_ok\n",
"okrel/feature/comics/comics_ok/lib/comics_ok.dart": (
    "export 'src/flow/comics_ok_flow.dart' show ComicsOkFlow;\n"
    "export 'package:comics_ok/src/navigator/comics_ok_navigator.dart' show ComicsOkNavigator;\n"),
# 4c: R15 route library in nested wiring importing a feature barrel
"r15/app/wiring/universe_wiring/pubspec.yaml": "name: universe_wiring\n",
"r15/app/wiring/universe_wiring/lib/src/routes/characters_routes.dart": (
    "import 'package:characters_list/characters_list.dart';\n"
    "import 'package:go_router/go_router.dart';\n\n"
    "@TypedGoRoute<CharactersRoute>(path: '/characters')\nclass CharactersRoute {}\n"),
"r15/feature/characters/characters_list/pubspec.yaml": "name: characters_list\n",
# 2c: bypass: relative import into another package's src
"src2/feature/d/d_one/pubspec.yaml": "name: d_one\n",
"src2/feature/d/d_one/lib/src/use.dart": "import '../../../../../utility/mc_b/lib/src/secret.dart';\n",
"src2/utility/mc_b/pubspec.yaml": "name: mc_b\n",
}
for rel, body in F.items():
    path = os.path.join(S, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(body)
print(len(F), "files")
