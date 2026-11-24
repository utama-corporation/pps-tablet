import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/features/kpi/model/kpi.dart';
import 'package:pps_tablet/features/kpi/repository/kpi_repository.dart';
import 'package:pps_tablet/features/kpi/view/kpi_screen.dart';

class FakeKpiRepository extends KpiRepository {
  FakeKpiRepository() : super(api: ApiClient());
  final List<String> calls = [];
  Object? error;
  KpiResult result = KpiResult.fromJson({
    'from': '2026-11-01',
    'to': '2026-11-22',
    'kpis': [
      {
        'key': 'washing',
        'label': 'Washing',
        'unit': 'kg',
        'input': 71992.75,
        'output': 66597,
        'metrics': [
          {'key': 'rendemen', 'label': 'Rendemen', 'value': 92.51, 'unit': '%', 'good': 'high'},
          {'key': 'waste', 'label': 'Waste', 'value': 7.94, 'unit': '%', 'good': 'low'},
        ],
        'rows': [
          {'mesin': 'MESIN WASHING 3', 'input': 56686.84, 'output': 51911, 'rendemen': 91.58, 'waste': 8.99, 'dokumen': null},
        ],
      },
      {
        'key': 'inject',
        'label': 'Inject',
        'unit': 'pcs',
        'input': null,
        'output': 351041,
        'metrics': [
          {'key': 'reject_per_1000', 'label': 'Reject per 1.000 pcs', 'value': 18.09, 'unit': 'kg', 'good': 'low'},
        ],
        'rows': [
          {'mesin': 'MESIN INJECT 19', 'pcs': 4599, 'reject': 1978.79, 'rejectPer1000': 430.27, 'dokumen': 43},
        ],
      },
      {'key': 'broker', 'label': 'Broker', 'error': 'Data belum dapat dimuat.', 'metrics': [], 'rows': []},
    ],
  });

  @override
  Future<KpiResult> load(String tanggal) async {
    calls.add(tanggal);
    if (error != null) throw error!;
    return result;
  }
}

Future<void> pump(WidgetTester tester, FakeKpiRepository repo) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: KpiScreen(repository: repo, initialDate: DateTime(2026, 11, 22, 15)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loads month-to-date KPI for the chosen day', (tester) async {
    final repo = FakeKpiRepository();
    await pump(tester, repo);
    expect(repo.calls, ['2026-11-22']);
    expect(find.text('92.51%'), findsOneWidget);
    expect(find.text('7.94%'), findsOneWidget);
    expect(find.text('MESIN WASHING 3'), findsOneWidget);
    expect(find.text('18.09 kg'), findsOneWidget);
    expect(find.text('430.27'), findsOneWidget);
    expect(find.text('Reject / 1.000 pcs (kg)'), findsOneWidget);
  });

  testWidgets('a failing KPI shows its error, others still render', (tester) async {
    await pump(tester, FakeKpiRepository());
    expect(find.text('Data belum dapat dimuat.'), findsOneWidget);
    expect(find.byKey(const ValueKey('kpi-washing')), findsOneWidget);
  });

  testWidgets('load failure shows retry', (tester) async {
    final repo = FakeKpiRepository()..error = ApiException(500, 'x');
    await pump(tester, repo);
    expect(find.text('KPI belum dapat dimuat'), findsOneWidget);
    repo.error = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('92.51%'), findsOneWidget);
  });

  test('model tolerates missing numbers', () {
    final b = KpiBlock.fromJson({
      'key': 'mixer',
      'label': 'Mixer',
      'metrics': [
        {'key': 'rendemen', 'label': 'Rendemen', 'value': null, 'unit': '%'},
      ],
      'rows': [
        {'mesin': 'M1', 'output': '12.5'},
      ],
    });
    expect(b.metrics.single.value, isNull);
    expect(b.metrics.single.good, 'high');
    expect(b.rows.single.output, 12.5);
  });
}
