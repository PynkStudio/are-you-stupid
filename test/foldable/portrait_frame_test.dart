import 'package:are_you_stupid/ui/widgets/portrait_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<MediaQueryData> pump(
    WidgetTester tester,
    Size size, {
    bool enabled = true,
    EdgeInsets padding = EdgeInsets.zero,
  }) async {
    late MediaQueryData seen;
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size, padding: padding),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: PortraitFrame(
            enabled: enabled,
            child: Builder(
              builder: (context) {
                seen = MediaQuery.of(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    return seen;
  }

  testWidgets('a landscape window shows a portrait column', (tester) async {
    final seen = await pump(
      tester,
      const Size(951, 669),
      padding: const EdgeInsets.only(right: 84, bottom: 34),
    );
    expect(seen.size.width, closeTo(669 * PortraitFrame.widthPerHeight, 0.01));
    expect(seen.size.height, 669);
    // The status bar inset is outside the column; the bottom one still counts.
    expect(seen.padding.right, 0);
    expect(seen.padding.bottom, 34);
  });

  testWidgets('portrait windows and other platforms are untouched', (
    tester,
  ) async {
    expect((await pump(tester, const Size(466, 678))).size.width, 466);
    final off = await pump(tester, const Size(951, 669), enabled: false);
    expect(off.size.width, 951);
  });
}
