# Windows installer

`setup.iss` is an [Inno Setup](https://jrsoftware.org/isinfo.php) script that
packages the release output of `flutter build windows --release` into a single
installer executable.

## Build locally (on Windows)

```pwsh
flutter pub get
flutter build windows --release
# Compile the installer (requires Inno Setup 6 in PATH).
iscc windows\installer\setup.iss
```

The resulting installer is written to `windows\installer\Output\noetica-setup-<version>.exe`.

## Build via GitHub Actions

Push a tag `v*` (e.g. `v0.1.0`) or run the **release** workflow manually from
the Actions tab. The workflow defined in `.github/workflows/release.yml`:

- builds the Android APK on `ubuntu-latest`,
- builds the Windows app and compiles `setup.iss` on `windows-latest`,
- uploads both artifacts to the workflow run, and
- attaches them to the GitHub release when triggered by a tag.

> Note: a Windows installer cannot be cross-built from Linux — the Flutter
> Windows toolchain requires Visual Studio Build Tools. CI handles this via a
> Windows runner.
