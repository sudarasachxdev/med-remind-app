// The binding between `PermissionGateway` and its
// `flutter_local_notifications` adapter.
//
// Story 3.1a built the port and its one adapter with no caller -- exactly the
// position `DoseRepository` was in from Story 1.7a until Story 1.8 wired its
// first one, and `test/story_scope_test.dart`'s own `_providerHomes` entry
// guarded `lib/app/`/`lib/features/` against either name for the same reason
// Story 1.7a's guard did: a screen must not arrive early, before this story
// existed to need one. This is that first caller, so the guard is retired
// here and the binding lands here.
//
// Declared with no implementation, in the same shape as `doseRepositoryProvider`
// and for the same reason (this spec's own Code Map): a default that quietly
// reported permission as granted would let Home render as if reminders would
// fire when nobody bound a real answer, which is the exact silent-success
// failure AD-14 exists to prevent -- worse here than for `DoseRepository`,
// because the wrong default is not merely empty, it is a false "everything is
// fine".

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/port/permission_gateway.dart';

/// The [PermissionGateway] the app uses.
///
/// **Must be overridden** at the composition root. Reading it without an
/// override throws, loudly, at the first read -- never a plausible default
/// that reports notifications as enabled when nothing real backs that answer.
final Provider<PermissionGateway> permissionGatewayProvider =
    Provider<PermissionGateway>((ref) {
      throw UnimplementedError(
        'permissionGatewayProvider must be overridden at the composition '
        'root. lib/main.dart binds it to '
        'FlutterLocalNotificationsPermissionGateway (AD-17).',
      );
    });
