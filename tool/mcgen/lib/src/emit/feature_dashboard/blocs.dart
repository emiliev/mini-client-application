// The dashboard's blocs: the shared base, one bloc (with its sealed events
// and its freezed state) per section, the session-dependent section's
// variant, and the paged detail page's bloc.
//
// Tide 5.8: hand-style sealed events with private cases, freezed `sealed`
// states with private cases, monitoring in `McBloc`. The base holds the
// mechanics every section shares (generation guard, once-per-visit view,
// open guard, refresh); a section holds what it fetches and what a tap does.

import 'package:mcgen/src/emit/feature_dashboard/model.dart';
import 'package:mcgen/src/emit/feature_dashboard/text.dart';

const _bloc = 'lib/src/presentation/bloc';

void emitBlocs(Out ctx, DbModel m) {
  ctx.file('$_bloc/${m.sectionBlocFile}', _base(m));
  for (final s in m.sections) {
    final base = '$_bloc/${s.snake}';
    ctx.file(
      '${base}_bloc.dart',
      s.isSession ? _sessionBloc(m, s) : _bloc_(m, s),
    );
    ctx.file(
      '${base}_event.dart',
      s.isSession ? _sessionEvent(m, s) : _event(m, s),
    );
    ctx.file('${base}_state.dart', _state(m, s));
  }
  final d = m.detail;
  if (d != null) {
    ctx.file('$_bloc/open_${d.name}.dart', _openDetail(m, d));
    ctx.file('$_bloc/${d.blocBase}.dart', _detailBloc(m, d));
    ctx.file('$_bloc/${d.stem}_event.dart', _detailEvent(m, d));
    ctx.file('$_bloc/${d.stem}_state.dart', _detailState(m, d));
  }
}

// --- the base --------------------------------------------------------------

String _base(DbModel m) {
  final d = m.doc(
    'base.doc',
    'The shape every section bloc of a dashboard shares (DB archetype,\n'
        'F-0056). One bloc per section, each with its own events and its own\n'
        'freezed state (`loading`, `ready`, `empty`, `failure`, plus what a\n'
        'section adds): this base holds only the mechanics, so the sections\n'
        'behave alike and none can affect another.\n'
        '\n'
        '- **[load]** shows the section\'s loading state, fetches, and shows\n'
        '  `ready`, `empty` or `failure`. **Retry** is a [load] of this section\n'
        '  only. **Pull to refresh** is a [refresh]: the shown state stays until\n'
        '  the answer lands.\n'
        '- **The newest answer wins.** Every load bumps a generation; an answer\n'
        '  is applied only if no load started after it (F-0046 fact 7). [fetch]\n'
        '  may also answer null to drop an answer for a session that is gone.\n'
        '- **`${m.viewedEvent}`** is tracked once per bloc, that is once per\n'
        '  visit of the page, the first time the section is `ready`: not when it\n'
        '  failed or is empty, and after a Retry that succeeds.\n'
        '\n'
        '[E] is the section\'s event type, [S] its state, [T] what it fetches.\n'
        'Pure Dart (R15).',
  );
  return tpl(
    '''
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_prelude/mc_prelude.dart';
import '<<analytics_uri>>';

<<d_guard>>const Duration openGuard = Duration(milliseconds: <<guard_ms>>);

<<d_class>>abstract base class <<Base>><E, S, T> extends McBloc<E, S> {
  <<Base>>(
    super.initialState, {
    required super.monitoring,
    required this.tracker,
    required this.section,
  });

  /// The blocs' analytics port (`mc_analytics`' `Analytics`).
  final AnalyticsTracker tracker;

  /// Which section this is (the analytics `section`).
  final <<Section>> section;

  int _generation = 0;
  bool _viewed = false;
  Timer? _openGuard;
  Object? _openTarget;

  /// The section's data. Null drops the answer without writing any state:
  /// it belongs to something that has changed since (the cart's session).
  Future<Result<T, ApiFailure>?> fetch();

  /// Whether [data] is the section's empty case.
  bool isEmptyData(T data);

  S loadingState();

  S readyState(T data);

  S emptyState();

  S failureState(ApiFailure error);

  /// Loads the section and shows the answer, unless a later load started
  /// meanwhile. With [keepShown] the current state stays until then (pull to
  /// refresh); otherwise the loading state shows at once (first load,
  /// Retry, a new session).
  Future<void> load(Emitter<S> emit, {bool keepShown = false}) async {
    final generation = ++_generation;
    if (!keepShown) {
      emit(loadingState());
    }
    final result = await fetch();
    // Every await is a boundary: only the newest load may write.
    if (result == null || generation != _generation || isClosed) {
      return;
    }
    result.fold((data) {
      if (isEmptyData(data)) {
        emit(emptyState());
        return;
      }
      emit(readyState(data));
      if (!_viewed) {
        _viewed = true;
        tracker.sectionViewed(section);
      }
    }, (error) => emit(failureState(error)));
  }

  /// Pull to refresh: [load] keeping the shown state, then completes [done]
  /// (the refresh control closes), also when a later load won.
  Future<void> refresh(Emitter<S> emit, Completer<void> done) async {
    try {
      await load(emit, keepShown: true);
    } finally {
      done.complete();
    }
  }

  /// False while a hand-over of the same [target] still guards (the second
  /// tap of a double tap); else starts the guard for it. Another target goes
  /// through at once.
  bool startOpenGuard(Object target) {
    if ((_openGuard?.isActive ?? false) && _openTarget == target) {
      return false;
    }
    _openGuard?.cancel();
    _openGuard = Timer(openGuard, () {});
    _openTarget = target;
    return true;
  }

  @override
  Future<void> close() {
    _openGuard?.cancel();
    return super.close();
  }
}
''',
    {
      'analytics_uri': m.uri('domain/model/${m.analyticsFile}'),
      'd_guard': m.doc(
        'base.open_guard',
        'How long after a hand-over a second hand-over of the same item is\n'
            'ignored: the second tap of a double tap (P-089).',
      ),
      'guard_ms': m.text('base.open_guard_ms', '500'),
      'd_class': d,
      'Base': m.sectionBloc,
      'Section': m.section,
    },
  );
}

