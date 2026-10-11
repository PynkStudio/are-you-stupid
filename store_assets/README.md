# Store screenshots

Ready-to-upload PNG files are generated into `output/`:

- `iphone-6.9/`: 1320 × 2868
- `ipad-13/`: 2064 × 2752
- `iphone-6.9-carousel/`: six-panel editorial carousel, 1320 × 2868
- `ipad-13-carousel/`: six-panel editorial carousel, 2064 × 2752
- `imessage-6.9-carousel/`: five-panel Stupid Streak carousel, 1320 × 2868
- `apple-tv/`: 3840 × 2160
- `mac/`: 2880 × 1800
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
