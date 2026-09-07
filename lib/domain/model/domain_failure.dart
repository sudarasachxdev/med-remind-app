// The root of every typed failure the domain throws.
//
// AD-1: pure Dart, no imports.
//
// The spine's Errors convention names this type: "the domain throws typed
// failures (`sealed class DomainFailure`); adapters translate platform
// exceptions into them at the boundary. No `dynamic` catches. A write failure
// is never swallowed -- per §9 the app must not report a success it did not
// achieve."
//
// Story 1.3 had one port and one way to fail, so the convention was satisfied
// by convention. This story is the second port and the second answer, and a
// feature that wants to catch "anything the domain refused to do" needs one
// type to name. `MedicineRepositoryFailure` sits under this; the next port's
// failures will too.

/// A failure the domain itself decided on, as opposed to an exception a
/// platform threw.
///
/// Subclasses are grouped per port -- see `MedicineRepositoryFailure` -- so
/// `on MedicineRepositoryFailure` catches one port's failures and
/// `on DomainFailure` catches them all.
///
/// `base` rather than `sealed`, which is what the spine's Errors convention
/// names. Measured on Dart 3.12.2: a `sealed` class may only be extended from
/// inside its own library, so every port's failures would have to be declared
/// in this one file -- and the exhaustiveness a `sealed` root buys is
/// unreachable anyway, because no caller ever switches over "any failure from
/// any port". Exhaustiveness is worth having one level down, where a caller
/// really does handle every case, so each port's family root IS `sealed` in the
/// port's own library. `base` keeps the other half of the guarantee: a failure
/// must EXTEND this and cannot merely implement it, so no type can claim to be
/// a DomainFailure without inheriting [toString] and owing the caller a
/// [message].
abstract base class DomainFailure implements Exception {
  const DomainFailure();

  /// A sentence that can be shown to the user as it stands.
  ///
  /// Written in the product's voice (EXPERIENCE.md): it states the fact and not
  /// a judgment, in sentence case, with no exclamation mark, no encouragement
  /// and no clinical phrasing. Every subclass owes the caller a sentence,
  /// because the alternative is a feature inventing its own copy for a case it
  /// cannot see the detail of.
  String get message;

  @override
  String toString() => '$runtimeType: $message';
}
