import 'package:flutter_test/flutter_test.dart';
import 'package:lluvia_calculo/models/fall_pace.dart';

void main() {
  group('FallPace', () {
    test('sin ajuste guardado usa la velocidad de siempre', () {
      expect(FallPace.fromSettings(const {}), FallPace.normal);
    });

    test('recupera lenta y muy lenta', () {
      expect(
        FallPace.fromSettings({FallPace.settingsKey: 0.7}),
        FallPace.lenta,
      );
      expect(
        FallPace.fromSettings({FallPace.settingsKey: '0.45'}),
        FallPace.muyLenta,
      );
    });

    test('un valor intermedio se acerca a la opción más próxima', () {
      expect(FallPace.nearest(0.6), FallPace.lenta);
      expect(FallPace.nearest(0.9), FallPace.normal);
    });

    test('lenta alarga la caída y el hueco entre operaciones', () {
      expect(FallPace.lenta.applySpeed(0.10), closeTo(0.07, 0.0001));
      expect(FallPace.lenta.applyInterval(3500), greaterThan(3500));
    });

    test('muy lenta deja aún más tiempo y no se detiene', () {
      final speed = FallPace.muyLenta.applySpeed(0.07);
      expect(speed, lessThan(0.05));
      expect(speed, greaterThanOrEqualTo(0.025));
      expect(FallPace.muyLenta.applyInterval(3200), greaterThan(6000));
    });

    test('normal no cambia la velocidad', () {
      expect(FallPace.normal.applySpeed(0.15), closeTo(0.15, 0.0001));
      expect(FallPace.normal.applyInterval(2800), 2800);
    });
  });
}
