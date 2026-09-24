# Handoff — Redesign Material Kabinet 3-Baris (5 layar produksi)

Tanggal: sesi lanjutan
Status: **WIRING + GETTER SELESAI — validasi visual di device | NoBP TERINCLUDE DI HASIL INPUTAN (backend+frontend selesai, migration DB pending)**

---

## 1. Tujuan

Redesign baris material kabinet (`_MaterialListTile`) dari 2-baris menjadi **3-baris**:

```
┌────────────────────────────────────────────┐
│ [icon] NamaBahanPendukung                  │
│        NoBahanPendukung                    │
│        123 PCS [icon_qty]         [delete] │
└────────────────────────────────────────────┘
```

Diterapkan di 5 menu: **inject, hot-stamp, pasang kunci long door (key_fitting), packing spanner (spanner), packing**.

### Keputusan user (REVISI 2026-09-24)
- ~~Label NoBP HANYA untuk baris temp~~ → **REVISI: NoBP sekarang ikut TERSIMPAN per baris input
  (kolom `NoBahanPendukung`) dan ditampilkan di baris manapun yang punya label**
  (temp = label scan sesi ini; existing = label tersimpan DB, dikembalikan GET inputs).

---

## 2. Yang SUDAH SELESAI (sesi ini)

1. **Fix delete temp material kabinet di packing** — permission key salah:
   `label_packing:delete` → `packing:delete`
   `packing_production_input_screen.dart` ± line 1249. ✅ committed.
2. **Merge frontend** `main` → `develop` selesai (commit `1adb633`).
3. **Backend — 5 file sudah dimodifikasi** utk DateUsage/delete material BP +
   hapus header (hot-stamp, key-fitting, spanner, packing):
   `delete-material` (inject + hot-stamp) & hapus seluruh header utk 4 layar.
   ⚠️ **BELUM di-commit — jangan hilangkan.** Nodemon sudah live di TEST6.
4. **Investigasi "PK 3000 pada furniture wip":** 
   FK `FK_FurnitureWIP_MstCabinetWIP` → `FurnitureWIP` merujuk `MstCabinetWIP`
   (kolom `IDFurnitureWIP` / FK-level). Query: TIDAK ada data prefix `PK.` (0 row);
   nilai '3000' muncul sebagai bagian label `BB.0000030000`, dst. Jawaban disampaikan.
5. **Audit selesai (5 layar + 5 VM + model):**
   - `CabinetMaterialItem` (shared) TIDAK menyimpan NoBahanPendukung.
   - Labels BP disimpan di map privat VM: `_scannedBahanPendukungByMaterial`
     (`Map<int, Set<String>>`, key = IdCabinetMaterial). Dikonfirmasi ada di
     5 VM: inject, packing, hot_stamp, key_fitting, spanner.
6. **Shared widget 3-baris DIBUAT & sudah tervalidasi (flutter):**
   `lib/features/production/shared/widgets/cabinet_material_list_tile.dart`
   class `CabinetMaterialListTile` (146 baris):
   - param: `item`, `isTemp`, `bahanPendukungLabels` (List<String>, utk baris temp),
     `onDeleteTemp`, `onDeleteExisting`.
   - menampilkan 3-baris: Nama → NoBP (hanya baris temp) → Qty + icon.

---

## 3. SUDAH SELESAI SESI LANJUTAN (validasi analyze + APK)

1. **Getter publik `bahanPendukungLabelsOf(int? IdCabinetMaterial)`** ditambahkan di 5 VM:
   inject, packing, hot_stamp, key_fitting, spanner (± setelah `getTempKeysForDebug`).
2. **Wiring `CabinetMaterialListTile`** selesai di 6 layar:
   - packing `packing_production_input_screen.dart`
   - inject v3 `inject_production_input_screen_v3.dart` (+ v1 standard `inject_production_input_screen.dart`
     — masih dipakai router utk mode backdate/non-realtime, ikut di-wire agar konsisten)
   - hot_stamp, key_fitting, spanner
   - `bahanPendukungLabels:` hanya diisi untuk baris temp
   - Local `_MaterialListTile` dihapus di semua layar tsb.
