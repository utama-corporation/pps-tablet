import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/core/view_model/label_print_lock_socket_manager.dart';
import 'package:pps_tablet/features/stock_opname_v2/view_model/so_v2_socket_manager.dart';
import 'package:pps_tablet/core/services/label_print_sync_queue.dart';
import 'package:pps_tablet/features/audit/repository/audit_repository.dart';
import 'package:pps_tablet/features/audit/view_model/audit_view_model.dart';
import 'package:pps_tablet/features/bj_jual/repository/bj_jual_input_repository.dart';
import 'package:pps_tablet/features/bj_jual/view_model/bj_jual_input_view_model.dart';
import 'package:pps_tablet/features/bongkar_susun/repository/bongkar_susun_input_repository.dart';
import 'package:pps_tablet/features/bongkar_susun/view_model/bongkar_susun_input_view_model.dart';
import 'package:pps_tablet/features/broker_type/repository/broker_type_repository.dart';
import 'package:pps_tablet/features/broker_type/view_model/broker_type_view_model.dart';
import 'package:pps_tablet/features/crusher_type/repository/crusher_type_repository.dart';
import 'package:pps_tablet/features/crusher_type/view_model/crusher_type_view_model.dart';
import 'package:pps_tablet/features/furniture_wip_type/repository/furniture_wip_type_repository.dart';
import 'package:pps_tablet/features/furniture_wip_type/view_model/furniture_wip_type_view_model.dart';
import 'package:pps_tablet/features/gilingan_type/repository/gilingan_type_repository.dart';
import 'package:pps_tablet/features/gilingan_type/view_model/gilingan_type_view_model.dart';
import 'package:pps_tablet/features/jenis_bonggolan/repository/jenis_bonggolan_repository.dart';
import 'package:pps_tablet/features/jenis_bonggolan/view_model/jenis_bonggolan_view_model.dart';
import 'package:pps_tablet/features/label/bahan_baku/repository/bahan_baku_repository.dart';
import 'package:pps_tablet/features/label/bahan_baku/view/bahan_baku_screen.dart';
import 'package:pps_tablet/features/label/bahan_baku/view_model/bahan_baku_view_model.dart';
import 'package:pps_tablet/features/label/bonggolan/repository/bonggolan_repository.dart';
import 'package:pps_tablet/features/label/bonggolan/view/bonggolan_screen.dart';
import 'package:pps_tablet/features/label/bonggolan/view_model/bonggolan_view_model.dart';
import 'package:pps_tablet/features/label/broker/repository/broker_repository.dart';
import 'package:pps_tablet/features/label/broker/view/broker_screen.dart';
import 'package:pps_tablet/features/label/broker/view_model/broker_view_model.dart';
import 'package:pps_tablet/features/label/furniture_wip/repository/furniture_wip_repository.dart';
import 'package:pps_tablet/features/label/furniture_wip/view/furniture_wip_screen.dart';
import 'package:pps_tablet/features/label/furniture_wip/view_model/furniture_wip_view_model.dart';
import 'package:pps_tablet/features/label/gilingan/repository/gilingan_repository.dart';
import 'package:pps_tablet/features/label/gilingan/view_model/gilingan_view_model.dart';
import 'package:pps_tablet/features/label/mixer/repository/mixer_repository.dart';
import 'package:pps_tablet/features/label/mixer/view/mixer_screen.dart';
import 'package:pps_tablet/features/label/mixer/view_model/mixer_view_model.dart';
import 'package:pps_tablet/features/label/packing/repository/packing_repository.dart';
import 'package:pps_tablet/features/label/packing/view/packing_screen.dart';
import 'package:pps_tablet/features/label/packing/view_model/packing_view_model.dart';
import 'package:pps_tablet/features/label/reject/repository/reject_repository.dart';
import 'package:pps_tablet/features/label/reject/view/reject_screen.dart';
import 'package:pps_tablet/features/label/reject/view_model/reject_view_model.dart';
import 'package:pps_tablet/features/mesin/repository/mesin_repository.dart';
import 'package:pps_tablet/features/mesin/view_model/mesin_view_model.dart';
import 'package:pps_tablet/features/mapping/view/mapping_screen.dart';
import 'package:pps_tablet/features/goods_transfer/view/goods_transfer_list_screen.dart';
import 'package:pps_tablet/features/warehouse_group/view/warehouse_group_screen.dart';
import 'package:pps_tablet/features/in_transit/view/in_transit_list_screen.dart';
import 'package:pps_tablet/features/mixer_type/repository/mixer_type_repository.dart';
import 'package:pps_tablet/features/mixer_type/view_model/mixer_type_view_model.dart';
import 'package:pps_tablet/features/operator/repository/operator_repository.dart';
import 'package:pps_tablet/features/operator/view_model/operator_view_model.dart';
import 'package:pps_tablet/features/regu/repository/regu_repository.dart';
import 'package:pps_tablet/features/regu/view_model/regu_view_model.dart';
import 'package:pps_tablet/features/supplier/repository/supplier_repository.dart';
import 'package:pps_tablet/features/supplier/view_model/supplier_view_model.dart';
import 'package:pps_tablet/features/packing_type/repository/packing_type_repository.dart';
import 'package:pps_tablet/features/packing_type/view_model/packing_type_view_model.dart';
import 'package:pps_tablet/features/washing_type/repository/washing_type_repository.dart';
import 'package:pps_tablet/features/washing_type/view_model/washing_type_view_model.dart';
import 'package:pps_tablet/features/pembeli/repository/pembeli_repository.dart';
import 'package:pps_tablet/features/pembeli/view_model/pembeli_view_model.dart';
import 'package:pps_tablet/features/production/broker/repository/broker_production_input_repository.dart';
import 'package:pps_tablet/features/production/broker/view_model/broker_production_input_view_model.dart';
import 'package:pps_tablet/features/production/crusher/repository/crusher_production_input_repository.dart';
import 'package:pps_tablet/features/production/crusher/repository/crusher_production_repository.dart';
import 'package:pps_tablet/features/production/crusher/view/crusher_production_screen.dart';
import 'package:pps_tablet/features/production/crusher/view_model/crusher_production_input_view_model.dart';
import 'package:pps_tablet/features/production/crusher/view_model/crusher_production_view_model.dart';
import 'package:pps_tablet/features/production/gilingan/repository/gilingan_production_repository.dart';
import 'package:pps_tablet/features/production/gilingan/view/gilingan_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/gilingan/view_model/gilingan_production_input_view_model.dart';
import 'package:pps_tablet/features/production/gilingan/view_model/gilingan_production_view_model.dart';
import 'package:pps_tablet/features/production/hot_stamp/model/hot_stamp_production_model.dart';
import 'package:pps_tablet/features/production/hot_stamp/repository/hot_stamp_production_input_repository.dart';
import 'package:pps_tablet/features/production/hot_stamp/repository/hot_stamp_production_repository.dart';
import 'package:pps_tablet/features/production/hot_stamp/view/hot_stamp_production_screen.dart';
import 'package:pps_tablet/features/production/hot_stamp/view_model/hot_stamp_production_input_view_model.dart';
import 'package:pps_tablet/features/production/hot_stamp/view_model/hot_stamp_production_view_model.dart';
import 'package:pps_tablet/features/production/inject/repository/inject_production_input_repository.dart';
import 'package:pps_tablet/features/production/inject/repository/inject_production_repository.dart';
import 'package:pps_tablet/features/production/inject/view/inject_production_screen.dart';
import 'package:pps_tablet/features/production/inject/view_model/inject_production_input_view_model.dart';
import 'package:pps_tablet/features/production/inject/view_model/inject_formula_view_model.dart';
import 'package:pps_tablet/features/production/inject/view_model/inject_production_view_model.dart';
import 'package:pps_tablet/features/production/key_fitting/repository/key_fitting_production_input_repository.dart';
import 'package:pps_tablet/features/production/key_fitting/repository/key_fitting_production_repository.dart';
import 'package:pps_tablet/features/production/key_fitting/view/key_fitting_production_screen.dart';
import 'package:pps_tablet/features/production/key_fitting/view_model/key_fitting_production_input_view_model.dart';
import 'package:pps_tablet/features/production/key_fitting/view_model/key_fitting_production_view_model.dart';
import 'package:pps_tablet/features/production/mixer/repository/mixer_production_input_repository.dart';
import 'package:pps_tablet/features/production/mixer/repository/mixer_production_repository.dart';
import 'package:pps_tablet/features/production/mixer/view/mixer_production_screen.dart';
import 'package:pps_tablet/features/production/mixer/view_model/mixer_production_input_view_model.dart';
import 'package:pps_tablet/features/production/mixer/view_model/mixer_production_view_model.dart';
import 'package:pps_tablet/features/production/packing/repository/packing_production_input_repository.dart';
import 'package:pps_tablet/features/production/packing/repository/packing_production_repository.dart';
import 'package:pps_tablet/features/production/packing/view/packing_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/packing/view_model/packing_production_input_view_model.dart';
import 'package:pps_tablet/features/production/packing/view_model/packing_production_view_model.dart';
import 'package:pps_tablet/features/production/return/repository/return_production_repository.dart';
import 'package:pps_tablet/features/production/return/view/return_production_screen.dart';
import 'package:pps_tablet/features/production/return/view_model/return_production_view_model.dart';
import 'package:pps_tablet/features/production/selection/view/production_selection_screen.dart';
import 'package:pps_tablet/features/production/sortir_reject/model/sortir_reject_production_model.dart';
import 'package:pps_tablet/features/production/sortir_reject/repository/sortir_reject_production_input_repository.dart';
import 'package:pps_tablet/features/production/sortir_reject/repository/sortir_reject_production_repository.dart';
import 'package:pps_tablet/features/production/sortir_reject/view/sortir_reject_production_screen.dart';
import 'package:pps_tablet/features/production/sortir_reject/view_model/sortir_reject_production_input_view_model.dart';
import 'package:pps_tablet/features/production/sortir_reject/view_model/sortir_reject_production_view_model.dart';
import 'package:pps_tablet/features/production/spanner/repository/spanner_production_input_repository.dart';
import 'package:pps_tablet/features/production/spanner/repository/spanner_production_repository.dart';
import 'package:pps_tablet/features/production/spanner/view/spanner_production_screen.dart';
import 'package:pps_tablet/features/production/spanner/view_model/spanner_production_input_view_model.dart';
import 'package:pps_tablet/features/production/spanner/view_model/spanner_production_view_model.dart';
import 'package:pps_tablet/features/production/washing/repository/washing_production_input_repository.dart';
import 'package:pps_tablet/features/production/washing/view/washing_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/washing/view_model/washing_production_input_view_model.dart';
import 'package:pps_tablet/features/reject_type/repository/reject_type_repository.dart';
import 'package:pps_tablet/features/reject_type/view_model/reject_type_view_model.dart';
import 'package:pps_tablet/features/production/broker/repository/broker_production_repository.dart';
import 'package:pps_tablet/features/production/broker/view_model/broker_production_view_model.dart';
import 'package:pps_tablet/features/shared/lokasi/lokasi_repository.dart';
import 'package:pps_tablet/features/shared/max_sak/max_sak_repository.dart';
import 'package:pps_tablet/features/shared/max_sak/max_sak_service.dart';
import 'package:pps_tablet/features/production/washing/repository/washing_production_repository.dart';
import 'package:pps_tablet/features/production/washing/view_model/washing_production_view_model.dart';
import 'package:pps_tablet/features/shared/overlap/repository/overlap_repository.dart';
import 'package:pps_tablet/features/shared/overlap/view_model/overlap_view_model.dart';
import 'package:pps_tablet/features/warehouse/repository/warehouse_repository.dart';
import 'package:pps_tablet/features/warehouse/view_model/warehouse_view_model.dart';
import 'package:provider/provider.dart';

