# pps_tablet — AGENTS.md

## Project

Flutter app for PPS (manufacturing/warehouse management). One codebase, one APK:
**it adapts to the device** — phones show the ported `pps_mobile` phone UI,
tablets keep the tablet UI. Detection mirrors `wps_tablet_v2`:
`isPhoneDevice()` in `lib/core/utils/device_type.dart` (`MediaQuery.shortestSide < 600`).
Single Flutter project (not a monorepo). Entrypoint: `lib/main.dart`.

## Environment & Build

- **Env files** loaded via `flutter_dotenv` — selection controlled by `APP_ENV` dart-define:
  - `APP_ENV=development` (default) → `.env.development` (server `192.168.11.153:7500`)
  - `APP_ENV=production` → `.env.production` (server `192.168.11.79:7500`)
- **Build APK**: `flutter build apk --release --dart-define=APP_ENV=$APP_ENV`
- **Widget preview** (isolated component development): `flutter run -t lib/preview.dart`
- **Version auto-increment** + APK upload to update server: `./deploy.sh "changelog" [--dev] [--force] [--min <ver>]`
  - `--dev` targets local test server; omit for production
- **Splash/icon generation**: uses `flutter_native_splash` and `flutter_launcher_icons` (config in `pubspec.yaml`)

## Architecture

- **State management**: Provider (`ChangeNotifierProvider` via `MultiProvider` in `lib/main.dart:195`)
- **Feature layout**: `lib/features/<feature>/` with subdirectories `repository/`, `view_model/`, `view/`, and (where present) `model/` and `widgets/` — e.g. `lib/features/production/inject/`
- **Core**: `lib/core/network/` (ApiClient wrapping `package:http`), `lib/core/services/` (token, permissions, dialog, print sync queue), `lib/core/view_model/`
- **Navigation**: named routes in `main.dart` (not Navigator 2.0); `AppNav` key in `lib/core/navigation/app_nav.dart`
- **API auth**: Bearer token stored via `TokenStorage` (Hive/SharedPreferences), attached by `ApiClient`
- **HTTP clients**: `ApiClient` wraps `package:http` for all normal API calls; `dio` is used only for APK download-with-progress in the `update` feature (`lib/features/update/view_model/update_view_model.dart`)
- **Real-time**: Socket.IO (`socket_io_client`) for label print lock sync
- **Local offline queue**: Hive-based `LabelPrintSyncQueue` retries failed print confirmations
- **Localization**: Indonesian locale (`id_ID`), `intl` with `initializeDateFormatting('id_ID')`

## Key Dependencies (non-obvious)

- **Bluetooth thermal printing**: `flutter_blue_plus` + `esc_pos_utils_plus` + `print_bluetooth_thermal` (classic BT, no RawBT)
- **Label scanning**: `mobile_scanner` (camera barcode)
- **SMB file access**: `smb_connect`
- **Printer master list**: fetched from API via `MasterPrinterRepository`

## Adaptive mobile/tablet (merged pps_mobile, 2026-11-09)

- Phone UI = the ported `pps_mobile` codebase under **`lib/mobile/`** (screens, VMs,
  repositories, mobile-only `shared/`, `widgets/`, `constants/`, `utils/`). It keeps the
  old mobile app's relative import graph; package imports were rewritten
  `package:pps_mobile/` → `package:pps_tablet/mobile/`.
- Tablet UI = `lib/features/…` + `lib/core/…` as before (untouched).
- `isPhoneDevice()` (`lib/core/utils/device_type.dart`) picks the shell. Callers pick
  phone routes by MediaQuery at the route builder (`lib/main.dart`), e.g.
  `/home` → `lib/mobile/features/home/view/main_shell.dart` (phone) vs `AppShell` (tablet);
  same device-aware pattern for `/stockopname` and `/mapping`.
- Phone-only named routes exist only for the mobile modules: `/stockopname-v2`
  (SoV2MyLokasiScreen), `/mapping-v2` (MappingV2Screen), `/bj-jual` (BjJualListScreen) —
  pushed by the phone home (`lib/mobile/features/home/view/home_screen.dart`).
- Phone-only VMs/repos are registered in the root `MultiProvider` aliased
  (`as mobile`/`as mobile_*`) next to the tablet ones (mobile classes are identical in name;
  alias avoids clashing imports). Phone pushes carry no Navigator-key semantics; login
  gates `/home` via the route builder (single shared LoginScreen = tablet one, NIK gate included).
- Login screen (shared, both device types) gained the network-mode switcher from
  pps_mobile (`NetworkModeConfig` in `lib/core/network/network_mode_config.dart`):
  `internal` (default; env `DEFAULT_NETWORK_MODE`) / `public` (`pps.padmoasm.com`) / `auto`.
  `endpoints.dart` `ApiConstants.baseUrl` resolves via `NetworkModeConfig.apiBaseUrl`.
  Tap the settings icon on the login screen to switch. New envs in both `.env.*`:
  `API_BASE_URL_INTERNAL`, `API_BASE_URL_PUBLIC`, `UPDATE_BASE_URL_INTERNAL`,
  `UPDATE_BASE_URL_PUBLIC`, `DEFAULT_NETWORK_MODE`.
- pps_mobile itself is untouched (legacy archive). Merged APK installs as "PPS"
  (`android:label="PPS"`, applicationId `com.example.pps_tablet`) — it does NOT replace
  the old `com.example.pps_mobile` install.
- `lib/mobile/**` providers are created in `main.dart`'s root MultiProvider.
  Legacy `test/bs_v2_create_screen_test.dart` was already broken before the merge
  (invalid_override) — unrelated to this change.

## Testing

- **Framework**: `flutter_test`
- **Pattern**: fake repositories (e.g. `FakeGilinganRepository` extending the real repo class) — see `test/gilingan_vm_test.dart`
- **Run**: `flutter test` (tests are minimal; `widget_test.dart` is the default counter stub)

## Lint & Analysis

- `dart analyze` or `flutter analyze` (config: `analysis_options.yaml` with `package:flutter_lints/flutter.yaml`)
- Flutter 3.x with Dart SDK ^3.8.0

## Routes (major)

Defined in `lib/main.dart:551-587`. Key paths:

- `/` → LoginScreen, `/home` → AppShell (sidebar + feature grid)
- `/label` → LabelSelectionScreen, `/production` → ProductionSelectionScreen
- `/stockopname` → StockOpnameListScreen
- Unique dual-route pattern: both `/shell/*` and `/production/*` often map to the same screen

## Deploy Gotchas

- The `deploy.sh` script modifies `pubspec.yaml` (increments version). **Do not commit** after running deploy unless you intend the version bump.
- `UPDATE_TOKEN` env var required (default: `UTAMA-UPDATE-SECRET-123`); passed as `x-update-token` header.
- Server responses at `http://<host>:7500/api/update/tablet/publish`