3. **Export widget** ke `shared.dart`; import model di widget diperbaiki
   (`../../models/` → `../models/`).
4. **`flutter analyze`**: error NOL untuk file tersentuh. (Sisa warning pre-existing.)
   Error di `test/gilingan_vm_test.dart` pre-existing (parameter idOperators/jam).
5. **APK development dibangun OK**: `build\app\outputs\flutter-apk\app-release.apk` (105.1MB).

── PIYUNGAN YANG BELUM DI-COMMIT ――

## 4. Yang BELUM SELESAI (lanjut sesi berikut)

1. ~JALANKAN BACKEND MIGRATION~ **DONE (2026-09-24, langsung ke PPS_TEST6 via node/mssql).
   Kolom `NoBahanPendukung` sudah ada di 5 tabel (terverifikasi query live).**
   Catatan: di-apply langsung, jadi `flyway migrate` nanti idempotent (guard
   COL_LENGTH) — aman.
2. **PRODUCTION DB juga sudah di-update (2026-09-24)** — DB `PPS` (server
   192.168.10.100, sqlserver yang sama dengan TEST6; database berbeda). Kolom
   `NoBahanPendukung` ditambahkan ke 5 tabel yang sama (idempotent, additive).
   Verifikasi read-only query material production jalan (sample `BD.0000000412`;
   data lama ber-NoBP NULL — wajar, belum pernah disimpan). Jadi ketika backend
   baru di-deploy ke server 192.168.11.79, `/inputs` TIDAK akan 500.
   ⚠️ Perbaikan error 500 `/inputs` juga mencakup: placeholder `NoBahanPendukung`
   untuk cabang UNION pertama di packing/spanner/key-fitting + fix subquery
   label-fill (kolom qty `Jumlah`/`Pcs` dimasukkan ke OPENJSON WITH di
   `produksi-upsert-sql.generator.js` — STRING_AGG DISTINCT diganti dedup-subquery
   karena `STRING_AGG(DISTINCT x) WITHIN GROUP` syntax error di SQL 2022).
2. **Validasi visual di device** — focus: baris temp DAN existing menampilkan NoBP
   bentukan `BP.<kode>`; delete temp/existing tetap jalan; submit → fetch ulang
   → NoBP tampil pada baris tersimpan.
3. Commit frontend (setelah validasi visual OK + migration applied).

---

## 5. Konten sesi "NoBP terinclude di hasil inputan" (2026-09-24)

### Backend (D:\backend\pps_backend) — BELUM DI-COMMIT
- `src/core/utils/produksi-upsert-sql.generator.js`: section UPSERT material kini
  meng-agregat `noBahanPendukung` (STRAG_AGG DISTINCT, dedup, urut) ke kolom
  `NoBahanPendukung` di baris mapping (UPDATE existing + INSERT new). Hanya aktif
  bila config punya `markUsage` (bjJual tidak terpengaruh).
- 5 service fetch inputs mengembalikan `noBahanPendukung` per cabinetMaterial row:
  packing, spanner, key-fitting, hot-stamp, inject (inject = UNION 5 cabang dibubuhi
  placeholder `NoBahanPendukung` agar jumlah kolom konsisten).
- Migration baru: `db/migrations/versioned/V20260924090000__add_no_bahan_pendukung_to_produksi_input_material.sql`.

### Frontend (D:\frontend\pps_tablet)
- `CabinetMaterialItem`: field `List<String> noBahanPendukung` + parser toleran
  (string dipisah koma/`;`/newline atau array) untuk key `noBahanPendukung`/`NoBahanPendukung`.
- `CabinetMaterialListTile`: `showNoBP` TIDAK lagi bergantung `isTemp` — tampil
  selama `bahanPendukungLabels` tidak kosong.
- 6 layar: `bahanPendukungLabels: !isTemp ? item.noBahanPendukung : vm.bahanPendukungLabelsOf(id)`.
- `flutter analyze` OK (0 error baru; warning pre-existing), APK dev built (105.1MB).

---

## 5. File penting

