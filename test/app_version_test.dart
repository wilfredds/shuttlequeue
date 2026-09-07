import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/app_version.dart';

/// Ang bersyon ay nakasulat sa dalawang lugar: sa `pubspec.yaml` (ito ang
/// napupunta sa APK) at sa `lib/app_version.dart` (ito ang nakikita ng QM
/// sa screen). Kapag naghiwalay sila, magsisinungaling ang app tungkol sa
/// sarili nito — at iyon mismo ang nasa kamay natin kapag may isinusumbong
/// na problema.
///
/// Kaya sa halip na tiwala, test.
void main() {
  test('tugma ang bersyon sa screen at ang bersyon sa pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true)
        .firstMatch(pubspec);

    expect(match, isNotNull, reason: 'walang version: sa pubspec.yaml');

    // "1.0.0+1" -> "1.0.0". Ang bahagi pagkatapos ng + ay ang build number
    // na hinihingi ng Android; hindi iyon ipinapakita sa tao.
    final fromPubspec = match!.group(1)!.split('+').first;

    expect(
      kAppVersion,
      fromPubspec,
      reason: 'Nagbago ang pubspec.yaml pero hindi ang lib/app_version.dart '
          '(o kabaligtaran). Dapat pareho sila.',
    );
  });

  test('ang bersyon ay hugis-semver', () {
    expect(RegExp(r'^\d+\.\d+\.\d+$').hasMatch(kAppVersion), isTrue);
  });
}