// --- a list section ----------------------------------------------------------

List<String> _commonImports(DbModel m, DbSection s) => [
  'dart:async',
  'package:bloc/bloc.dart',
  'package:freezed_annotation/freezed_annotation.dart',
  'package:injectable/injectable.dart',
  'package:mc_api_errors/mc_api_errors.dart',
  'package:mc_bloc_kit/mc_bloc_kit.dart',
  'package:mc_monitoring/mc_monitoring.dart',
  'package:mc_prelude/mc_prelude.dart',
  m.uri('domain/model/${m.modelFile}'),
  m.uri('domain/model/${m.analyticsFile}'),
  m.uri('domain/repository/${m.module}_repository.dart'),
  if (s.uses.contains(DbUse.flow)) m.uri('flow/${m.module}_flow_state.dart'),
  if (s.uses.contains(DbUse.navigator))
    m.uri('navigator/${m.module}_navigator.dart'),
  if (s.uses.contains(DbUse.flow) && m.detail != null)
    m.uri('presentation/bloc/open_${m.detail!.name}.dart'),
  if (s.uses.contains(DbUse.clock)) m.uri('domain/model/${m.clockFile}'),
  if (s.uses.contains(DbUse.session)) 'package:mc_session/mc_session.dart',
  m.uri('presentation/bloc/${m.sectionBlocFile}'),
];

/// The constructor parameters and fields a section's dependencies add, in
/// the exemplar's order.
(String, String) _deps(DbModel m, DbSection s) {
  final params = StringBuffer();
  final fields = StringBuffer();
  if (s.uses.contains(DbUse.flow)) {
    params.writeln('    this._flow,');
    fields.writeln(
      '  final FeatureFlowController<${m.flowState}> _flow;',
    );
  }
  if (s.uses.contains(DbUse.navigator)) {
    params.writeln('    this._navigator,');
    fields.writeln('  final ${m.navigator} _navigator;');
  }
  if (s.uses.contains(DbUse.clock)) {
    params.writeln('    this._clock,');
    fields.writeln('  final ${m.clock} _clock;');
  }
  if (s.uses.contains(DbUse.session)) {
    params.writeln('    this._session,');
    fields.writeln('  final SessionReader _session;');
  }
  return (params.toString(), fields.toString());
}

