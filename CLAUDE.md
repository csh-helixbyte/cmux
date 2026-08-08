# cmux agent notes

## This is a fork

`origin` is the user's own fork, `csh-helixbyte/cmux`. There is no upstream remote, no reviewer, and no shared review process.

Ship by merging into `main` and pushing to `origin`. Do not open a pull request. Work on a branch, dogfood the tagged build, get the user's approval, then:

```bash
git checkout main && git merge <branch> && git push origin main
git branch -d <branch>
```

Several skills in `skills/` still describe a PR flow with review bots and required GitHub checks. Their technical content still applies; the PR mechanics do not. Take the branch-merge-push path instead, and never wait on a check that only runs against a pull request.

## Setup

`./scripts/setup.sh` initializes submodules, builds GhosttyKit, and installs the pbxproj normalization pre-commit hook.

## Build and reload

Always build with a tag. **Never run bare `xcodebuild` or `open` an untagged `cmux DEV.app`**: untagged builds share the default debug socket and bundle ID with other agents, causing conflicts and stealing focus.

```bash
./scripts/reload.sh --tag <branch-slug>            # build Debug, kill same-tag app, do not launch
./scripts/reload.sh --tag <branch-slug> --launch   # also open it
```

A tag gives the app its own name, bundle ID, socket, and derived data path, so it runs side-by-side with the user's main app. Report the build to the user as a markdown link to `http://127.0.0.1:17320/<tag>`. Never put a `file://` URL, a raw `.app` path, or `/tmp/cmux-<tag>/...` in chat output.

Other variants: `reloadp.sh` (Release), `reloads.sh` (Release as isolated "cmux STAGING"), `reload2.sh --tag <tag>` (both).

Compile-only check, no launch:

```bash
xcodebuild -project cmux.xcodeproj -scheme cmux -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/cmux-<tag> build
```

Rebuild GhosttyKit.xcframework with Release optimizations:

```bash
cd ghostty && zig build -Demit-xcframework=true -Dxcframework-target=universal -Doptimize=ReleaseFast
```

Clean up older tags you started this session (quit the app, remove its `/tmp` socket and derived data) before launching a new one.

## Tag-bound debug CLI

For CLI or socket dogfood against a tagged Debug app, set `CMUX_TAG` and use the helper. Do not use `/tmp/cmux-cli`, which points at the most recently reloaded build and can target the user's main app socket.

```bash
CMUX_TAG=<tag> scripts/cmux-debug-cli.sh list-workspaces
CMUX_TAG=<tag> scripts/cmux-debug-cli.sh send --workspace workspace:1 --surface surface:1 "echo ok"
```

The helper refuses to run without `CMUX_TAG`, targets `/tmp/cmux-debug-<tag>.sock`, uses the matching tagged CLI from DerivedData, and scrubs the ambient cmux terminal context so a command cannot leak onto the user's main app.

## iOS builds open on the iPhone by default

Any work verified by opening the iOS app installs BOTH an isolated-simulator build AND the same build on the user's iPhone. Never stop at simulator-only. Use `ios/scripts/reload-cloud.sh --tag <tag>` (or `ios/scripts/reload.sh --tag <tag>`); with a default iPhone configured (`CMUX_IPHONE_DEVICE_ID` or `~/.config/cmux/iphone-device-id`) the device leg is automatic, and `--device-id <id>` still overrides (`xcrun devicectl list devices`). Auto sign-in and auto-pair apply as usual; launch the app so it is immediately open on the phone. The simulator leg uses the tag's own isolated device `cmux-dev-<slug>`, created on demand; do not target a shared or user-visible simulator.

Every phone build requires the same-tag Mac dev build (the iOS app is unusable without its Mac). The reload scripts build the Mac tag first when it is missing and refuse to ship a phone-only build if that fails; do not bypass this with `CMUX_IOS_SKIP_MAC_BUILD_CHECK` in normal work.

