# tool/

## `flutter-test.sh` — run the suite on a machine with a broken Xcode

`flutter test` in this package builds native assets before it runs a single
test. `drift_flutter` pulls `path_provider_foundation`, which pulls
`objective_c`, whose build hook shells out to `xcrun --show-sdk-path` and then
compiles with `clang`.

On a machine whose Xcode cannot load `libxcodebuildLoader.dylib`, both of those
fail, and they fail in a way that looks nothing like a toolchain problem:

    Unhandled exception:
    Bad state: No element
    #0  Iterable.first (dart:core/iterable.dart:663:7)
    #1  firstLineOfStdout (.../objective_c-9.5.0/hook/build.dart:198:8)

That is `objective_c` calling `.first` on the empty stdout of a failed `xcrun`.
No test has run at this point, and nothing in the message says so.

`./tool/flutter-test.sh` puts `tool/mac-toolchain-shim/` on `PATH` ahead of
`/usr/bin` and forwards everything to `flutter test`:

    ./tool/flutter-test.sh                       # the whole suite
    ./tool/flutter-test.sh test/design_tokens_test.dart
    ./tool/flutter-test.sh --plain-name 'SOURCE PARITY'

### Why the shim and not `xcode-select`

`sudo xcode-select -s /Library/Developer/CommandLineTools` is the obvious fix
and it does not work: the Command Line Tools ship no `usr/bin/xcrun`, so the
hook fails identically. `DEVELOPER_DIR` alone fails the same way. Two shims are
needed — one answering `xcrun --show-sdk-path`, and one routing `clang` to the
CLT copy, because the broken Xcode's `clang` cannot locate `xcodebuild` either
and fails one step later.

If your Xcode is healthy, none of this applies and plain `flutter test` works.
The shims only ever forward, so running through the script on a healthy machine
is harmless.
