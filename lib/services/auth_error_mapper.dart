/// Pure mapping ng FirebaseAuthException codes papunta sa app-level errors.
/// Walang Flutter/Firebase imports para unit-testable; ang screen na ang
/// bahalang mag-translate ng enum papuntang localized string.
enum AuthError {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  network,
  tooManyRequests,
  unknown,
}

AuthError mapAuthErrorCode(String code) {
  switch (code) {
    // Pinagsama ang tatlo: hindi natin sinasabi kung ang email o password
    // ang mali — mas ligtas at ganyan din ang bagong Firebase behavior.
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return AuthError.invalidCredentials;
    case 'email-already-in-use':
      return AuthError.emailAlreadyInUse;
    case 'weak-password':
      return AuthError.weakPassword;
    case 'invalid-email':
      return AuthError.invalidEmail;
    case 'network-request-failed':
      return AuthError.network;
    case 'too-many-requests':
      return AuthError.tooManyRequests;
    default:
      return AuthError.unknown;
  }
}