If the iPhone is unreachable at build time, the reload still completes: the signed build is parked in the offline install queue (`scripts/iphone-install-queue.sh`, persistent under `~/Library/Application Support/cmux-dev/iphone-install-queue`), and a LaunchAgent auto-installs and launches it within seconds of the phone being plugged back in or reappearing on the network, then sends a `cmux notify` with the installed tags. The LaunchAgent is a one-time per-Mac setup: `scripts/install-iphone-queue-agent.sh install`; it runs a stable copy of the queue script, so re-run the installer after changing that script. In the handoff, report the queued state (`scripts/iphone-install-queue.sh list`) instead of treating an unreachable phone as a failure; `drain` retries manually, `clear` abandons a queued build.

## iOS dev auth

`ios/scripts/reload.sh` and `scripts/mobile-dev-launch.sh` auto-sign-in from `~/.secrets/cmuxterm-dev.env`. If the phone lands on the login screen or the helper reports missing credentials, do not ask the user to authenticate every build. Tell them to run `scripts/setup-team-dev.sh` once; it verifies their Stack login and writes the file chmod 600. Manual fallback: create it with `CMUX_DOGFOOD_STACK_EMAIL=...` and `CMUX_DOGFOOD_STACK_PASSWORD=...`.

## Regression test commits

Two commits, so the history proves the test catches the bug: commit 1 adds the failing test only, commit 2 adds the fix. Run the test at commit 1 and confirm it fails before writing the fix — that failure is the evidence, and on a fork nothing else will produce it.

## First pass, then dogfood

A first pass ends when the change is implemented and committed on its branch, the tagged build succeeded on that branch's HEAD, and focused tests ran. Then hand off to the user. Do not open a pull request, and do not run speculative review passes after that point.

Do not launch a background review agent (`$autoreview`, `codex review`, `claude review`, or a judge loop) by default. Second-model review is explicit user opt-in in the current conversation; an implementation request, a finished branch, a closeout, or a handoff is not that opt-in.

The main agent owns dogfood, approval, and every pushed fix. Merging app/runtime/UI changes into `main` requires the user's explicit approval after dogfood, because the push to `origin/main` is what ships them. If a fix changes runtime behavior mid-dogfood, rebuild the tag and re-notify, since the earlier verdict covers only the build the user tested.

Size written output to the change. Commit messages, handoff notes, and docs state what changed, why, and how to check it. Skip restating the diff, recapping your own process, or adding summary sections that repeat the paragraph above them.

Notify through `cmux notify` so the user can leave and return. Handoff: `--title "Dogfood ready: <short task>" --subtitle "<branch> · <tag>" --body "Was: <prior bad behavior>. Now: <expected behavior>. <concrete check>."`. Later closeout notifications use `"Merged: <branch>"` or `"Blocked: <branch>"` with a one-line cause and the next decision. Titles carry outcome and branch, bodies carry the single next action. Skip notify if there is no cmux socket.

## Pitfalls

Each of these has full detail in the skill named in parentheses.