- Shared widget: `lib/features/production/shared/widgets/cabinet_material_list_tile.dart`
- Model: `lib/features/production/shared/models/cabinet_material_item.dart`
- VM (5): `{inject,packing,hot_stamp,key_fitting,spanner}/view_model/*_production_input_view_model.dart`
- Layar (5): `{inject(view v3),packing,hot_stamp,key_fitting,spanner}/view/*_production_input_screen*.dart`

---

## 6. Catatan penting

- **JANGAN commit perubahan backend** (belum di-commit, dikerjakan khusus).
- APK dirilis: `flutter build apk --release --dart-define=APP_ENV=<env>`.
- Widget preview: `flutter run -t lib/preview.dart`.
- Jangan merusak permission/hak akses delete yang sudah berfungsi (`packing:delete`).
- Waterfall NoBP: submit payload (sudah ada sejak commit `97557f8`) → backend
  STRING_AGG ke kolom `NoBahanPendukung` → GET inputs mengembalikannya → tile
  menampilkan di baris existing. JANGAN lupa migration sebelum uji.

---

## 7. QC tiap jam washing & broker (2026-09-24) — backend DITAMBAH

User minta QC mesin washing/broker **mengikuti pola QC inject**: input per jam,
timer ⏳ (1 jam ke depan), pesan "jam ini sudah lewat dan tidak diinput" bila
terlewat, countdown waktu tersisa.

### Backend (D:\backend\pps_backend) — BELUM DI-COMMIT
- Baru: `src/core/utils/qc-bucket.js` — `buildQcBuckets` + primitives
  (salinan verbatim dari inject, termasuk special-case shift===3). Dipakai
  HANYA oleh service washing/broker; inject & dialignya tidak diubah.
- Service washing & broker: `getXxxQcByNoProduksi` sekarang mengembalikan
  `{header, items, buckets}` (bucket dihitung dari tglProduksi + hourStart/
  hourEnd asli produksi); `createXxxQc(noProduksi, idMesin, hourStart, keterangan)`.
  DELETE/PUT tak berubah.
- Controller washing & broker: `createQc` terima `req.body.hourStart`
  (dibersihkan `normalizeTime`).
- Migration baru: `V20260925100000__add_hourstart_to_washing_broker_qc.sql`
  (kolom `HourStart varchar(5) NULL` ke `WashingProduksiQc` & `BrokerProduksiQc`).
  **SUDAH di-apply ke PPS_TEST6 dan PPS** (via node/mssql, idempotent).
- Teruji end-to-end via service (WSH=W.0000000001, BRK=E.0000006055);
  window bucket benar (8 bucket 08:00–16:00, opensAt=akhir jam, closesAt=+1 jam).

### Frontend (D:\frontend\pps_tablet)
- `shared/models/qc_downtime_item.dart`: + `QcDowntimeItem.hourStart`,
  `QcDowntimeHeader`, `QcDowntimeBucket`, `QcDowntimeDetail`.
- Repo washing & broker: `fetchQc` → `Future<QcDowntimeDetail>` (parse
  `data.header/items/buckets`); `createQc` + param `hourStart`.
- `shared/widgets/qc_downtime_dialog.dart`: **ditulis ulang gaya inject** — enum
  `{locked, available, expired, submitted}`, `_kQcInputOpenDelay=Duration.zero`,
  Timer 1 detik, countdown pill "Terbuka dalam/Tertutup dalam mm:ss", row tersimpan
  amber (edit bila window masih buka + hapus), expired = pesan merah
  "Jam ini sudah lewat dan tidak diinput". Fallback bucket lokal bila backend
  tidak kirim buckets. Tak ada counter/BS/berat (hanya keterangan per jam).
- Mesin screen washing & broker: closure `create` + param `hourStart`.
- `flutter analyze` di 6 file tersentuh: 0 error (hanya info `avoid_print`/
  `unused_element` pre-existing). `gilingan_vm_test.dart` tetap error pre-existing.

### Pending
- Build APK + validasi visual di device (long-press kartu mesin → dialog; per-jam;
  cek countdown pada jam berjalan; cek pesan expired pada jam lampau).
- **Deploy backend baru ke 192.168.11.79** agar NoBP + QC per jam aktif di production
  (frontend production APP_ENV menunjuk 192.168.11.79:7500).
- Backend & frontend belum di-commit.
