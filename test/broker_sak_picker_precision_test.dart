import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/features/production/shared/models/production_label_lookup_result.dart';
import 'package:pps_tablet/features/production/shared/widgets/production_sak_picker_dialog.dart';

void main() {
  testWidgets('shared broker partial picker disables thousandths before submission', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final vm = ChangeNotifier();
    addTearDown(vm.dispose);
    final lookup = ProductionLabelLookupResult.success({
      'prefix': 'D.', 'tableName': 'Broker_d',
      'data': [{'NoBroker': 'D.0000000001', 'NoSak': 1, 'Berat': 15.0}],
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductionSakPickerDialog(
      noProduksi: 'I.1', isPartialMode: true, vm: vm,
      getLookup: () => lookup, willBeDuplicate: (_, __) => false,
      isPicked: (_) => false, hasTemporaryDataForLabel: (_) => false,
      inputsOf: (_) => Object(), isInputsLoading: (_) => false,
      loadInputs: (_) async {}, clearPicks: () {}, togglePick: (_) {},
      commitPickedToTemp: ({required String noProduksi}) => (added: 1, skipped: 0),
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sak 1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '2.719');
    await tester.pumpAndSettle();
    expect(find.text('Maksimal 2 angka di belakang koma'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '2,72');
    await tester.pumpAndSettle();
    expect(find.text('Maksimal 2 angka di belakang koma'), findsNothing);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });
}
