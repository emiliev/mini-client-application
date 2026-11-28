// The skeleton of a new form/wizard module (`options.skeleton`): working
// first writes of the files a module owns, so a spec alone gives a module that
// compiles, passes its BDD and keeps the exemplars' guards. They are `owned:`
// from then on. An exemplar sets none of it (its own files are hand-built).
//
// The shape is the exemplars': a `WizardController` over text fields (a form
// is a wizard of one step), one write to a path, pinned to the session epoch,
// the flow result and the server's verdicts mapped to the field they name.

import 'package:mcgen/src/core/emit.dart';
import 'package:mcgen/src/core/ir/code.dart';
import 'package:mcgen/src/core/ir/dart_ir.dart';
import 'package:mcgen/src/core/naming.dart';
import 'package:mcgen/src/emit/feature_form_wizard/model.dart';
import 'package:mcgen/src/emit/feature_form_wizard/skeleton_build.dart';
import 'package:mcgen/src/emit/feature_form_wizard/skeleton_templates.dart';
import 'package:mcgen/src/emit/feature_form_wizard/skeleton_tests.dart';
import 'package:mcgen/src/emit/feature_form_wizard/text.dart';

/// Names the skeleton defines (they are in `options.types`).
Set<String> skeletonDefines(FwModel m) {
  final sk = m.skeleton;
  if (sk == null) return const {};
  return {sk.resultName, '${m.pascal}StepPage'};
}

const _flutterMaterial = 'package:flutter/material.dart';

/// Declares [text] as one library at [path], owned after its first write.
void _lib(
  EmitContext ctx,
  String path,
  String text, {
  List<String> imports = const [],
  List<String> parts = const [],
  String? partOf,
  String? defines,
  String? doc,
}) {
  ctx.library(
    DartLibrary(
      path,
      imports: imports,
      parts: parts,
      partOf: partOf,
      decls: [RawDecl(Code(templateRefs(text)), name: defines, doc: doc)],
    ),
    owned: true,
  );
}

