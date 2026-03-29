# Product Summary

## One-line definition

Restore a saved macOS multi-display layout after dock reconnect, sleep wake, or random identical-monitor swaps.

## Target user

- developers with two or more external displays
- creators with layout-sensitive workflows
- analysts or traders who need stable left/right positioning

## MVP scope

- macOS menu bar app
- launch at login hook point
- display reconfiguration watcher
- debounce window before restore
- profile save and profile selection
- confidence-based automatic restore
- `Fix Now` action
- `Swap Left / Right` fallback
- recent diagnostics log

## Product constraints

- do not promise perfect prevention
- skip automatic restore when confidence is low
- keep the utility lightweight and quiet in normal operation
- wrap `displayplacer` first, then evaluate a native engine later

## Initial architecture

- `DisplayRestoreApp`: menu bar shell and settings surface
- `DisplayRestoreKit`: models, matcher, coordinator, persistence, logging
- `ProfileMatcher`: weighted scoring based on serials, IDs, resolution, scale
- `RestoreCoordinator`: translates scores into safe actions
- `ProfileStore`: JSON persistence in Application Support

## Next implementation milestones

1. Replace sample snapshots with a CoreGraphics-backed snapshot reader.
2. Register a real display reconfiguration callback with debounce handling.
3. Wire `displayplacer` execution and post-restore verification.
4. Add launch-at-login via `SMAppService`.
5. Expand tests with recorded hardware fixtures.

