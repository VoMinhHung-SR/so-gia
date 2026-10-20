import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/app/theme.dart';

void main() {
  test('buildAppTheme largeText + highContrast does not assert', () {
    expect(() => buildAppTheme(largeText: true, highContrast: false), returnsNormally);
    expect(() => buildAppTheme(largeText: false, highContrast: true), returnsNormally);
    expect(() => buildAppTheme(largeText: true, highContrast: true), returnsNormally);
  });
}