String _bloc_(DbModel m, DbSection s) {
  final (params, fields) = _deps(m, s);
  final retry = m.optionalText('${s.name}.retry_comment');
  final members = s.members == null
      ? ''
      : '\n${keepRegion('${s.name}.members', s.members!, indent: '  ')}\n';
  final fetch =
      s.fetchMethod ??
      '  @override\n'
          '  Future<Result<${s.data}, ApiFailure>> fetch() =>\n'
          '      _repository.${s.fetch}();';
  final top = s.top == null ? '' : '${s.top}\n\n';
  return tpl(
    '''
<<imports>>

part '<<file>>_bloc.freezed.dart';
part '<<file>>_event.dart';
part '<<file>>_state.dart';

<<top>><<d_class>>@injectable
final class <<Bloc>>
    extends <<Base>><<<Event>>, <<State>>, <<data>>> {
  <<Bloc>>(
    this._repository,
<<params>>    AnalyticsTracker tracker,
    Monitoring monitoring,
  ) : super(
        const <<State>>.loading(),
        monitoring: monitoring,
        tracker: tracker,
        section: <<Section>>.<<name>>,
      ) {
    // Idle until the page is shown: the page adds `load` (a visit).
    on<<<Event>>>(_onEvent);
  }

  final <<Repository>> _repository;
<<fields>>
  Future<void> _onEvent(<<Event>> event, Emitter<<<State>>> emit) async {
    switch (event) {
      case _Load():
        await load(emit);
      case _Retry():
<<retry>>        if (state is _Failure) {
          await load(emit);
        }
      case _Refresh(:final done):
        await refresh(emit, done);
      case _Open(:final <<arg>>):
<<open>>
    }
  }
<<members>>
<<fetch>>

  @override
  bool isEmptyData(<<data>> data) => <<empty>>;

  @override
  <<State>> loadingState() => const <<State>>.loading();

  @override
  <<State>> readyState(<<data>> data) => <<State>>.ready(<<ready_args>>);

  @override
  <<State>> emptyState() => const <<State>>.empty();

  @override
  <<State>> failureState(ApiFailure error) => <<State>>.failure(error);
}
''',
    {
      'imports': imports(_commonImports(m, s)),
      'file': s.snake,
      'top': top,
      'd_class': m.doc(
        '${s.name}.doc',
        'The ${s.name} section: loads on its own, and hands a tapped '
            '${words(s.arg)} over.',
      ),
      'Bloc': s.bloc,
      'Base': m.sectionBloc,
      'Event': s.event,
      'State': s.state,
      'Section': m.section,
      'name': s.name,
      'data': s.data,
      'params': params,
      'fields': fields,
      'Repository': m.repository,
      'retry': retry == null
          ? ''
          : '${retry.split('\n').map((l) => '        // $l').join('\n')}\n',
      'arg': s.arg,
      'open': keepRegion(
        '${s.name}.open',
        s.openDefault,
        indent: '        ',
      ),
      'members': members,
      'fetch': fetch,
      'empty': s.emptyWhen,
      'ready_args': s.readyArgs,
    },
  );
}

String words(String camel) => camel
    .replaceAllMapped(RegExp('([A-Z])'), (m) => ' ${m[1]!.toLowerCase()}')
    .trim();

String _event(DbModel m, DbSection s) {
  final e = s.event;
  return tpl(
    '''
part of '<<file>>_bloc.dart';

<<d_class>>sealed class <<Event>> {
  const <<Event>>();

  <<d_load>>const factory <<Event>>.load() = _Load;

  <<d_retry>>const factory <<Event>>.retry() = _Retry;

  <<d_refresh>>const factory <<Event>>.refresh(Completer<void> done) = _Refresh;

  <<d_open>>const factory <<Event>>.open(<<argType>> <<arg>>) = _Open;
}

final class _Load extends <<Event>> {
  const _Load();
}

final class _Retry extends <<Event>> {
  const _Retry();
}

final class _Refresh extends <<Event>> {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _Open extends <<Event>> {
  const _Open(this.<<arg>>);

  final <<argType>> <<arg>>;
}
''',
    {
      'file': s.snake,
      'Event': e,
      'd_class': m.doc(
        '${s.name}.event.doc',
        'What the ${s.name} section asks for (Tide\'s sealed events).',
      ),
      'd_load': m.memberDoc(
        '${s.name}.event.load',
        'The first load: the page adds it once it is shown (F-0056 §1).',
      ),
      'd_retry': m.memberDoc(
        '${s.name}.event.retry',
        'Retry after a failure: loads this section again, and only this one.',
      ),
      'd_refresh': m.memberDoc(
        '${s.name}.event.refresh',
        'Pull to refresh; [done] completes when the answer arrived.',
      ),
      'd_open': m.memberDoc(
        '${s.name}.event.open',
        'A ${words(s.arg)} was tapped.',
      ),
      'argType': s.argType,
      'arg': s.arg,
    },
  );
}

