# T-0058-AC4: no direct overlay calls

## direct calls in lib code (outside mc_ds_overlays)
```
none
```
## positive control: mc_ds_overlays/lib holds the calls in: utility/mc_ds_overlays/lib/src/mc_dialog.dart utility/mc_ds_overlays/lib/src/mc_menu_button.dart utility/mc_ds_overlays/lib/src/mc_sheet.dart utility/mc_ds_overlays/lib/src/mc_toast.dart 
## negative controls
```
showDialog(context: ctx);: reported
showAdaptiveDialog(context: ctx);: reported
showModalBottomSheet(context: ctx);: reported
showBottomSheet(context: ctx);: reported
showGeneralDialog(context: ctx);: reported
showCupertinoDialog(context: ctx);: reported
showCupertinoModalPopup(context: ctx);: reported
showCupertinoSheet(context: ctx);: reported
showSnackBar(null);: reported
showMaterialBanner(null);: reported
showAboutDialog(context: ctx);: reported
showLicensePage(context: ctx);: reported
showMenu(context: ctx);: reported
PopupMenuButton<int>(itemBuilder: b);: reported
Overlay.of(ctx).insert(entry);: reported
whole-line comments: ignored
```

**PASS T-0058-AC4-no-direct-overlays**
