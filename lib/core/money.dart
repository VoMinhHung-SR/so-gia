import 'package:intl/intl.dart';

final _vnd = NumberFormat.decimalPattern('vi_VN');

/// Format integer VND as `25.000đ`.
String formatVnd(int amount) => '${_vnd.format(amount)}đ';

/// Parse user input: `25000`, `25.000`, `25,000`, `25k`, `25K`.
/// Returns null if empty or invalid.
int? parseVnd(String raw) {
  var s = raw.trim().toLowerCase().replaceAll('đ', '').replaceAll('d', '');
  if (s.isEmpty) return null;

  var multiplier = 1;
  if (s.endsWith('k')) {
    multiplier = 1000;
    s = s.substring(0, s.length - 1).trim();
    // "25k" ok; reject decimals like "1.5k" for MVP simplicity.
    if (s.contains('.') || s.contains(',')) return null;
  }

  s = s.replaceAll(RegExp(r'[.\s,]'), '');
  if (s.isEmpty || !RegExp(r'^\d+$').hasMatch(s)) return null;

  final value = int.tryParse(s);
  if (value == null) return null;
  return value * multiplier;
}