String _state(DbModel m, DbSection s) {
  final extra = s.isSession
      ? '''

  <<d_signed_out>>const factory <<State>>.signedOut() = _SignedOut;

  <<d_signing_in>>const factory <<State>>.signingIn() = _SigningIn;'''
      : '';
  return tpl(
    '''
part of '<<file>>_bloc.dart';

<<d_class>>@Freezed(copyWith: false)
sealed class <<State>> with _\$<<State>> {
  <<d_loading>>const factory <<State>>.loading() = _Loading;

  <<d_ready>>const factory <<State>>.ready(<<ready_params>>) = _Ready;

  <<d_empty>>const factory <<State>>.empty() = _Empty;

  <<d_failure>>@Implements<McFailureState>()
  const factory <<State>>.failure(ApiFailure error, {StackTrace? stackTrace}) =
      _Failure;$extra
}
''',
    {
      'file': s.snake,
      'State': s.state,
      'd_class': m.doc(
        '${s.name}.state.doc',
        'A section\'s state (Tide\'s shape, R16).',
      ),
      'd_loading': m.memberDoc('${s.name}.state.loading', ''),
      'd_ready': m.memberDoc('${s.name}.state.ready', ''),
      'd_empty': m.memberDoc('${s.name}.state.empty', ''),
      'd_failure': m.memberDoc('${s.name}.state.failure', ''),
      'd_signed_out': m.memberDoc(
        '${s.name}.state.signed_out',
        'Nobody is signed in: the summary is hidden and nothing is requested.',
      ),
      'd_signing_in': m.memberDoc(
        '${s.name}.state.signing_in',
        'The app is signing someone in for this section.',
      ),
      'ready_params': s.readyParams,
    },
  );
}

// --- the session section -----------------------------------------------------

