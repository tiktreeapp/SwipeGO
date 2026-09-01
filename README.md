# SwipeGo

SwipeGo is a native iOS photo library organizer built with SwiftUI and PhotoKit. The app focuses on reducing the stress of large photo libraries by grouping media into quick swipe sessions, showing storage impact, and keeping cleanup actions inside the iOS photo permission and deletion flow.

## Product Goals

1. Make photo cleanup feel lightweight: users review one group at a time instead of scrolling through the full library.
2. Surface storage impact immediately: the launch screen and My tab both show photo-library usage against total device capacity.
3. Keep actions safe: deletes use the system PhotoKit confirmation flow and move media to Recently Deleted.
4. Use an English UI throughout the app.
5. Support iOS 17.6 and later while using a modern, translucent bottom-tab style inspired by current iOS design.
6. Use `#02A75B` as the primary green.

## Implemented Scope

### Launch

- Rounded green app mark with the app name `SwipeGo`.
- Tagline: `Swipe Easy, Save Storage.`
- Local photo-library storage summary in the format `Photos on Device: used/total`.
- Top four media categories ranked by estimated storage and count:
  - Videos
  - Photos
  - Live Photos
  - Screenshots
- Start button transitions into the main app.
- Privacy line: `Organized locally. Privacy protected. Use with confidence.`

### Swipe Tab

- Shows a green-accented system alert on first entry:
  - English translation: `To reduce the pressure of cleaning up a large photo library, SwipeGo uses smart daily groups to help you revisit past moments.`
- Shows the current date.
- Displays four 3:4 cover cards in a 2 by 2 grid:
  - Random: non-video media grouped by day, preferring compact daily groups and limiting the stack to 16 items.
  - Videos: largest videos first, using file size and then duration, limited to 8 items.
  - Memories: currently uses older-year media as a practical placeholder until the final memory rule is specified.
  - Screenshots: currently uses recent screenshots as a practical placeholder until the final screenshot rule is specified.
- Detail viewer supports:
  - Left swipe: skip.
  - Right swipe: like/browse.
  - Up swipe: request deletion through PhotoKit and iOS confirmation.

### Cleanup Tab

- Top segmented control:
  - Time
  - Media Type
- Time filters by year and month.
- Media Type filters by the same core categories used by the app.
- Thumbnail grid uses square crops.

### My Tab

- Refreshable total library storage summary.
- Top storage categories.
- Today's cleanup summary:
  - Browsed count.
  - Deleted count.
  - Estimated storage saved.
  - Per-media-type viewed/deleted counts.

## Technical Notes

- Frameworks: SwiftUI, PhotoKit, UIKit.
- Minimum app deployment target: iOS 17.6.
- Photo library access uses `PHPhotoLibrary.requestAuthorization(for: .readWrite)`.
- Estimated file sizes are derived from `PHAssetResource` metadata.
- Device capacity is read from file system attributes.
- Image thumbnails are loaded through `PHCachingImageManager` with aspect-fill square thumbnails for cleanup and aspect-fill 3:4 covers for swipe groups.

## Remaining Product Decisions

1. Define the final Memories grouping rule.
2. Define the final Screenshots grouping rule.
3. Decide whether likes should be persisted locally with SwiftData.
4. Decide whether daily cleanup stats reset at midnight or are persisted as history.
