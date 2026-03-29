# LayoutRecall Product Specification

Status: Draft  
Last updated: 2026-03-29

## 1. Purpose

LayoutRecall is a macOS menu bar utility that detects disruptive external display changes and restores a previously saved layout when the connected monitor set matches a known workspace with high confidence.

This document turns the high-level product draft into an implementation-ready plan. It defines scope, architecture direction, acceptance criteria, delivery phases, and the issue breakdown needed to move the repository from scaffold to MVP.

## 2. Problem Statement

macOS may reorder or swap identical external displays after:

- dock reconnect
- sleep and wake
- cable reconnect
- monitor power cycle
- spontaneous display reconfiguration

For users who rely on stable left/right monitor placement, this creates immediate productivity loss and forces repetitive manual correction.

## 3. Product Goals

### Primary goals

- Detect meaningful display reconfiguration events with low noise.
- Match the current monitor set against saved profiles safely.
- Restore a saved layout automatically only when confidence is high.
- Offer a fast manual recovery path when confidence is low.
- Keep the app lightweight, quiet, and menu-bar-first.

### Secondary goals

- Persist recent diagnostics for troubleshooting.
- Support launch at login.
- Make the app reliable enough for daily use on common dual- and triple-monitor setups.

## 4. Non-Goals for MVP

- A fully native display layout engine that replaces `displayplacer`
- Cloud sync or multi-machine profile sync
- Per-app window arrangement
- Enterprise device policy support
- Cross-platform support outside macOS
- A complex onboarding flow or analytics pipeline

## 5. Current Repository Status

The current codebase already provides useful scaffolding:

- domain models for display snapshots and profiles
- profile matching and restore decision logic
- profile persistence in Application Support
- menu bar shell and settings window
- a repo-owned verification entrypoint

The repository is not yet functionally complete because these pieces are still missing or stubbed:

- real display snapshot capture from CoreGraphics
- real display event monitoring and debounce
- actual `displayplacer` execution
- post-restore verification
- persistent diagnostics history
- launch-at-login integration
- broader tests and CI coverage

## 6. MVP Definition

The MVP is complete when all of the following are true:

- The app reads the real currently attached display set.
- The app listens for real display reconfiguration events.
- The app can save at least one usable profile from a live setup.
- The app automatically restores a saved layout only when the match score exceeds the configured threshold.
- The app exposes `Fix Now` and `Swap Left / Right` manual actions.
- The app stores recent diagnostics and shows them in the UI.
- The app can launch at login.
- The repository has repeatable build/test verification and CI.

## 7. Target Users

- Developers using laptop + dock + multiple external monitors
- Creators who keep a stable primary/secondary monitor arrangement
- Analysts or operators with layout-sensitive workstations

## 8. Core User Flows

### Flow A: First-time setup

1. User launches the app.
2. User saves the current layout as a profile.
3. The app captures live display metadata and a restore command.
4. The profile is persisted.

### Flow B: Automatic recovery

1. macOS emits a display reconfiguration event.
2. The app waits for the debounce window to settle.
3. The app captures the current live display set.
4. The app finds the best profile match.
5. If the score is above the threshold and auto-restore is enabled, the app runs the restore command.
6. The app verifies the result and records diagnostics.

### Flow C: Manual recovery

1. A reconfiguration event happens but confidence is below threshold.
2. The app does not auto-run a command.
3. The user opens the menu and clicks `Fix Now` or `Swap Left / Right`.
4. The app executes the chosen action and records diagnostics.

## 9. Functional Requirements

### FR-1: Live display snapshot capture

The app must collect a live `DisplaySnapshot` array from CoreGraphics and related APIs.

Required fields:

- stable display identifier
- vendor ID
- product ID
- serial number when available
- fallback identifiers when serial is unavailable
- resolution
- refresh rate when available
- scale factor when available
- display bounds/origin

Acceptance criteria:

- A connected dual-monitor setup produces two snapshots with stable IDs across repeated reads.
- Identical monitor models still remain distinguishable when any serial or persistent identifiers exist.
- Snapshot capture failures are reported in diagnostics and do not crash the app.

### FR-2: Display event monitoring

The app must observe display-related changes and trigger restore evaluation only after the display set stabilizes.

Requirements:

- use a real CoreGraphics reconfiguration callback
- support wake-related reevaluation
- debounce repeated change bursts into one evaluation
- ignore obviously transient intermediate states when possible

Acceptance criteria:

- Reconnect or wake sequences do not produce repeated restore attempts within the debounce window.
- Manual test logs show one evaluation for one meaningful display change burst.

### FR-3: Profile creation and persistence

The app must allow saving a profile from the current live layout and persist it safely.

Requirements:

- save the display set fingerprint
- save the display metadata used for matching
- save expected origins/positions
- save the engine type and generated restore command
- allow multiple profiles
- allow toggling auto-restore and confidence threshold per profile