String _sessionBloc(DbModel m, DbSection s) {
  final (params, fields) = _deps(m, s);
  return tpl(
    '''
<<imports>>

part '<<file>>_bloc.freezed.dart';
part '<<file>>_event.dart';
part '<<file>>_state.dart';

<<d_class>>@injectable
final class <<Bloc>>
    extends <<Base>><<<Event>>, <<State>>, <<data>>> {
  <<Bloc>>(
    this._repository,
<<params>>    AnalyticsTracker tracker,
    Monitoring monitoring,
  ) : super(
        const <<State>>.loading(),
        monitoring: monitoring,
        tracker: tracker,
        section: <<Section>>.<<name>>,
      ) {
    on<<<Event>>>(_onEvent);
    // Idle until the page is shown: the page adds `load` (a visit), and only
    // then does the section follow the session.
  }

  final <<Repository>> _repository;
<<fields>>
  /// From the visit's start (the first `load`): a page built under another
  /// screen does not follow the session, so it loads nothing.
  StreamSubscription<AuthStatus>? _sessionChanges;

  /// The session epoch the section last started to show (loaded, or showed
  /// signed out for). A session event for this same epoch changes nothing.
  int? _shownEpoch;

  Future<void> _onEvent(
    <<Event>> event,
    Emitter<<<State>>> emit,
  ) async {
    switch (event) {
      case _Load():
        _sessionChanges ??= _session.authState.listen(
          (_) => add(const _SessionChanged()),
        );
        await _show(emit);
      case _Retry():
        if (state is _Failure) {
          await _show(emit);
        }
      case _Refresh(:final done):
        if (_session.isSignedIn) {
          await refresh(emit, done);
        } else {
          done.complete();
        }
      case _SessionChanged():
        if (_session.epoch != _shownEpoch) {
          await _show(emit);
        }
      case _SignIn():
        await _signIn(emit);
      case _Open():
        if (startOpenGuard(<<ItemKind>>.<<open_kind>>)) {
          tracker.itemTapped(section, <<ItemKind>>.<<open_kind>>, '<<open_id>>');
          _navigator.<<open_call>>();
        }
    }
  }

  <<d_show>>Future<void> _show(Emitter<<<State>>> emit) async {
    _shownEpoch = _session.epoch;
    if (!_session.isSignedIn) {
      // A read still on its way is dropped by [fetch]: its session is gone.
      emit(const <<State>>.signedOut());
      return;
    }
    await load(emit);
  }

  Future<void> _signIn(Emitter<<<State>>> emit) async {
    // One sign-in at a time: a second tap finds it signing in.
    if (state is! _SignedOut) {
      return;
    }
    emit(const <<State>>.signingIn());
    await _navigator.requestSignIn();
    if (isClosed) {
      return;
    }
    // The session, not the answer, decides. A sign-in reloaded the section
    // already if its event came first; otherwise it loads now, once.
    if (_session.epoch != _shownEpoch || state is _SigningIn) {
      await _show(emit);
    }
  }

  @override
  Future<Result<<<data>>, ApiFailure>?> fetch() async {
    final epoch = _session.epoch;
    final result = await _repository.<<fetch>>(epoch: epoch);
    if (_session.epoch == epoch) {
      return result;
    }
    // An answer for a session that is gone is dropped, and the section
    // reloads for the session now current. A sign-in as the same user starts
    // a new epoch without an `authState` event, so nothing else would.
    // Not after the store was left: a closed bloc takes no events (and has
    // nothing to show).
    if (!isClosed) {
      add(const _SessionChanged());
    }
    return null;
  }

  @override
  bool isEmptyData(<<data>> data) => <<empty>>;

  @override
  <<State>> loadingState() => const <<State>>.loading();

  @override
  <<State>> readyState(<<data>> data) => <<State>>.ready(<<ready_args>>);

  @override
  <<State>> emptyState() => const <<State>>.empty();

  @override
  <<State>> failureState(ApiFailure error) => <<State>>.failure(error);

  @override
  Future<void> close() {
    // Not awaited: a cancel future is made in the root zone and never
    // completes under a widget test's fake async (F-0052 trap 1).
    unawaited(_sessionChanges?.cancel());
    return super.close();
  }
}
''',
    {
      'imports': imports(_commonImports(m, s)),
      'file': s.snake,
      'd_class': m.doc(
        '${s.name}.doc',
        'The ${s.name} section: the signed-in user\'s data, which opens.\n'
            '\n'
            '- **Signed out** the section is hidden: it offers to sign in and\n'
            '  sends nothing. A tap asks the app (`requestSignIn()`) and waits;\n'
            '  whatever the answer, the session decides what shows next.\n'
            '- **The session decides.** It follows `SessionReader.authState`: a\n'
            '  sign-in, a sign-out or a user switch anywhere reloads the section\n'
            '  for the session now current, once per session epoch. An answer\n'
            '  that arrives for an older epoch also reloads it.\n'
            '- **Every await is a session boundary** (F-0040 fact 21): a read\n'
            '  started for one session and answered under another is dropped\n'
            '  before any state is written, and the request itself is pinned to\n'
            '  its epoch (T-0050).',
      ),
      'Bloc': s.bloc,
      'Base': m.sectionBloc,
      'Event': s.event,
      'State': s.state,
      'Section': m.section,
      'ItemKind': m.itemKind,
      'name': s.name,
      'data': s.data,
      'params': params,
      'fields': fields,
      'Repository': m.repository,
      'd_show': m.memberDoc(
        '${s.name}.show_doc',
        'Shows the section for the session now current: signed out, or its data.',
      ),
      'fetch': s.fetch ?? '',
      'empty': s.emptyWhen,
      'ready_args': s.readyArgs,
      'open_kind': s.openKind,
      'open_call': s.openCall,
      'open_id': s.openId,
    },
  );
}

