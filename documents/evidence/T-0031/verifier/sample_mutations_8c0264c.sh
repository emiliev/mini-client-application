#!/bin/bash
# Re-runs a sample of the round-1 mutations at 8c0264c.
cd /Users/emililiev/projects/flutter/mini-client/.claude/worktrees/agent-a8c6bd698e60fb5fa
M=documents/evidence/T-0031/verifier/mutate.sh
PB=utility/mc_ds_lists/lib/src/paged_body.dart; L=//utility/mc_ds_lists:paged_list_test; G=//utility/mc_ds_lists:paged_grid_test
IM=utility/mc_ds_media/lib/src/mc_image.dart; I=//utility/mc_ds_media:image_test
CA=utility/mc_ds_cards/lib/src/mc_media_card.dart; C=//utility/mc_ds_cards:card_test
r() { bash $M "$@" 2>&1 | grep -E "^\[|passed|failed" | sed 's/^  \/\/utility\/[a-z_]*://' | tr '\n' ' '; echo; }
r M3-no-latch $PB 's/\} else if \(!_requested\) \{/} else if (true) {/' $L $G
r M4-no-end $PB 's/!s\.hasReachedEnd &&\n\s*//' $L $G
r M5-no-inflight $PB 's/!s\.isLoadingMore &&\n\s*//' $L $G
r M6-no-failure $PB 's/&&\n\s*s\.failure == null;/;/' $L $G
r M9-failure-hides-items $PB 's/if \(firstLoad && s\.failure != null\)/if (s.failure != null)/' $L $G
r M10-retry-twice $PB 's/onPressed: onRetry,/onPressed: () {\n                onRetry();\n                onRetry();\n              },/' $L $G
r M11-no-empty $PB 's/firstLoad && s\.hasReachedEnd && !s\.isLoadingMore/firstLoad && s.hasReachedEnd && s.isLoadingMore/' $L $G
r M12-no-skeleton $PB 's/final skeleton = widget\.skeletonSliver\?\.call\(context\);/final Widget? skeleton = null;/' $L $G
r M14-no-placeholder $IM 's/final ready = wasSynchronouslyLoaded \|\| frame != null;/final ready = wasSynchronouslyLoaded || frame != null || child is Widget;/' $I
r M15-narrow-catch $IM 's/\} on Exception catch \(_\) \{/} on FormatException catch (_) {/' $I
r M17-network-as-asset utility/mc_ds_media/lib/src/image_provider_for.dart 's/NetworkImage\(url\.toString\(\)\)/AssetImage(url.toString())/' $I
r M18-error-placeholder $IM 's/errorBuilder: \(context, error, stack\) =>\n\s*_Fallback\(key: McImage\.fallbackKey, palette: palette\),/errorBuilder: (context, error, stack) =>\n          _Placeholder(key: McImage.placeholderKey, palette: palette),/' $I
r M21-label-swap $CA 's/label: title,\n      value: subtitle,/label: subtitle ?? title,\n      value: title,/' $C
r M22-no-exclude $CA 's/onTap: onTap,\n      child: ExcludeSemantics\(child: card\),/onTap: onTap,\n      child: card,/' $C
r G1-dark-outline utility/mc_ds_tokens/lib/src/colors.dart 's/outline: Color\(0xFF7C7C88\)/outline: Color(0xFF7C7C89)/' //utility/mc_ds_media:golden_test //utility/mc_ds_cards:golden_test //utility/mc_ds_lists:golden_test