void emitSkeleton(EmitContext ctx, FwModel m) {
  final sk = m.skeleton!;
  final v = skeletonVars(m);
  final module = m.module;
  final stem = m.stem;
  String uri(String p) => 'package:$module/src/$p';
  final resultUri = uri('domain/model/${sk.resultFile}');
  final repoUri = uri('domain/repository/${stem}_repository.dart');
  final formUri = uri('presentation/form/${stem}_form.dart');
  final blocUri = uri('presentation/bloc/${stem}_bloc.dart');
  final l10nUri = uri('l10n/${m.l10nFile}.dart');
  final messagesUri = uri('presentation/widget/messages.dart');

  _lib(
    ctx,
    'lib/src/domain/model/${sk.resultFile}',
    tpl(resultIdTemplate, v),
    defines: sk.resultName,
    doc:
        sk.resultDoc ??
        "An item's id in this feature's own vocabulary: the flow's result once\n"
            'it is saved, so the barrel exports it. Features never share types\n'
            '(plan 01 §4.3).\n'
            '\n'
            'An extension type: a `String` at run time, but not interchangeable with\n'
            'other ids at compile time.',
  );
  _lib(
    ctx,
    'lib/src/domain/repository/${stem}_repository.dart',
    tpl(repositoryTemplate, v),
    imports: [
      'package:dio/dio.dart',
      'package:injectable/injectable.dart',
      'package:mc_api_auth/mc_api_auth.dart',
      'package:mc_api_client/mc_api_client.dart',
      'package:mc_api_errors/mc_api_errors.dart',
      'package:mc_prelude/mc_prelude.dart',
      resultUri,
    ],
    defines: '${m.pascal}Repository',
  );
  _lib(
    ctx,
    'lib/src/presentation/form/${stem}_form.dart',
    tpl(formTemplate, v),
    imports: ['package:mc_forms/mc_forms.dart'],
    defines: '${m.pascal}Fields',
  );
  ctx.symbols
    ..define('${m.pascal}Steps', formUri)
    ..define('serverError', formUri)
    ..define('${m.camel}Steps', formUri)
    ..define('${m.camel}BodyOf', formUri);
  final bloc = 'lib/src/presentation/bloc/${stem}_bloc.dart';
  ctx.library(
    DartLibrary(
      bloc,
      parts: ['${stem}_event.dart', '${stem}_state.dart'],
      imports: [
        'dart:async',
        'package:bloc/bloc.dart',
        'package:injectable/injectable.dart',
        'package:mc_api_errors/mc_api_errors.dart',
        'package:mc_bloc_kit/mc_bloc_kit.dart',
        'package:mc_forms/mc_forms.dart',
        'package:mc_monitoring/mc_monitoring.dart',
        'package:mc_prelude/mc_prelude.dart',
        'package:mc_session/mc_session.dart',
        resultUri,
        repoUri,
        uri('flow/${stem}_flow_state.dart'),
        formUri,
      ],
      decls: [
        RawDecl(Code(tpl(blocTemplate, v)), name: '${m.pascal}Bloc'),
      ],
    ),
    owned: true,
  );
  for (final (suffix, template) in [
    ('event', eventTemplate),
    ('state', stateTemplate),
  ]) {
    ctx.library(
      DartLibrary(
        'lib/src/presentation/bloc/${stem}_$suffix.dart',
        partOf: '${stem}_bloc.dart',
        decls: [
          RawDecl(
            Code(tpl(template, v)),
            name: '${m.pascal}${pascalCase(suffix)}',
          ),
        ],
      ),
      owned: true,
    );
  }
  ctx.symbols
    ..define('${m.pascal}Opening', blocUri)
    ..define('${m.pascal}Editing', blocUri)
    ..define('${m.pascal}SessionEnded', blocUri);
  _lib(
    ctx,
    'lib/src/presentation/widget/messages.dart',
    tpl(messagesTemplate, {
      ...v,
      'cases': _messageCases(m),
      'fallback': '${m.camel}${sk.fields.first.pascal}Refused',
    }),
    imports: [
      l10nUri,
      formUri,
      'package:mc_api_errors/mc_api_errors.dart',
      'package:mc_forms/mc_forms.dart',
      'package:mc_l10n_core/mc_l10n_core.dart',
    ],
  );
  ctx.symbols
    ..define('failureMessage', messagesUri)
    ..define('fieldErrorMessage', messagesUri);
  _lib(
    ctx,
    'lib/src/presentation/page/${stem}_step_page.dart',
    tpl(pageTemplate, {...v, 'step_cases': _stepCases(m)}),
    imports: [
      _flutterMaterial,
      'package:flutter_bloc/flutter_bloc.dart',
      l10nUri,
      blocUri,
      formUri,
      messagesUri,
      resultUri,
      'package:mc_ds_buttons/mc_ds_buttons.dart',
      'package:mc_ds_feedback/mc_ds_feedback.dart',
      'package:mc_ds_forms/mc_ds_forms.dart',
      'package:mc_ds_layout/mc_ds_layout.dart',
      'package:mc_ds_navigation/mc_ds_navigation.dart',
      'package:mc_feature_flow/mc_feature_flow.dart',
      'package:mc_forms/mc_forms.dart',
      'package:mc_l10n_core/mc_l10n_core.dart',
    ],
    defines: '${m.pascal}StepPage',
  );
  emitSkeletonTests(ctx, m, v);
  emitSkeletonBuild(ctx, m);
}

