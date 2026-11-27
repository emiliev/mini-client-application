/// The body of `GET /v1/flags`: `{flags: {key: value}, experiments: [...]}`.
typedef FlagsBody = Map<String, Object?>;

/// What the default set serves to everyone: the flags and their anonymous
/// values. Keys are invented; real bricks declare their own flags, and a
/// client ignores keys it has no flag for.
const Map<String, Object?> _anonymousFlags = {
  'catalogue.page_size': 20,
  'dev.diagnostics': false,
  'search.layout': 'grid',
  'settings.accent': 'red',
  'store.promo_banner': false,
};

/// What a signed-in user gets instead of the anonymous value (targeting).
/// Only the keys named here differ; every other flag is the anonymous one.
const Map<String, Map<String, Object?>> _targeting = {
  'u-100': {'search.layout': 'list', 'store.promo_banner': true},
  'u-101': {'catalogue.page_size': 40},
};

/// The experiments of the default set. Weights are relative integers (the
/// client scales them to 10000 buckets); a zero weight never gets a subject.
const List<Map<String, Object?>> _experiments = [
  {
    'key': 'store_home_layout',
    'variants': [
      {'name': 'control', 'weight': 5000},
      {'name': 'compact', 'weight': 3000},
      {'name': 'rich', 'weight': 2000},
    ],
  },
  {
    'key': 'trivia_hint',
    'variants': [
      {'name': 'control', 'weight': 10000},
      {'name': 'hint', 'weight': 0},
    ],
  },
];

/// The flags [userId] sees: the anonymous values with that user's targeting
/// applied. A null or unknown [userId] is anonymous.
Map<String, Object?> flagsForUser(String? userId) => {
  ..._anonymousFlags,
  ...?_targeting[userId],
};

/// The default set's body for [userId] (null: anonymous).
FlagsBody flagsBodyDefault(String? userId) => {
  'flags': flagsForUser(userId),
  'experiments': _experiments,
};

/// The `platform.empty` body: no flags and no experiments.
FlagsBody flagsBodyEmpty() => {
  'flags': <String, Object?>{},
  'experiments': <Object?>[],
};

/// The `platform.flags_malformed` body (the same for everyone): well-formed
/// JSON with values of the wrong type. `catalogue.page_size` is a string
/// instead of an int, `store.promo_banner` an int instead of a bool,
/// `search.layout` a name no enum has, and the second variant of
/// `store_home_layout` has a string weight. The other flags are valid.
FlagsBody flagsBodyMalformed() => {
  'flags': {
    ..._anonymousFlags,
    'catalogue.page_size': 'twenty',
    'search.layout': 'carousel',
    'store.promo_banner': 1,
  },
  'experiments': [
    {
      'key': 'store_home_layout',
      'variants': [
        {'name': 'control', 'weight': 5000},
        {'name': 'compact', 'weight': 'heavy'},
        {'name': 'rich', 'weight': 2000},
      ],
    },
    _experiments[1],
  ],
};
