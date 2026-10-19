import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/vietnamese.dart';

void main() {
  test('removeDiacritics', () {
    expect(removeDiacritics('Nước ngọt'), 'nuoc ngot');
    expect(removeDiacritics('Đậu xanh'), 'dau xanh');
  });

  test('matchesSearch accent-insensitive', () {
    expect(matchesSearch('Nước ngọt Coca', 'nuoc'), isTrue);
    expect(matchesSearch('Đậu xanh', 'dau'), isTrue);
    expect(matchesSearch('Bánh mì', 'banh'), isTrue);
    expect(matchesSearch('Bánh mì', 'sua'), isFalse);
  });

  test('matchesSearchTokens prefix and multi-word', () {
    expect(matchesSearchTokens('Nước mắm Nam Ngư', 'nuoc mam'), isTrue);
    expect(matchesSearchTokens('Dầu đậu nành', 'dau an'), isTrue);
    expect(matchesSearchTokens('Thịt ba rọi', 'ba roi'), isTrue);
    expect(matchesSearchTokens('Thịt ba rọi', 'sua'), isFalse);
  });
}