String _sessionEvent(DbModel m, DbSection s) => tpl(
  '''
part of '<<file>>_bloc.dart';

<<d_class>>sealed class <<Event>> {
  const <<Event>>();

  <<d_load>>const factory <<Event>>.load() = _Load;

  <<d_retry>>const factory <<Event>>.retry() = _Retry;

  <<d_refresh>>const factory <<Event>>.refresh(Completer<void> done) = _Refresh;

  <<d_sign_in>>const factory <<Event>>.signIn() = _SignIn;

  <<d_open>>const factory <<Event>>.open() = _Open;
}

final class _Load extends <<Event>> {
  const _Load();
}

final class _Retry extends <<Event>> {
  const _Retry();
}

final class _Refresh extends <<Event>> {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _SignIn extends <<Event>> {
  const _SignIn();
}

final class _Open extends <<Event>> {
  const _Open();
}

<<d_changed>>final class _SessionChanged extends <<Event>> {
  const _SessionChanged();
}
''',
  {
    'file': s.snake,
    'Event': s.event,
    'd_class': m.doc(
      '${s.name}.event.doc',
      'What the ${s.name} section asks for (Tide\'s sealed events).',
    ),
    'd_load': m.memberDoc(
      '${s.name}.event.load',
      'The first load: the page adds it once it is shown (F-0056 §1).',
    ),
    'd_retry': m.memberDoc(
      '${s.name}.event.retry',
      'Retry after a failure: loads this section again, and only this one.',
    ),
    'd_refresh': m.memberDoc(
      '${s.name}.event.refresh',
      'Pull to refresh; [done] completes when the answer arrived (at once\n'
          'while signed out: there is nothing to reload).',
    ),
    'd_sign_in': m.memberDoc(
      '${s.name}.event.sign_in',
      'Signed out, the offer to sign in was tapped.',
    ),
    'd_open': m.memberDoc(
      '${s.name}.event.open',
      'The section was tapped: it opens.',
    ),
    'd_changed': m.doc(
      '${s.name}.event.session_changed',
      'Internal: `SessionReader.authState` changed (a sign-in, a sign-out or a\n'
          'user switch, here or anywhere else in the app).',
    ),
  },
);

// --- the detail page's bloc ------------------------------------------------------

String _openDetail(DbModel m, DbDetail d) => tpl(
  '''
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import '<<flow_state_uri>>';

<<d_ext>>extension <<Open>>InFlow on FeatureFlowController<<<FlowState>>> {
  <<d_method>>void open<<Pascal>>(<<Open>> <<name>>) {
    if (state.<<name>> == null) {
      update((s) => s.copyWith(<<name>>: <<name>>));
    }
  }
}
''',
  {
    'flow_state_uri': m.uri('flow/${m.module}_flow_state.dart'),
    'FlowState': m.flowState,
    'Open': d.open,
    'Pascal': d.pascal,
    'name': d.name,
    'd_ext': m.doc(
      'detail.open.doc',
      'A ${d.name} opens as a page of this flow, not a route (plan 01 §4.1).',
    ),
    'd_method': m.memberDoc(
      'detail.open.method',
      'Opens [${d.name}]\'s page above the home. One at a time: a second tap\n'
          'while the page slides in keeps the first (F-0031 fact 9).',
    ),
  },
);