Acceptance criteria:

- Saving the current layout produces a profile file that survives app restart.
- A newly saved profile is immediately eligible for matching.

### FR-4: Matching and restore decision

The app must select the best saved profile safely and decide whether to auto-restore, offer manual recovery, or remain idle.

Requirements:

- preserve the existing weighted matching approach as a starting point
- keep matching independent of physical display order
- allow profile-specific confidence thresholds
- never auto-restore below threshold
- prefer safe false negatives over unsafe false positives

Acceptance criteria:

- A known saved setup with strong identifiers matches above threshold.
- A partial or ambiguous setup does not auto-restore.
- No profile match results in `saveNewProfile` when no profiles exist, otherwise `offerManualFix`.

### FR-5: Restore execution

The app must execute layout restoration through `displayplacer` first.

Requirements:

- discover whether `displayplacer` is installed and runnable
- execute restore commands asynchronously
- capture exit status, stderr, and timeout
- support a manual `Fix Now`
- support a manual `Swap Left / Right` fallback command

Acceptance criteria:

- A valid command executes successfully from the app process.
- Missing `displayplacer` produces a clear UI and diagnostics message.
- Fallback actions are backed by real commands rather than placeholder text.

### FR-6: Post-restore verification

The app must verify whether the requested layout appears to have been restored after command execution.

Requirements:

- re-read live snapshots after restore
- compare restored origins against the expected profile origins
- tolerate small timing delays with a short retry window
- report verified success, unverified result, or failure

Acceptance criteria:

- A successful restore records verification success.
- A failed or partial restore records the mismatch reason.

### FR-7: Diagnostics

The app must persist and display recent diagnostics to help debug matching and restore failures.

Required fields:

- timestamp
- event type
- matched profile name
- match score
- chosen action
- execution result
- verification result
- human-readable details

Acceptance criteria:

- Diagnostics survive app relaunch.
- The most recent entries are viewable from the settings UI.
- Diagnostic volume is capped to avoid unbounded growth.

### FR-8: Menu bar and settings UX

The app must remain menu-bar-first and provide only the controls necessary for the MVP.

Menu requirements:

- current status line
- latest decision line
- latest executed command when relevant
- `Fix Now`
- `Save Current Layout`
- `Swap Left / Right`
- link to settings
- quit button

Settings requirements:

- list profiles
- edit profile name
- toggle auto-restore
- adjust confidence threshold
- view recent diagnostics
- explain when the app will or will not auto-restore

Acceptance criteria:

- A user can configure and recover from the menu bar without opening a developer console.

### FR-9: Launch at login

The app must support optional launch at login using `SMAppService`.

Acceptance criteria:

- The setting persists.
- The app registers and unregisters cleanly without crashing.

## 10. Non-Functional Requirements

### NFR-1: Safety

- Do not execute automatic restore when confidence is below threshold.
- Do not restore when the display count is clearly incompatible.
- Do not crash due to missing identifiers or missing external dependencies.

### NFR-2: Performance

- Snapshot capture should complete quickly enough for menu interactions to feel immediate.
- Restore evaluation should happen within a short time after the debounce window ends.

### NFR-3: Reliability

- Burst display events should not trigger restore loops.
- Persistence failures should degrade gracefully.

### NFR-4: Observability

- Diagnostic entries must be sufficient to reconstruct what the app decided and why.

### NFR-5: Repository health

- `./scripts/run-ai-verify --mode full` must remain the local completion gate.
- GitHub Actions must run build and test on pull requests.

## 11. Technical Design Direction

### 11.1 Runtime pipeline

1. Receive a display-related event.
2. Start or refresh the debounce timer.
3. Capture the live display set after the timer elapses.
4. Load saved profiles.
5. Match the current display set against profiles.
6. Decide whether to auto-restore, offer manual recovery, save a profile, or stay idle.
7. If a restore action is selected, execute the engine command.
8. Re-read the display set and verify the result.
9. Record diagnostics and update UI state.

### 11.2 Proposed new or expanded components

- `DisplaySnapshotReader`: reads live display data
- `CGDisplayEventMonitor`: real monitor callback implementation
- `RestoreExecutor`: runs external restore commands
- `RestoreVerifier`: compares expected vs actual layout after execution
- `DiagnosticsStore`: persists and loads recent diagnostics
- `ProfileCommandBuilder`: generates `displayplacer` commands from live snapshots

### 11.3 Existing components to keep and extend

- `ProfileMatcher`: keep the weighted model and refine using fixture data
- `RestoreCoordinator`: keep as the central decision boundary
- `ProfileStore`: extend if profile schema evolves
- `AppModel`: move from scaffold state to real orchestration state

## 12. Delivery Roadmap

### Phase 0: Foundation and repository health

Goals:

- stabilize verification
- document the product clearly
- prepare CI

Deliverables:

- this specification document
- GitHub Actions workflow for build/test
- small refactors that support dependency injection for live integrations

Exit criteria:

- every PR runs automated build/test
- local verify and CI use the same basic success conditions

### Phase 1: Live display capture

Goals:

- replace sample snapshots with real hardware reads

Deliverables:

- `DisplaySnapshotReader`
- integration of live snapshots into `AppModel`
- diagnostic handling for snapshot capture failures

Exit criteria:

- the app menu reflects live hardware state rather than sample data
- saved profiles are created from real monitor metadata

### Phase 2: Event monitoring and debounce

Goals:

- move from manual-only evaluation to event-driven evaluation

Deliverables:

- real display event monitor
- debounce coordinator
- wake/reconfigure handling

Exit criteria:

- reconnecting displays causes one restore evaluation at the end of the event burst

### Phase 3: Real restore execution

Goals:

- make `Fix Now` and auto-restore actually restore layouts

Deliverables:

- `displayplacer` command execution
- `Swap Left / Right` fallback implementation
- dependency checks and failure surfacing
- post-restore verification

Exit criteria:

- the app can restore a known layout end to end in a controlled test environment

### Phase 4: Profile UX and diagnostics

Goals:

- make the app understandable and operable without developer help

Deliverables:

- editable profiles
- confidence threshold controls
- persisted diagnostics history
- settings diagnostics view

Exit criteria:

- a user can inspect what the app decided and why

### Phase 5: Login item, hardening, and beta readiness

Goals:

- make the app fit for external testing

Deliverables:

- launch at login
- broader test coverage with recorded fixtures
- packaging polish
- known limitations documentation

Exit criteria:

- the app is stable enough for daily beta usage by a small set of external users

## 13. Recommended GitHub Milestones

### Milestone 1: Live capture and event pipeline

- implement `DisplaySnapshotReader`
- implement `CGDisplayEventMonitor`
- add debounce coordinator
- connect live snapshots to `AppModel`

### Milestone 2: Restore execution MVP

- add `displayplacer` executor
- generate commands from saved profiles
- implement post-restore verification
- implement real `Fix Now`
- implement real `Swap Left / Right`

### Milestone 3: Productization

- diagnostics persistence
- profile editing UX
- launch at login
- CI hardening
- fixture-based tests

## 14. Recommended Issue Breakdown

1. Add `DisplaySnapshotReader` backed by CoreGraphics.
2. Add a real `DisplayEventMonitor` and debounce coordinator.
3. Replace sample display injection in `AppModel` with live snapshots.
4. Add a `displayplacer` dependency check and execution service.
5. Add post-restore verification against expected origins.
6. Generate restore commands from saved live layouts.
7. Implement a real `Swap Left / Right` fallback action.
8. Persist diagnostics to disk and expose them in settings.
9. Add profile editing and threshold controls.
10. Add `SMAppService` launch-at-login support.
11. Add CI for build/test verification.
12. Add recorded fixture tests for dual- and triple-monitor scenarios.

## 15. Testing Strategy

### Unit tests

- profile matching score behavior
- restore decision thresholds
- command generation
- verification diff logic
- diagnostics truncation and persistence

### Fixture tests

- dual identical monitors with stable serials
- identical monitors with missing serials
- dock reconnect with reordered IDs
- one display missing
- low-confidence ambiguous setup

### Manual hardware tests

- disconnect and reconnect dock
- sleep and wake while docked
- power cycle one identical monitor
- swap cable ports between identical monitors

### Verification gate

Local completion must continue to use:

```bash
./scripts/run-ai-verify --mode full
```

CI must cover the same build and test path.

## 16. Risks and Mitigations

### Risk: unstable monitor identifiers

Mitigation:

- score multiple identifiers rather than relying on one
- use fixture data from several hardware setups

### Risk: restore loops during noisy event bursts

Mitigation:

- strict debounce
- cooldown after restore
- skip re-triggering on self-induced changes where feasible

### Risk: `displayplacer` availability or command drift

Mitigation:

- explicit dependency detection
- clear missing dependency messaging
- isolate command generation and execution behind services

### Risk: false-positive auto-restore

Mitigation:

- conservative default threshold
- profile-specific thresholds
- prefer manual recovery when uncertain

## 17. Open Questions

- Which exact CoreGraphics and IOKit identifiers are most stable across the target hardware matrix?
- Should the app support multiple fallback actions beyond `Swap Left / Right` in MVP?
- Should the app auto-save diagnostics to a plain JSON file or a more human-readable log format?
- How aggressively should post-restore verification retry before declaring uncertainty?

## 18. Immediate Next Step

The highest-value next implementation task is:

Add a real `DisplaySnapshotReader` and wire it into `AppModel`.

Reason:

- every remaining product behavior depends on live hardware state
- without this step the app remains a scaffold regardless of UI or command work
