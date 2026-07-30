# Decision 0001: hand-edit `project.pbxproj` for new targets, don't use the `xcodeproj` gem

**Status:** Accepted (Phase 0/1, commit `ae220c9`).

**Context:** Needed to add `CineConnectTests`/`CineConnectUITests` native
targets with no Xcode GUI available in this environment. The project uses
`objectVersion = 77` (Xcode 16+'s `PBXFileSystemSynchronizedRootGroup`
format) — a recent enough format that CocoaPods' `xcodeproj` Ruby gem's
support for it was an unknown risk at the time.

**Decision:** Author a minimal, targeted textual diff to
`project.pbxproj` directly — new `PBXNativeTarget`/`PBXFileReference`/
`PBXTargetDependency`/`XCConfigurationList` entries only, leaving every
existing object (including the app target's synchronized group
definition) completely untouched.

**Why not the gem:** it fully parses and re-serializes the *entire*
project file. For a very new format version, that round-trip risks
silently mangling parts of the file the gem doesn't fully model yet — and
even if it works, the resulting diff would touch far more of the file than
necessary, making review harder.

**Verification that this was safe:** `plutil -lint` (syntax), `xcodebuild
-list` (both new targets + existing target all recognized), `xcodebuild
build` (app target unaffected), `xcodebuild test` (both new targets build,
link, and run correctly) — see
`../IMPLEMENTATION_JOURNAL.md`'s CC6 entry and
`../FILE_INDEX.md` for the full targets/files touched.

**Consequence:** any *future* project-file surgery in this repo (a third
test target, a Swift package dependency, etc.) should default to the same
minimal-diff approach until there's a concrete reason to trust a generator
tool with this project's specific format version.
