import 'package:are_you_stupid/ui/theme.dart';
import 'package:are_you_stupid/ui/widgets/balanced_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lines a finished layout actually renders, word by word.
List<String> _lines(String text, BalancedLayout l) {
  final p = TextPainter(
    text: TextSpan(text: text, style: l.style),
    textDirection: TextDirection.ltr,
    maxLines: l.lines,
  )..layout(maxWidth: l.width);
  final out = <String>[];
  var start = 0;
  for (final m in p.computeLineMetrics()) {
    final end = p
        .getPositionForOffset(Offset(l.width, m.baseline - m.ascent / 2))
        .offset;
    out.add(text.substring(start, end).trim());
    start = end;
  }
  p.dispose();
  return out;
}

void main() {
  test('a single long word shrinks instead of breaking', () {
    const text = 'IMPOSTAZIONI';
    final l = BalancedText.balance(text, Ays.title(48), 200, maxLines: 1);
    expect(l.lines, 1);
    expect(l.style.fontSize, lessThan(48));
  });

  test('a short title keeps its size', () {
    final l = BalancedText.balance('SETTINGS', Ays.title(20), 300, maxLines: 1);
    expect(l.lines, 1);
    expect(l.style.fontSize, 20);
  });

  test('two-line headlines come out balanced, no orphan word', () {
    const text = 'CONGRATULATIONS, I GUESS';
    final l = BalancedText.balance(text, Ays.title(40), 340, maxLines: 3);
    expect(l.lines, 2);
    expect(_lines(text, l), ['CONGRATULATIONS,', 'I GUESS']);
  });

  test('never splits inside a word', () {
    const text = 'PUNTEGGIO MIGLIORE';
    final l = BalancedText.balance(text, Ays.title(44), 160);
    for (final line in _lines(text, l)) {
      expect(text.split(' '), containsAll(line.split(' ')));
    }
  });

  testWidgets('renders inside a narrow column without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            child: BalancedText(
              'IMPOSTAZIONI',
              style: Ays.title(48),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('IMPOSTAZIONI'), findsOneWidget);
  });
}