// ⬇️ Tambahan untuk locale & tanggal Indonesia
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// === imports kamu yang lain ===
import 'package:pps_tablet/features/label/selection/view/label_selection_screen.dart';
import 'package:pps_tablet/features/label/washing/repository/washing_repository.dart';
import 'package:pps_tablet/features/label/washing/view/washing_screen.dart';
import 'package:pps_tablet/features/label/washing/view_model/washing_view_model.dart';
import 'package:pps_tablet/features/shared/plastic_type/jenis_plastik_repository.dart';
import 'package:pps_tablet/features/shared/plastic_type/jenis_plastik_view_model.dart';
import 'package:pps_tablet/features/stock_opname/repository/stock_opname_ascend_repository.dart';
import 'package:pps_tablet/features/stock_opname/repository/stock_opname_family_repository.dart';
import 'package:pps_tablet/features/stock_opname/repository/stock_opname_repository.dart';
import 'package:pps_tablet/features/stock_opname/view_model/stock_opname_ascend_view_model.dart';
import 'package:pps_tablet/features/stock_opname/view_model/stock_opname_family_view_model.dart';
import 'core/navigation/app_nav.dart';
import 'core/network/api_client.dart';
import 'core/utils/master_printer_repository.dart';
import 'features/bongkar_susun/repository/bongkar_susun_repository.dart';
import 'features/bongkar_susun/view_model/bongkar_susun_view_model.dart';
import 'features/label/crusher/repository/crusher_repository.dart';
import 'features/label/crusher/view/crusher_screen.dart';
import 'features/label/crusher/view_model/crusher_view_model.dart';
import 'features/label/gilingan/view/gilingan_screen.dart';
import 'features/login/view/login_screen.dart';
import 'features/production/broker/view/broker_production_screen.dart';
import 'features/production/gilingan/repository/gilingan_production_input_repository.dart';
import 'features/shared/lokasi/lokasi_view_model.dart';
import 'features/stock_opname/view/stock_opname_list_screen.dart';
import 'core/view/app_shell.dart';
import 'features/stock_opname/view_model/stock_opname_list_view_model.dart';
import 'features/stock_opname/view_model/stock_opname_detail_view_model.dart';
import 'features/stock_opname/view_model/stock_opname_label_before_view_model.dart';
import 'features/home/view_model/user_profile_view_model.dart';
import 'features/stock_opname/view_model/socket_manager.dart';
import 'features/stock_opname/view_model/label_detail_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Env by mode: development (default) | production
  const appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  final envFile = appEnv == 'production'
      ? '.env.production'
      : '.env.development';
  await dotenv.load(fileName: envFile);
  await Hive.initFlutter();

  // Locale Indonesia untuk nama hari/bulan (Intl)
  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 🔹 Sediakan ApiClient sekali untuk seluruh app
        Provider<ApiClient>(create: (_) => ApiClient()),
        Provider<MasterPrinterRepository>(
          create: (ctx) => MasterPrinterRepository(api: ctx.read<ApiClient>()),
        ),

        ChangeNotifierProvider(
          create: (_) =>
              StockOpnameViewModel(repository: StockOpnameRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => StockOpnameLabelBeforeViewModel(),
        ),
        ChangeNotifierProvider(create: (_) => StockOpnameDetailViewModel()),
        ChangeNotifierProvider(create: (_) => UserProfileViewModel()),
        ChangeNotifierProvider(
          create: (_) => LokasiViewModel(repository: LokasiRepository()),
        ),
        ChangeNotifierProvider(create: (_) => SocketManager()),
        ChangeNotifierProvider(
          create: (_) => LabelPrintLockSocketManager()..connect(),
        ),
        ChangeNotifierProvider(
          create: (_) => SoV2SocketManager()..connect(),
        ),
        ChangeNotifierProvider(create: (_) => LabelPrintSyncQueue()..start()),
        ChangeNotifierProvider(create: (_) => LabelDetailViewModel()),
        ChangeNotifierProvider(
          create: (_) => StockOpnameAscendViewModel(
            repository: StockOpnameAscendRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StockOpnameFamilyViewModel(
            repository: StockOpnameFamilyRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WashingViewModel(repository: WashingRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              JenisPlastikViewModel(repository: JenisPlastikRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => WashingProductionViewModel(
            repository: WashingProductionRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => WashingProductionInputViewModel(
            repository: WashingProductionInputRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              BongkarSusunViewModel(repository: BongkarSusunRepository()),
        ),
        Provider<MaxSakService>(
          create: (_) => MaxSakService(MaxSakRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => PermissionViewModel()..loadPermissions(),
        ),
        ChangeNotifierProvider<BahanBakuViewModel>(
          create: (ctx) => BahanBakuViewModel(
            repository: BahanBakuRepository(api: ctx.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider<BrokerViewModel>(
          create: (ctx) => BrokerViewModel(
            repository: BrokerRepository(api: ctx.read<ApiClient>()),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BonggolanViewModel(repository: BonggolanRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => CrusherViewModel(repository: CrusherRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => CrusherProductionInputViewModel(
            repository: CrusherProductionInputRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BrokerProductionViewModel(
            repository: BrokerProductionRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => BrokerProductionInputViewModel(
            repository: BrokerProductionInputRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              JenisBonggolanViewModel(repository: JenisBonggolanRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => CrusherProductionViewModel(
            repository: CrusherProductionRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              CrusherTypeViewModel(repository: CrusherTypeRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              BrokerTypeViewModel(repository: BrokerTypeRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              WashingTypeViewModel(repository: WashingTypeRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => MesinViewModel(repository: MesinRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => OperatorViewModel(repository: OperatorRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => ReguViewModel(repository: ReguRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => SupplierViewModel(repository: SupplierRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => PembeliViewModel(repository: PembeliRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => WarehouseViewModel(repository: WarehouseRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => OverlapViewModel(repository: OverlapRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => MixerViewModel(repository: MixerRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              MixerProductionViewModel(repository: MixerProductionRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => MixerTypeViewModel(repository: MixerTypeRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => GilinganViewModel(repository: GilinganRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              GilinganTypeViewModel(repository: GilinganTypeRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => GilinganProductionViewModel(
            repository: GilinganProductionRepository(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              FurnitureWipViewModel(repository: FurnitureWipRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => BongkarSusunInputViewModel(
            repository: BongkarSusunInputRepository(),
          ),
        ),

        ChangeNotifierProvider<HotStampProductionViewModel>(
          create: (ctx) => HotStampProductionViewModel(
            repository: HotStampProductionRepository(
              api: ctx.read<ApiClient>(),
            ),
          ),
        ),

        ChangeNotifierProvider<HotStampingProductionInputViewModel>(
          create: (ctx) => HotStampingProductionInputViewModel(
            repository: HotStampingProductionInputRepository(),
          ),
        ),

        ChangeNotifierProvider<InjectProductionInputViewModel>(
          create: (ctx) => InjectProductionInputViewModel(
            repository: InjectProductionInputRepository(),
          ),
        ),

        ChangeNotifierProvider<InjectFormulaViewModel>(
          create: (_) => InjectFormulaViewModel(),
        ),

        ChangeNotifierProvider<SpannerProductionViewModel>(
          create: (ctx) => SpannerProductionViewModel(
            repository: SpannerProductionRepository(api: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<SpannerProductionInputViewModel>(
          create: (ctx) => SpannerProductionInputViewModel(
            repository: SpannerProductionInputRepository(),
          ),
        ),

        ChangeNotifierProvider<KeyFittingProductionViewModel>(
          create: (ctx) => KeyFittingProductionViewModel(
            repository: KeyFittingProductionRepository(
              api: ctx.read<ApiClient>(),
            ),
          ),
        ),

        ChangeNotifierProvider<KeyFittingProductionInputViewModel>(
          create: (ctx) => KeyFittingProductionInputViewModel(
            repository: KeyFittingProductionInputRepository(),
          ),
        ),

        ChangeNotifierProvider<ReturnProductionViewModel>(
          create: (ctx) => ReturnProductionViewModel(
            repository: ReturnProductionRepository(api: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<FurnitureWipTypeViewModel>(
          create: (ctx) => FurnitureWipTypeViewModel(
            repository: FurnitureWipTypeRepository(api: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<PackingViewModel>(
          create: (ctx) => PackingViewModel(
            repository: PackingRepository(api: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<PackingProductionViewModel>(
          create: (ctx) => PackingProductionViewModel(
            repository: PackingProductionRepository(api: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<PackingProductionInputViewModel>(
          create: (ctx) => PackingProductionInputViewModel(
            repository: PackingProductionInputRepository(
              apiClient: ctx.read<ApiClient>(),
            ),
          ),
        ),

        ChangeNotifierProvider<BJJualInputViewModel>(
          create: (ctx) => BJJualInputViewModel(
            repository: BJJualInputRepository(apiClient: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<PackingTypeViewModel>(
          create: (ctx) => PackingTypeViewModel(
            repository: PackingTypeRepository(api: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<InjectProductionViewModel>(
          create: (ctx) => InjectProductionViewModel(
            repository: InjectProductionRepository(),
          ),
        ),

        ChangeNotifierProvider<RejectViewModel>(
          create: (ctx) => RejectViewModel(
            repository: RejectRepository(api: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<RejectTypeViewModel>(
          create: (ctx) => RejectTypeViewModel(
            repository: RejectTypeRepository(api: ctx.read<ApiClient>()),
          ),
        ),

        ChangeNotifierProvider<SortirRejectProductionViewModel>(
          create: (ctx) => SortirRejectProductionViewModel(
            repository: SortirRejectProductionRepository(
              api: ctx.read<ApiClient>(),
            ),
          ),
        ),

        ChangeNotifierProvider<SortirRejectInputViewModel>(
          create: (ctx) => SortirRejectInputViewModel(
            repository: SortirRejectInputRepository(
              apiClient: ctx.read<ApiClient>(),
            ),
          ),
        ),

        ChangeNotifierProvider<GilinganProductionInputViewModel>(
          create: (ctx) => GilinganProductionInputViewModel(
            repository: GilinganProductionInputRepository(
              apiClient: ctx.read<ApiClient>(),
            ),
          ),
        ),

        ChangeNotifierProvider<MixerProductionInputViewModel>(
          create: (ctx) => MixerProductionInputViewModel(
            repository: MixerProductionInputRepository(
              apiClient: ctx.read<ApiClient>(),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'PPS Tablet',
        navigatorKey: AppNav.key,

        // 🎨 THEME: pakai biru sebagai warna utama + atur default button
        theme: ThemeData(
          useMaterial3: true, // boleh kamu ganti false kalau belum mau M3
          // Warna utama seluruh aplikasi
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0), // 🔵 biru utama
            brightness: Brightness.light,
          ),

          // ElevatedButton default → biru
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),

          // FilledButton default → biru
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),

          // TextButton default → teks biru
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
            ),
          ),
        ),

        // ⬇️ Aktifkan localization supaya showDatePicker & widgets lain pakai bahasa Indo
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('id', 'ID'), Locale('en', 'US')],
        locale: const Locale('id', 'ID'),

        initialRoute: '/',
        routes: {
          '/': (context) => LoginScreen(),
          '/home': (context) => const AppShell(),
          '/stockopname': (context) => StockOpnameListScreen(),
          '/label': (context) => LabelSelectionScreen(),
          '/label/bahan-baku': (context) => BahanBakuScreen(),
          '/label/washing': (context) => WashingTableScreen(),
          '/label/broker': (context) => BrokerScreen(),
          '/label/bonggolan': (context) => BonggolanScreen(),
          '/label/crusher': (context) => CrusherScreen(),
          '/label/gilingan': (context) => GilinganScreen(),
          '/label/mixer': (context) => MixerScreen(),
          '/label/furniture_wip': (context) => FurnitureWipScreen(),
          '/production': (context) => ProductionSelectionScreen(),
          '/production/washing': (context) =>
              const WashingProductionMesinScreen(),
          '/production/broker': (context) => BrokerProductionScreen(),
          '/production/crusher': (context) => CrusherProductionScreen(),
          '/label/packing': (context) => PackingScreen(),
          '/label/reject': (context) => RejectScreen(),
          '/production/gilingan': (context) => const GilinganProductionMesinScreen(),
          '/production/mixer': (context) => MixerProductionScreen(),
          '/shell/hot-stamp': (context) => HotStampProductionScreen(),
          '/production/hot-stamp': (context) => HotStampProductionScreen(),
          '/production/inject': (context) => InjectProductionScreen(),
          '/shell/key-fitting': (context) => KeyFittingProductionScreen(),
          '/production/key-fitting': (context) => KeyFittingProductionScreen(),
          '/shell/spanner': (context) => SpannerProductionScreen(),
          '/production/spanner': (context) => SpannerProductionScreen(),
          '/shell/packing': (context) => PackingProductionMesinScreen(),
          '/production/packing': (context) => PackingProductionMesinScreen(),
          '/production/sortir-reject': (context) =>
              SortirRejectProductionScreen(),
          '/shell/return': (context) => ReturnProductionScreen(),
          '/production/return': (context) => ReturnProductionScreen(),
          '/shell/mapping': (context) => const MappingScreen(),
          '/shell/goods-transfer': (context) => const GoodsTransferListScreen(),
          '/shell/warehouse-group': (context) => const WarehouseGroupScreen(),
          '/shell/in-transit': (context) => const InTransitListScreen(),
        },
      ),
    );
  }
}
