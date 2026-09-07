import 'package:flutter_test/flutter_test.dart';
import 'package:shuttlequeue/services/account_security.dart';

void main() {
  group('ratePassword — haba muna, hindi listahan ng panuntunan', () {
    test('kulang sa walo: tinatanggihan', () {
      expect(ratePassword(''), PasswordStrength.tooShort);
      expect(ratePassword('abc'), PasswordStrength.tooShort);
      expect(ratePassword('1234567'), PasswordStrength.tooShort);
    });

    test('walo ang minimum — eksaktong walo ay pasado na', () {
      expect(ratePassword('12345678'), isNot(PasswordStrength.tooShort));
    });

    test('walong pare-pareho ang uri: mahina', () {
      expect(ratePassword('12345678'), PasswordStrength.weak);
      expect(ratePassword('badminton'), PasswordStrength.weak);
    });

    test('may halo at sapat ang haba: ayos na', () {
      expect(ratePassword('Shuttle22'), PasswordStrength.fair);
    });

    test('mahaba ang panalo kahit walang simbolo', () {
      // Ito ang buong punto: mas matibay ang mahabang parirala kaysa
      // sa maikling `P@ss1!` na hinihingi ng ibang app.
      expect(ratePassword('paluinmoyanshuttle'), PasswordStrength.strong);
    });

    test('labindalawa na may halo: matibay', () {
      expect(ratePassword('Shuttlecock12'), PasswordStrength.strong);
    });

    test('labindalawa na iisa ang uri: hindi pa matibay', () {
      expect(ratePassword('aaaaaaaaaaaa'), PasswordStrength.fair);
    });
  });

  group('signInLockout — dahan-dahang pagbagal', () {
    test('walang parusa sa unang apat — nagkakamali ang tao', () {
      for (var i = 0; i <= 4; i++) {
        expect(signInLockout(i), Duration.zero, reason: 'sa $i na palya');
      }
    });

    test('sa ikalima, nagsisimula ang paghihintay', () {
      expect(signInLockout(5), const Duration(seconds: 15));
    });

    test('dumodoble sa bawat susunod', () {
      expect(signInLockout(6), const Duration(seconds: 30));
      expect(signInLockout(7), const Duration(seconds: 60));
      expect(signInLockout(8), const Duration(seconds: 120));
    });

    test('may takda sa limang minuto — hindi habambuhay na pagka-lock', () {
      expect(signInLockout(9), const Duration(seconds: 240));
      expect(signInLockout(10), const Duration(seconds: 300));
      expect(signInLockout(50), const Duration(seconds: 300));
    });
  });

  group('looksLikeEmail — maluwag nang sinasadya', () {
    test('tinatanggap ang mga tunay na address', () {
      expect(looksLikeEmail('coach@gmail.com'), isTrue);
      expect(looksLikeEmail('france+queue@gmail.com'), isTrue);
      expect(looksLikeEmail('qm@smashmate.com.ph'), isTrue);
      expect(looksLikeEmail('  coach@gmail.com  '), isTrue);
    });

    test('tinatanggihan ang malinaw na mali', () {
      expect(looksLikeEmail(''), isFalse);
      expect(looksLikeEmail('coach'), isFalse);
      expect(looksLikeEmail('coach@'), isFalse);
      expect(looksLikeEmail('coach@gmail'), isFalse);
      expect(looksLikeEmail('coach gmail.com'), isFalse);
    });
  });

  group('normalizeEmail', () {
    test('inaalis ang espasyo at ibinababa ang titik', () {
      // Ang paste mula sa Messenger ay may espasyo; ang keyboard ng
      // telepono ay nagmamalaki ng unang titik. Pareho itong nagdudulot
      // ng "walang ganyang account" na nakakalito.
      expect(normalizeEmail('  Coach@Gmail.Com '), 'coach@gmail.com');
    });
  });
}