String _detailBloc(DbModel m, DbDetail d) {
  final open = d.open;
  return tpl(
    '''
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:mc_api_errors/mc_api_errors.dart';
import 'package:mc_bloc_kit/mc_bloc_kit.dart';
import 'package:mc_monitoring/mc_monitoring.dart';
import 'package:mc_paging/mc_paging.dart';
import '<<id_uri>>';
import '<<model_uri>>';
import '<<analytics_uri>>';
import '<<repository_uri>>';
import '<<flow_state_uri>>';
import '<<navigator_uri>>';
import '<<base_uri>>'
    show openGuard;

part '<<file>>.freezed.dart';
part '<<stem>>_event.dart';
part '<<stem>>_state.dart';

<<d_size>>const int <<name>>PageSize = <<page_size>>;

<<d_class>>@injectable
final class <<Bloc>> extends McBloc<<<Event>>, <<State>>> {
  <<Bloc>>(
    this._repository,
    this._flow,
    this._navigator,
    this._tracker,
    Monitoring monitoring,
  ) : _<<name>> = (_flow.state.<<name>> ?? _flow.state.root<<Pascal>>)!,
      super(const <<State>>.loading(), monitoring: monitoring) {
    _paging = PagingController<<<item>>>(
      fetcher: (request) =>
          _repository.<<fetch_page>>(_<<name>>.id, request),
      // The controller reports outside any handler; an event brings each
      // state back into the bloc, so only a handler emits.
      onState: (page) => add(_PageChanged(page)),
      limit: <<name>>PageSize,
    );
    on<<<Event>>>(_onEvent);
    add(const <<Event>>.load());
    if (_<<name>>.name == null) {
      add(const _ResolveName());
    }
  }

  final <<Repository>> _repository;
  final FeatureFlowController<<<FlowState>>> _flow;
  final <<Navigator>> _navigator;
  final AnalyticsTracker _tracker;
  final <<Open>> _<<name>>;
  late final PagingController<<<item>>> _paging;
  Timer? _openGuard;
  int? _openTarget;

  Future<void> _onEvent(
    <<Event>> event,
    Emitter<<<State>>> emit,
  ) async {
    switch (event) {
      case _Load():
        await _paging.loadFirst();
      case _LoadMore():
        await _paging.loadMore();
      case _Retry():
        await _paging.retry();
      case _Refresh(:final done):
        try {
          await _paging.refresh();
        } finally {
          done.complete();
        }
      case _Open(:final <<arg>>):
        if (_startOpenGuard(<<arg>>.id.value)) {
          _tracker.itemTapped(
            <<Section>>.<<analytics>>,
            <<ItemKind>>.<<open_kind>>,
            '\${<<arg>>.id.value}',
          );
          _navigator.<<open_call>>(<<arg>>.id);
        }
      case _PageChanged(:final page):
        emit(_toState(page));
      case _ResolveName():
        await _resolveName();
    }
  }

  /// No items yet: an unknown <<name>> is "not found", another failure the
  /// full-page error, anything else still loading. With items, or at the
  /// end of an empty <<name>>, the grid shows the page (its footer carries a
  /// later page's failure, with Retry).
  static <<State>> _toState(PagedState<<<item>>> page) =>
      switch (page) {
        PagedState(items: [], failure: ApiNotFound()) =>
          const <<State>>.notFound(),
        PagedState(items: [], failure: final failure?) =>
          <<State>>.failure(failure),
        PagedState(items: [], hasReachedEnd: false) =>
          const <<State>>.loading(),
        _ => <<State>>.success(page),
      };

  Future<void> _resolveName() async {
    final result = await _repository.<<lookup>>();
    if (isClosed) {
      return;
    }
    final id = _<<name>>.id;
    final name = result
        .getOrElse(() => const [])
        .where((c) => c.id == id)
        .map((c) => c.name)
        .firstOrNull;
    if (name != null) {
      _flow.update((s) => _named(s, id, name));
    }
  }

  static <<FlowState>> _named(
    <<FlowState>> s,
    <<IdType>> id,
    String name,
  ) => switch (s) {
    <<FlowState>>(<<name>>: <<Open>>(id: final open))
        when open == id =>
      s.copyWith(
        <<name>>: <<Open>>(id: id, name: name),
      ),
    <<FlowState>>(root<<Pascal>>: <<Open>>(id: final root))
        when root == id =>
      s.copyWith(
        root<<Pascal>>: <<Open>>(id: id, name: name),
      ),
    // The page left meanwhile: nothing to title.
    _ => s,
  };

  bool _startOpenGuard(int target) {
    if ((_openGuard?.isActive ?? false) && _openTarget == target) {
      return false;
    }
    _openGuard?.cancel();
    _openGuard = Timer(openGuard, () {});
    _openTarget = target;
    return true;
  }

  @override
  Future<void> close() {
    _openGuard?.cancel();
    _paging.dispose();
    return super.close();
  }
}
''',
    {
      'id_uri': m.uri('domain/model/${m.idOf(d.id)!.file}'),
      'model_uri': m.uri('domain/model/${m.modelFile}'),
      'analytics_uri': m.uri('domain/model/${m.analyticsFile}'),
      'repository_uri': m.uri('domain/repository/${m.module}_repository.dart'),
      'flow_state_uri': m.uri('flow/${m.module}_flow_state.dart'),
      'navigator_uri': m.uri('navigator/${m.module}_navigator.dart'),
      'base_uri': m.uri('presentation/bloc/${m.sectionBlocFile}'),
      'file': d.blocBase,
      'stem': d.stem,
      'arg': d.arg,
      'd_size': m.doc(
        'detail.page_size',
        'Items per request: ${d.pageSize}, the contract\'s default page.',
      ),
      'd_class': m.doc(
        'detail.doc',
        'The ${d.name} page\'s bloc: one ${d.name}\'s ${d.items} through a\n'
            '[PagingController] (offset and limit: load, load more at the end of the\n'
            'list, refresh, retry), and a tapped item handed over to the app.',
      ),
      'Bloc': d.bloc,
      'Event': d.event,
      'State': d.state,
      'Open': open,
      'Pascal': d.pascal,
      'name': d.name,
      'page_size': '${d.pageSize}',
      'item': d.item,
      'fetch_page': d.fetchPage,
      'lookup': d.lookup,
      'Repository': m.repository,
      'FlowState': m.flowState,
      'Navigator': m.navigator,
      'Section': m.section,
      'ItemKind': m.itemKind,
      'analytics': d.analytics,
      'open_kind': d.openKind,
      'open_call': d.openCall,
      'IdType': d.id,
    },
  );
}

