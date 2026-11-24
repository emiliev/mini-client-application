/// The golden helpers now live in `mc_test_utils` (P-033, T-0026). This
/// package re-exports them so the `mc_ds_*` golden tests keep their import
/// until they migrate.
library;

export 'package:mc_test_utils/mc_test_utils.dart'
    show
        mcFontsDataLabel,
        mcGoldenApp,
        mcGoldenMatrix,
        mcLoadFonts,
        mcRegisteredFontFamily,
        mcSetSurface;
