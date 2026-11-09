import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/features/production/shared/widgets/weight_input_dialog.dart';

void main() {
  testWidgets('broker rejects thousandths and accepts comma remainder at two decimals', (tester) async {
    double? saved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      return TextButton(onPressed: () async {
        saved = await WeightInputDialog.show(context, maxWeight: 20 - 17.28, maxDecimalPlaces: 2);
      }, child: const Text('Open'));
    }))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2.719');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Maksimal 2 angka di belakang koma'), findsOneWidget);
    expect(saved, isNull);
    await tester.enterText(find.byType(TextFormField), '2,72');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(saved, 2.72);
    expect(find.byType(WeightInputDialog), findsNothing);
  });
}
