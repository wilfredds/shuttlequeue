import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/services/auth_error_mapper.dart';

void main() {
  group('mapAuthErrorCode', () {
    test('collapses all credential failures into one safe message', () {
      // Hindi natin sinasabi kung ang email o password ang mali —
      // iisang generic na error para sa tatlong codes.
      expect(mapAuthErrorCode('invalid-credential'), AuthError.invalidCredentials);
      expect(mapAuthErrorCode('wrong-password'), AuthError.invalidCredentials);
      expect(mapAuthErrorCode('user-not-found'), AuthError.invalidCredentials);
    });

    test('maps registration errors', () {
      expect(mapAuthErrorCode('email-already-in-use'), AuthError.emailAlreadyInUse);
      expect(mapAuthErrorCode('weak-password'), AuthError.weakPassword);
      expect(mapAuthErrorCode('invalid-email'), AuthError.invalidEmail);
    });

    test('maps operational errors', () {
      expect(mapAuthErrorCode('network-request-failed'), AuthError.network);
      expect(mapAuthErrorCode('too-many-requests'), AuthError.tooManyRequests);
    });

    test('unknown codes never crash — they fall back to unknown', () {
      expect(mapAuthErrorCode('some-future-firebase-code'), AuthError.unknown);
      expect(mapAuthErrorCode(''), AuthError.unknown);
    });
  });
}
