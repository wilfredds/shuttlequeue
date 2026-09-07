/// Ang bersyon ng app, ipinapakita sa sign-in screen.
///
/// Bakit const at hindi `package_info_plus`? Isang dependency lang iyon
/// para sa isang string, at may bigat iyon sa web. Ang panganib ng const
/// ay malilimutan itong i-update — kaya may test na naghahambing nito sa
/// `pubspec.yaml` at bumabagsak kapag naghiwalay sila.
///
/// Semantic versioning: MAJOR.MINOR.PATCH.
///   MAJOR — nagbago ang hugis ng datos sa Firestore (tingnan ang
///           production-readiness.md tungkol sa migrations).
///   MINOR — bagong tampok na hindi sumisira ng luma.
///   PATCH — ayos lang ng bug.
const kAppVersion = '1.0.0';
