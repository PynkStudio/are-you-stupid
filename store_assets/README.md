# Store screenshots

Ready-to-upload PNG files are generated into `output/`:

- `iphone-6.9/`: 1320 × 2868
- `ipad-13/`: 2064 × 2752
- `iphone-6.9-carousel/`: five-panel editorial carousel, 1320 × 2868 (the
  set uploaded to App Store Connect; raws in `build/screenshots/iphone69-v2/`)
- `ipad-13-carousel/`: five-panel carousel, 2064 × 2752, from native iPad
  Pro 13" simulator captures (`build/screenshots/ipad13-v2/`)
- `imessage-6.9-carousel/`: five-panel Stupid Streak carousel, 1320 × 2868
- `apple-tv/`: 3840 × 2160, five board slides (empty lobby, full lobby, round
  results, elimination, final). The board images are 2x renders of the shipped
  SwiftUI board views from `build/screenshots/board-v3/` (see below)
- `mac/`: 2880 × 1800 — real window captures of the Mac app (single player and
  the PLAY/HOST chooser, `build/screenshots/mac/`) plus three host-board slides
  (lobby, round results, final) from the same board renders, built by
  `generate_mac_screenshots.py`. Supporting lines are plain accent text, no
  pill badges

The board renders come from the AYSHostUI snapshot test, seeded with fixture
players, so lobby, results and final can be shown without staging a live
match. Refresh them after any board change, from `tvos/`:

```bash
AYS_STORE_CAPTURE_DIR="$PWD/../build/screenshots/board-v3" swift test --filter testStoreCaptures
```

then, from the repository root, regenerate only the Apple TV and Mac sets:

```bash
python3 -c "import sys; sys.path.insert(0, 'store_assets'); import generate_store_screenshots as g; g.desktop_assets()"
python3 store_assets/generate_mac_screenshots.py
```
- `play-phone/`: 1080 × 1920 (Google Play phone screenshots; Play rejects
  images taller than 2:1)
- `play-feature/`: Google Play feature graphic (1024 × 500) and hi-res icon
  (512 × 512)

All files are RGB PNGs without transparency. The carousel pairs real UI
captures with short benefit copy and a continuous visual ribbon. iPad panels
use edge-to-edge editorial crops of real UI rather than presenting an iPhone
device frame as if it were a native iPad screenshot. The campaign does not
fabricate game UI.

The iMessage set is separate from the main iOS campaign. It reproduces the
shipped UIKit states and exact extension copy inside a Messages context:
start, deterministic challenge, hidden-score wait, round result and rematch.

Regenerate from the repository root:

```bash
python3 store_assets/generate_store_screenshots.py
```

The English master copy is intentionally short enough to stay legible in App
Store search results. Localized campaigns should regenerate the header copy;
the in-app captures should come from the matching app locale.