String _detailEvent(DbModel m, DbDetail d) => tpl(
  '''
part of '<<file>>.dart';

<<d_class>>sealed class <<Event>> {
  const <<Event>>();

  <<d_load>>const factory <<Event>>.load() = _Load;

  <<d_more>>const factory <<Event>>.loadMore() = _LoadMore;

  <<d_retry>>const factory <<Event>>.retry() = _Retry;

  <<d_refresh>>const factory <<Event>>.refresh(Completer<void> done) = _Refresh;

  <<d_open>>const factory <<Event>>.open(<<item>> <<arg>>) = _Open;
}

final class _Load extends <<Event>> {
  const _Load();
}

final class _LoadMore extends <<Event>> {
  const _LoadMore();
}

final class _Retry extends <<Event>> {
  const _Retry();
}

final class _Refresh extends <<Event>> {
  const _Refresh(this.done);

  final Completer<void> done;
}

final class _Open extends <<Event>> {
  const _Open(this.<<arg>>);

  final <<item>> <<arg>>;
}

<<d_changed>>final class _PageChanged extends <<Event>> {
  const _PageChanged(this.page);

  final PagedState<<<item>>> page;
}

<<d_resolve>>final class _ResolveName extends <<Event>> {
  const _ResolveName();
}
''',
  {
    'file': d.blocBase,
    'Event': d.event,
    'item': d.item,
    'arg': d.arg,
    'd_class': m.doc(
      'detail.event.doc',
      'What the ${d.name} page asks for (Tide\'s sealed events).',
    ),
    'd_load': m.memberDoc(
      'detail.event.load',
      'Starts over with the first page (the bloc adds it itself).',
    ),
    'd_more': m.memberDoc(
      'detail.event.load_more',
      'The grid scrolled past its load-more threshold.',
    ),
    'd_retry': m.memberDoc(
      'detail.event.retry',
      'Repeats the request that failed (the first page or a later one).',
    ),
    'd_refresh': m.memberDoc(
      'detail.event.refresh',
      'Pull to refresh: reloads the first page and keeps the items meanwhile.',
    ),
    'd_open': m.memberDoc(
      'detail.event.open',
      'An item was tapped: it opens.',
    ),
    'd_changed': m.doc(
      'detail.event.page_changed',
      'Internal: the paging controller produced a new state.',
    ),
    'd_resolve': m.doc(
      'detail.event.resolve_name',
      'Internal: the opener did not know the ${d.name}\'s name; look it up.',
    ),
  },
);

String _detailState(DbModel m, DbDetail d) => tpl(
  '''
part of '<<file>>.dart';

<<d_class>>@Freezed(copyWith: false)
sealed class <<State>> with _\$<<State>> {
  <<d_loading>>const factory <<State>>.loading() = _Loading;

  <<d_success>>const factory <<State>>.success(PagedState<<<item>>> page) =
      _Success;

  <<d_not_found>>const factory <<State>>.notFound() = _NotFound;

  <<d_failure>>@Implements<McFailureState>()
  const factory <<State>>.failure(ApiFailure error, {StackTrace? stackTrace}) =
      _Failure;
}
''',
  {
    'file': d.blocBase,
    'State': d.state,
    'item': d.item,
    'd_class': m.doc(
      'detail.state.doc',
      'Tide\'s state shape (R16). `copyWith` is off: freezed\'s deep copy of a\n'
          '`PagedState` field would name `\$PagedStateCopyWith` (F-0031 Part A\n'
          'fact 2), and the bloc emits whole states.',
    ),
    'd_loading': m.memberDoc(
      'detail.state.loading',
      'The first page is on its way.',
    ),
    'd_success': m.memberDoc(
      'detail.state.success',
      'Something to show: items (perhaps loading or failing more), or a\n'
          'settled empty ${d.name}.',
    ),
    'd_not_found': m.memberDoc(
      'detail.state.not_found',
      'No ${d.name} has this id (`404`). Not a failure: nothing to retry.',
    ),
    'd_failure': m.memberDoc(
      'detail.state.failure',
      'The first page failed. `McBloc` reports it to monitoring (D-16).',
    ),
  },
);
