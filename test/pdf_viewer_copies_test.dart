import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pps_tablet/common/widgets/master_printer_selector.dart';
import 'package:pps_tablet/common/widgets/pdf_viewer_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<List<int>> _pdf() async {
  final doc = pw.Document()..addPage(pw.Page(build: (_) => pw.Text('BJ')));
  return doc.save();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, {required int defaultCopies}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bytes = await tester.runAsync(_pdf);
    await tester.pumpWidget(
      MaterialApp(
        home: PdfViewerScreen(
          title: 'BA.0001',
          pdfBytes: Uint8List.fromList(bytes!),
          defaultCopies: defaultCopies,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('BJ label preview starts at 2 copies and can go down to 1', (tester) async {
    await pump(tester, defaultCopies: 2);
    expect(find.byKey(const ValueKey('copies-value')), findsOneWidget);
    expect(find.text('CETAK 2 RANGKAP'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('copies-minus')));
    await tester.pump();
    expect(find.text('CETAK LABEL'), findsOneWidget);
    // Tidak boleh di bawah 1.
    final minus = tester.widget<IconButton>(find.byKey(const ValueKey('copies-minus')));
    expect(minus.onPressed, isNull);
  });

  testWidgets('other labels keep the old screen without a copies picker', (tester) async {
    await pump(tester, defaultCopies: 1);
    expect(find.byKey(const ValueKey('copies-value')), findsNothing);
    expect(find.text('CETAK LABEL'), findsOneWidget);
  });

  test('PrintOutcome defaults to one copy', () {
    expect(PrintOutcome(id: '', mac: 'AA:BB:CC:DD:EE:FF', printerName: 'x').copies, 1);
  });
}