- **Typing-latency-sensitive paths** (`cmux-debugging`): `WindowTerminalHostView.hitTest()` in `TerminalWindowPortal.swift`, `TabItemView` in `ContentView.swift`, and `TerminalSurface.forceRefresh()` in `GhosttyTerminalView.swift` run on every keystroke. Read the skill before touching them.
- **SwiftUI list boundaries** (`cmux-debugging`): no view below a `LazyVStack`/`LazyHStack`/`List`/`ForEach` boundary may hold an observable store reference, and no function called from `body` may write state. Violating either reintroduces the 100% CPU spin loop from https://github.com/manaflow-ai/cmux/issues/2586. Reference pattern: `IndexSectionActions` / `SectionGapActions` / `SessionSearchFn` in `Sources/SessionIndexView.swift`.
- **Do not add an app-level display link or manual `ghostty_surface_draw` loop.** Rely on Ghostty wakeups and its renderer, or typing lags.
- **Terminal find layering** (`cmux-debugging`): `SurfaceSearchOverlay` mounts from `GhosttySurfaceScrollView` in `Sources/GhosttyTerminalView.swift` (AppKit portal layer), never from SwiftUI panel containers such as `Sources/Panels/TerminalPanelView.swift`. Portal-hosted terminal views can sit above SwiftUI during split/workspace churn.
- **Custom UTTypes** for drag-and-drop must be declared in `Resources/Info.plist` under `UTExportedTypeDeclarations` (e.g. `com.splittabbar.tabtransfer`, `com.cmux.sidebar-tab-reorder`).
- **Submodule safety** (`cmux-ghostty`): push the submodule commit to its remote `main` before committing the pointer in the parent repo. Never commit on a detached HEAD. Verify with `git merge-base --is-ancestor HEAD origin/main`.
- **Localize every user-facing string** (`cmux-localization`): `String(localized:)` with keys in `Resources/Localizable.xcstrings`, plus every web message catalog (`web/messages/en.json`, `web/messages/ja.json`). A localization audit is required for any UI, Settings, menu, schema, docs, or help-text change, and the handoff must state what was audited.
- **Shortcut policy** (`cmux-keyboard-shortcuts`): every new cmux-owned shortcut goes in `KeyboardShortcutSettings`, is editable in Settings, is supported in `~/.config/cmux/cmux.json`, and is documented.
- **Test wiring** (`cmux-testing`): a `.swift` file in `cmuxTests/` without a `PBXFileReference` + `PBXSourcesBuildPhase` entry is silently skipped, and `xcodebuild test` still passes with "Executed 0 tests". `workflow-guard-tests` runs `./scripts/lint-pbxproj-test-wiring.sh` to catch it.
- **SPM package groups** (`cmux-architecture`): packages live under `Packages/{Shared,iOS,macOS}/<pkg>` and the workspace mirrors that folder shape. To move one, `git mv` the directory then `python3 scripts/check-workspace-package-groups.py --write`. Never hand-edit workspace group membership.
- **Do not gitignore cmux-owned `Package.resolved`.** SwiftPM resolution changes must show in the commit diff; package-local lockfiles are not replaced by the root one. `python3 scripts/check-package-resolved-policy.py` fails on drift.
- **"Feature flag" means a remote PostHog runtime flag.** Implement through `CmuxFeatureFlags` with a PostHog key, explicit unavailable fallback, registry metadata, live update behavior, and focused tests. A local override may support dogfood but must not be the production control plane.
- **Foundation, SwiftUI, AttributeGraph, and WebKit semantics change between macOS major versions.** `URL(fileURLWithPath: "/").deletingLastPathComponent().path` returns `"/.."` on macOS 14 and 15 but `"/"` on macOS 26 (https://github.com/manaflow-ai/cmux/issues/4529); CI and maintainer machines were all on the fixed side while every reporter was on the broken side. Test on the reporter's macOS before declaring a repro disproven. AWS M4 Pro builders (`aws-m4pro-1..6`) run macOS 15.7.4.

## Shared behavior policy

When a behavior is exposed through multiple entrypoints (shortcut, command palette, context menu, CLI, settings, debug menu), implement one shared action path and verify every entrypoint. Do not patch one surface and leave the others with duplicated logic.

For optimistic UI or CLI updates, keep one mutation path, record pending state with a request id or previous snapshot, reconcile from the authoritative result, and roll back explicitly on failure. Do not let each entrypoint keep its own optimistic copy.

When a user says tests missed a bug, add behavior-level coverage around the exact repro path before claiming the fix is complete.

## Skills

Detailed contributor rules live in `skills/`, exposed to the Skill tool through the symlinks in `.claude/skills/`. Load the task-specific skill before changing that area; the pitfalls above name the relevant one.

Do not restate the skill catalog here. The harness already lists every installed skill with its own description, and a second hand-maintained list drifts: a skill that exists in `skills/` but has no symlink in `.claude/skills/` cannot be loaded at all, and no list in this file will tell you that.
