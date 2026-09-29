# TodoSticky Gate 3B-2 — Apple Notarization + Stapling

Date: 2026-09-29
Baseline: `446af4aa2ede23f05ff37bb41671c23168903079` (`main`)

## Closure

`GATE 3B-2 — PASS / CLOSED / FROZEN`

`APPLE NOTARIZATION — ACCEPTED`
`STAPLED APP — VALIDATED`

This Gate covers Apple notarization, stapling, post-staple verification, exact Release runtime smoke testing, and regression evidence. DMG packaging, GitHub release work, tags, and push remain outside this Gate.

## Frozen Release candidate

The candidate was rebuilt from the exact Gate 3B-1 commit without source or project-file changes:

```text
xcodebuild -project TodoSticky.xcodeproj -scheme TodoSticky -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/todosticky-gate3b2.O6PYUH \
  CLANG_COVERAGE_MAPPING=NO build
```

Result: **PASS**.

- App: `/tmp/todosticky-gate3b2.O6PYUH/Build/Products/Release/TodoSticky.app`
- Bundle identifier: `com.jasminstudio.TodoSticky`
- Version: `0.1 (1)`
- Architecture: arm64
- Developer ID TeamIdentifier: `P5949MJ486`
- ZIP: `/tmp/todosticky-gate3b2.O6PYUH/TodoSticky-notarization.zip`
- ZIP size: `2095192` bytes
- ZIP SHA-256: `a951108d45b2647d31144cdc55648df07207752fb585275016078e0f55958559`

## Pre-submission signature evidence

- `codesign --verify --deep --strict --verbose=4`: **PASS**.
- Authority chain: Developer ID Application → Developer ID Certification Authority → Apple Root CA.
- CodeDirectory flag: `runtime`; secure timestamp present.
- Effective entitlements are empty; no `com.apple.security.get-task-allow` entitlement is present.
- No LLVM profiling sections were present in the Release executable.

## Apple Notary Service

Submission used only the existing Keychain profile `TodoSticky-Notary`; no credential material was read or recorded.

- Submission ID: `75b048b0-fce8-40f9-a296-2fd0e880e435`
- Created: `2026-09-29T06:26:25.439Z`
- Upload: `2026-09-29T06:26:28.071Z`
- Status: **Accepted**
- Status summary: `Ready for distribution`
- Status code: `0`
- Notary log SHA-256: `a951108d45b2647d31144cdc55648df07207752fb585275016078e0f55958559`
- Issues: `null`
- Ticket architecture: arm64
- Ticket CDHash: `8a2ccbf0fcb6d42836f0c4e5ae79fd1d2a51422c`

## Stapling and post-staple verification

- `xcrun stapler staple`: **PASS** (`The staple and validate action worked!`).
- `xcrun stapler validate`: **PASS** (`The validate action worked!`).
- `codesign --verify --deep --strict --verbose=4`: **PASS**.
- Post-staple signature reports `Notarization Ticket=stapled`.
- `spctl --assess --type execute --verbose=4`: **accepted**, `source=Notarized Developer ID`, `override=security disabled`.

The local system reports Gatekeeper assessments disabled; therefore this evidence does not claim clean-machine Gatekeeper behavior beyond the notarized Developer ID assessment returned by `spctl`.

## Runtime and regression evidence

- Exact stapled Release executable launched successfully from the frozen artifact.
- Accessibility/UI inspection showed the `Todo Sticky` window, input field, existing Todo list, and menu bar; no immediate crash occurred.
- Runtime process path: `/tmp/todosticky-gate3b2.O6PYUH/Build/Products/Release/TodoSticky.app/Contents/MacOS/TodoSticky`.
- Smoke test used an isolated temporary HOME and profile path. Exact runtime processes were terminated after inspection; no exact executable remained.
- XCTest command used temporary DerivedData and profile output outside the repository.
- XCTest: **11 passed, 0 failed, 0 unexpected**.

## Scope and freeze

The only repository change after verification is this Gate record. `default.profraw` remains untouched and untracked. No AppIcon architecture, product source, `project.pbxproj`, `Contents.json`, credentials, DMG, tag, GitHub release, or push was changed by this Gate.

Next authorized step: Gate 3B-3 distribution packaging/release work.
