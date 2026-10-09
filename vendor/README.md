# Vendored pub packages (in-repo)

These two packages are committed inside this repo so that `flutter pub get`
resolves identically on a developer machine and on cloud build runners
(GitHub Actions, Codemagic) with no machine-specific paths. `pubspec.yaml`
references them by relative path (`vendor/sqlite3`,
`vendor/sqlite3_flutter_libs`). They are excluded from `flutter analyze`
linting via `analysis_options.yaml` (their `lib/` code is still type-checked
through the app's imports).

| Package | Version | Why vendored |
|---|---|---|
| sqlite3 | 2.9.4 | Raw SQLite via FFI for the data layer; deliberately the last 2.x release (3.x switched to native-assets build hooks). |
| sqlite3_flutter_libs | 0.5.42 | Supplies the native libsqlite3 binary for Android; pairs with sqlite3 2.x. Its Android Gradle step pulls `eu.simonbinder:sqlite3-native-library:3.52.0` from Maven Central at build time. |

Do not edit these packages in place — to upgrade, replace the folder with
the new pub.dev release, update the version note here, and re-run
`flutter pub get` + `flutter analyze` + `flutter test`.
