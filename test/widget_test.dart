import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/app.dart';

void main() {
  testWidgets('App boots and shows the M0 placeholder home', (tester) async {
    // Direktang ShuttleQueueApp ang pinu-pump (hindi main()) para hindi
    // kailanganin ang Firebase.initializeApp sa test environment.
    await tester.pumpWidget(const ShuttleQueueApp());
    await tester.pumpAndSettle();

    expect(find.text('ShuttleQueue'), findsOneWidget);
    expect(find.text('Scaffold ready'), findsOneWidget);
  });
}
