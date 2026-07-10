import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single access point para sa Firebase instances. Sa widget tests,
/// ino-override natin ang mga ito ng fakes — kaya bawal ang direktang
/// FirebaseAuth.instance / FirebaseFirestore.instance sa ibang files.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
