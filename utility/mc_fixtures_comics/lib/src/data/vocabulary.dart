/// Word lists for the invented comics. Everything here is original.
///
/// A series title is `<series word> <series noun>`: 12 x 10 = 120 unique
/// combinations. The `Sp*` words exist so prefix search has real work to do.
library;

const List<String> seriesWords = [
  'Spindle',
  'Spire',
  'Sparrow',
  'Amber',
  'Brass',
  'Cinder',
  'Ember',
  'Frost',
  'Gale',
  'Hollow',
  'Iron',
  'Jade',
];

const List<String> seriesNouns = [
  'Chronicles',
  'Station',
  'Legacy',
  'Vanguard',
  'Harbor',
  'Requiem',
  'Frontier',
  'Gambit',
  'Orbit',
  'Reckoning',
];

const List<String> premises = [
  'a lighthouse keeper who hears the tide count backwards',
  'a courier carrying a letter that rewrites its own address',
  'a clockmaker whose shop stays open one hour past midnight',
  'a retired pilot and a map that will not stay finished',
  'two rival cartographers sharing one very small island',
  'a city that rebuilds itself every autumn',
  'a quiet librarian guarding a book nobody can finish',
  'a night train that stops only at places that are not there',
];

const List<String> twists = [
  'the storm arrives early',
  'an old debt comes due',
  'the lights go out all at once',
  'a stranger knows everyone by name',
  'the map turns out to be a mirror',
  'the last bridge is closed for repairs',
];

const List<String> creatorFirstNames = [
  'Ada',
  'Bruno',
  'Calla',
  'Dmitri',
  'Esme',
  'Farid',
  'Greta',
  'Hiro',
  'Ines',
  'Jonas',
  'Kira',
  'Lev',
];

const List<String> creatorLastNames = [
  'Alder',
  'Brook',
  'Castell',
  'Dunmore',
  'Eastwick',
  'Fenn',
  'Garrow',
  'Holt',
  'Ivers',
  'Kestrel',
];

/// The roles on a comic, in credit order. The first two are always present.
const List<String> creatorRoles = [
  'writer',
  'penciller',
  'inker',
  'colorist',
  'letterer',
  'cover_artist',
];

const List<String> variantLabels = [
  'Foil',
  'Sketch',
  'Retailer',
  'Anniversary',
  'Midnight',
];