/// The values every template reads.
Map<String, String> skeletonVars(FwModel m) {
  final sk = m.skeleton!;
  final fields = sk.fields;
  String indent(String s, int n) =>
      s.split('\n').map((l) => l.isEmpty ? l : '${' ' * n}$l').join('\n');
  final anyTrim = fields.any((f) => f.trim);
  final stepsText = StringBuffer();
  for (final step in sk.steps) {
    if (step.isReview) {
      stepsText.writeln(
        '  const WizardStep(${m.pascal}Steps.${camelCase(step.id)}, fields: []),',
      );
      continue;
    }
    stepsText
      ..writeln('  WizardStep(')
      ..writeln('    ${m.pascal}Steps.${camelCase(step.id)},')
      ..writeln('    fields: [');
    for (final f in step.fields) {
      final rules = [
        if (f.required)
          f.trim
              ? '_trimmed(Validators.required<String>())'
              : 'Validators.required<String>()',
        if (f.max != null)
          f.trim
              ? '_trimmed(Validators.maxLength(${f.max}))'
              : 'Validators.maxLength(${f.max})',
      ];
      stepsText
        ..writeln('      FieldDef<String>(')
        ..writeln('        ${m.pascal}Fields.${f.name},')
        ..writeln("        initial: '',");
      if (rules.isNotEmpty) {
        stepsText.writeln('        validators: [${rules.join(', ')}],');
      }
      stepsText.writeln('      ),');
    }
    stepsText
      ..writeln('    ],')
      ..writeln('  ),');
  }
  final body = StringBuffer();
  for (final f in fields) {
    body.writeln(
      "  '${f.bodyKey}': (values.get<String>(${m.pascal}Fields.${f.name}) ?? '')${f.trim ? '.trim()' : ''},",
    );
  }
  for (final e in sk.extra.entries) {
    body.writeln("  '${e.key}': ${e.value},");
  }
  return {
    'module': m.module,
    'stem': m.stem,
    'Pascal': m.pascal,
    'camel': m.camel,
    'Result': sk.resultName,
    'Repository': '${m.pascal}Repository',
    'Navigator': m.navigator,
    'Flow': m.flow,
    'L10n': m.l10nClass,
    'path': sk.path,
    'idKey': sk.idKey,
    'step_count': '${sk.steps.length}',
    'field_consts': indent(
      [
        for (final f in fields) "static const String ${f.name} = '${f.name}';",
      ].join('\n'),
      2,
    ),
    'of_parameter': [
      for (final f in fields) "    '${f.bodyKey}' => ${f.name},\n",
    ].join(),
    'step_consts': indent(
      [
        for (final s in sk.steps)
          "static const String ${camelCase(s.id)} = '${s.id}';",
      ].join('\n'),
      2,
    ),
    'steps': stepsText.toString(),
    'body': body.toString(),
    // `_trimmed` is written only for a form that trims.
    'trimmed_fn': anyTrim
        ? '/// Applies [rule] to the trimmed text, as the backend trims a value.\n'
              'Validator<String> _trimmed(Validator<String> rule) =>\n'
              '    (value) => rule(value?.trim());\n\n'
        : '',
    'review_locals': sk.steps.any((s) => s.isReview)
        ? '    final core = McL10nCoreL10n.of(context);\n'
              '    final failure = wizard.failure;\n'
        : '',
    'tag': m.archTag,
    'noun': sk.noun,
  };
}

String _messageCases(FwModel m) {
  final sk = m.skeleton!;
  final b = StringBuffer();
  for (final f in sk.fields) {
    final key = '${m.camel}${f.pascal}';
    b.writeln('  ${m.pascal}Fields.${f.name} => switch (error.code) {');
    if (f.required) {
      b.writeln('    ValidationCode.required => l10n.${key}Required,');
    }
    if (f.max != null) {
      b.writeln(
        '    ValidationCode.tooLong => l10n.${key}TooLong(error.max!.toInt()),',
      );
    }
    b.writeln('    _ => l10n.${key}Refused,');
    b.writeln('  },');
  }
  return b.toString();
}

String _stepCases(FwModel m) {
  final sk = m.skeleton!;
  final b = StringBuffer();
  for (final (i, step) in sk.steps.indexed) {
    b.writeln('        $i => [');
    if (step.isReview) {
      for (final f in sk.fields) {
        b.writeln('          Text(');
        b.writeln(
          "            '\${l10n.${m.camel}${f.pascal}Label}: \${form.fieldOf<String>(${m.pascal}Fields.${f.name}).value ?? ''}',",
        );
        b.writeln(
          "            key: const ValueKey<String>('${m.module}.review.${f.name}'),",
        );
        b.writeln('          ),');
      }
      b.writeln('          if (wizard.isCompleting)');
      b.writeln(
        '            McLoading(key: savingKey, semanticLabel: l10n.${m.camel}Saving),',
      );
      b.writeln('          if (failure != null)');
      b.writeln(
        '            Text(failureMessage(failure, core), key: saveErrorKey),',
      );
    } else {
      for (final (j, f) in step.fields.indexed) {
        if (j > 0) b.writeln('          const McGap.xs(),');
        b.writeln('          McFormTextField(');
        b.writeln(
          '            field: form.fieldOf<String>(${m.pascal}Fields.${f.name}),',
        );
        b.writeln('            label: l10n.${m.camel}${f.pascal}Label,');
        b.writeln(
          '            onChanged: (v) =>\n'
          '                bloc.add(${m.pascal}Event.fieldChanged(${m.pascal}Fields.${f.name}, v)),',
        );
        b.writeln(
          '            onTouched: () =>\n'
          '                bloc.add(const ${m.pascal}Event.touched(${m.pascal}Fields.${f.name})),',
        );
        b.writeln(
          '            errorMessage: (e) =>\n'
          '                fieldErrorMessage(${m.pascal}Fields.${f.name}, e, l10n),',
        );
        b.writeln('            textInputAction: TextInputAction.next,');
        b.writeln('          ),');
      }
    }
    b.writeln('        ],');
  }
  return b.toString();
}
