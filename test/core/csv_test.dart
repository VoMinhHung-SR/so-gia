import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/csv.dart';

void main() {
  test('escape commas quotes and newlines', () {
    expect(escapeCsvField('a,b'), '"a,b"');
    expect(escapeCsvField('say "hi"'), '"say ""hi"""');
    expect(escapeCsvField('line1\nline2'), '"line1\nline2"');
  });

  test('roundtrip encode/parse with BOM', () {
    final csv = encodeCsv(
      headers: ['id', 'name'],
      rows: [
        ['1', 'Nước ngọt'],
        ['2', 'a,b "c"'],
      ],
    );
    expect(csv.startsWith(csvUtf8Bom), isTrue);
    final rows = parseCsv(csv);
    expect(rows.first, ['id', 'name']);
    expect(rows[1], ['1', 'Nước ngọt']);
    expect(rows[2], ['2', 'a,b "c"']);
  });

  test('pickNewer by updated_at', () {
    final older = DateTime.utc(2024, 1, 1);
    final newer = DateTime.utc(2025, 1, 1);
    expect(
      pickNewer(
        local: 'local',
        incoming: 'incoming',
        updatedAtOf: (s) => s == 'local' ? older : newer,
      ),
      'incoming',
    );
    expect(
      pickNewer(
        local: 'local',
        incoming: 'incoming',
        updatedAtOf: (s) => s == 'local' ? newer : older,
      ),
      'local',
    );
  });
}
