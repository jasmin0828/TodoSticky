# TodoSticky Gate 3B-1 — Developer ID Release Signing + Hardened Runtime

Date: 2026-09-29
Baseline: `3c61c2f1d81cb80406521a8435385f2842210b34` (`main`)

## Closure

`GATE 3B-1 — PASS / CLOSED / FROZEN`

This Gate covers Release signing, Hardened Runtime, signed-app verification, runtime smoke testing, and regression tests. Notarization, stapling, DMG packaging, GitHub release work, tags, and push remain outside this Gate.

## Release signing configuration

Only the TodoSticky app target's Release configuration was changed. Debug and the TodoStickyTests target remain signing-disabled development configurations.

- Signing identity: `Developer ID Application: DEGENG CHEN (P5949MJ486)`
- Developer ID TeamIdentifier: `P5949MJ486`
- `CODE_SIGN_STYLE = Manual`
- `CODE_SIGNING_ALLOWED = YES`
- `CODE_SIGNING_REQUIRED = YES`
- `CODE_SIGNING_TIMESTAMP = YES`
- `OTHER_CODE_SIGN_FLAGS = "--timestamp"`
- `CODE_SIGN_INJECT_BASE_ENTITLEMENTS = NO`
- `ENABLE_HARDENED_RUNTIME = YES`
- No provisioning profile and no explicit entitlements file.
- Release code coverage is disabled in the target configuration. Xcode 27 still reports a derived coverage-mapping default, so the reproducible Gate build also passed `CLANG_COVERAGE_MAPPING=NO`; the final binary contains no LLVM profiling sections.

## Release artifact evidence

Build command:

```text
xcodebuild -project TodoSticky.xcodeproj -scheme TodoSticky -configuration Release \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/todosticky-gate3b1-final.CNGnaV \
  CLANG_COVERAGE_MAPPING=NO build
```

Result: **PASS**.

Artifact: `/tmp/todosticky-gate3b1-final.CNGnaV/Build/Products/Release/TodoSticky.app`

- Architecture: arm64
- Bundle identifier: `com.jasminstudio.TodoSticky`
- Version: `0.1 (1)`
- `AppIcon.icns` and `Assets.car` present.
- No `__llvm_prf_*` or `__LLVM_COV` sections present.

## Signature verification

The final artifact reports:

- Authority: Developer ID Application → Developer ID Certification Authority → Apple Root CA.
- TeamIdentifier: `P5949MJ486`.
- CodeDirectory flag: `runtime`.
- Secure timestamp present.
- Sealed Resources version 2 with two sealed resources.
- `codesign --verify --deep --strict --verbose=4`: **PASS**.
- Signature is not ad-hoc.

Effective entitlements are empty. `com.apple.security.get-task-allow` is absent, and no Hardened Runtime exception is present.

## Runtime and tests

- Exact Release artifact launched successfully.
- Accessibility/UI inspection showed the `Todo Sticky` window, input field, existing Todo list, and normal menu bar without an immediate crash.
- Smoke test used an isolated temporary HOME/profile path and did not modify repository `default.profraw` or user Todo data.
- XCTest: **11 passed, 0 failed, 0 skipped**.
- Test profiling output was redirected outside the repository.

## Gatekeeper boundary

`spctl --status` reports `assessments disabled`. The artifact is reported as `source=Unnotarized Developer ID` with `override=security disabled`. This confirms the local signed-app baseline only; it does not establish Gatekeeper acceptance. Notarization and stapling remain pending for Gate 3B-2.

## Scope and freeze

The repository diff is limited to the Release signing/Hardened Runtime configuration and this Gate record. No Todo feature, AppIcon, persistence, workflow, credential, certificate, or private-key material was added. No tag, release, push, DMG, or notarization submission was performed.
