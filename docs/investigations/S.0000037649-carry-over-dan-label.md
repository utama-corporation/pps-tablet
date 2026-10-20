# Investigasi S.0000037649 — Carry Over, Jenis 93, dan 8 vs 7 Label

Tanggal investigasi: 2026-10-20
Sumber data: server live produksi `http://192.168.11.79:7500` (via REST API + Bearer token)
Catatan: token yang dipakai sudah kedaluwarsa/rahasia — jangan simpan token di file ini.

---

## Ringkasan Pertanyaan

1. Apakah ada carry over sesudah error pada no transaksi **S.0000037649** bucket **11:00–12:00**?
2. Kenapa label yang dihasilkan total **8** di database, padahal kalau dibagi seharusnya cuma **7**?
3. Apa maksud item batch jenis **93 (furnitureWip)**?
4. Kalau cetakan diganti, bukannya seharusnya membuat `InjectProduksi_h` baru?
5. Dari tabel mana data jenis 93 didapat?

---

## 1. Carry Over Bucket 11:00–12:00 — YA, ada

Dari `GET /api/production/inject/batch/S.0000037649`, batch id **588** bucket `11:00`:

| Field | Nilai |
|---|---|
| isDowntime | false (batch normal, bukan downtime) |
| items | idJenis **93** (outputCategory `furnitureWip`) |
| pcsInput | 30 |
| carryOverIn | 0 |
| **carryOverOut** | **30** |
| labels | **0 label** — semua pcs di-carry out |
| dateTimeCreate | 2026-10-18T05:24:41.263Z (12:24 WIB) |

Server meng-commit batch ini dengan carry over keluar 30 pcs — pola klasik **server commit tapi response gagal di tablet** (timeout 25s), sehingga operator mengira error. Carry over 30 pcs jenis 93 ini **tidak pernah dikonsumsi**: bucket 12:00 & 13:00 downtime, dan bucket 14:00 input jenis 255 dengan `carryOverIn: 0`. Jadi ini data orphan.

Mismatch tambahan: QC punya input jam 10:00 (jumlahBS 15) tapi tidak ada batch 10:00; QC bilang 11:00 downtime, tapi batch 11:00 justru bukan downtime.

## 2. Kenapa 8 Label, Seharusnya 7

Label packing (barang jadi) untuk S.0000037649 di DB — **total 8 label, 35 pcs**:

| NoBJ | Pcs | Printed | Keterangan |
|---|---|---|---|
| BA.0000117190–195 | 5×6 = 30 pcs | ✅ semua | dibuat 13:41–13:42 WIB |
| BA.0000117196 | 4 | ✅ | dari batch 14:00 (`carryOverOut: 0`) |
| **BA.0000117279** | **1** | **❌ belum** | nomor jauh lebih baru, dibuat 19 Okt 11:07 WIB |

`pcsPerLabel` jenis 255 = **5** → 35 pcs ÷ 5 = **7 label**. Yang membuat jadi 8: 5 pcs terakhir terpecah menjadi **4** (BA.0000117196) **+ 1** (BA.0000117279, label terpisah belum dicetak).

Kesimpulan: **bukan pembagian yang salah** — 6 label pertama benar (5 pcs × 6). Batch 14:00 hanya mencatat 4 pcs, lalu 1 pcs sisanya ditambahkan manual sebagai label baru → 8 label.

Tindakan pembersihan opsional: hapus/cancel **BA.0000117279** (1 pcs, belum tercetak) jika itu duplikat koreksi, atau pastikan pcs asli memang 35 dan label ke-7 seharusnya berisi 5 pcs.

## 3. Maksud Item Jenis 93 (furnitureWip)

Dari `GET /api/production/inject/S.0000037649/formula-inputs`:

```
InputKategoriKode: "furniturewip", InputPrefixLabel: "BB."
InputId: 93 → "OUTER FOOT PAD KC HIJAU APEL"
```

Jenis 93 = **OUTER FOOT PAD KC HIJAU APEL** — komponen **Furniture WIP (prefix BB.)** yang berperan sebagai **INPUT/bahan** dalam formula produksi ini, **bukan output jadi**. Output produksi ini cuma satu: jenis **255** (MODELUX KURSI CAFE KC 2601, prefix BA.).

Tablet **tidak pernah mengirim `outputCategory`** — payload submit cuma `{idJenis, pcsInput, carryOverIn, carryOverOut}` (`inject_production_input_screen_v3.dart:939-944`). Yang dikirim tablet adalah `idJenis: 93`, dan **server** menstempel `outputCategory: "furnitureWip"` dari master jenis.

**Timeline audit** (`GET /api/audit/S.0000037649/history`, WIB):

| Waktu (18 Okt) | Kejadian |
|---|---|
| 08:27 | Produksi **dibuat therty** dengan **IdCetakan 29**, IdWarna 9 |
| 12:24 | Batch 11:00 disubmit: 30 pcs **jenis 93** (masih cetakan 29) |
| **12:41** | **IdCetakan diganti 29 → 4** (KC 2601) + JmlhAnggota 2→1 |
| 13:41–13:42 | 6 label barang jadi (jenis 255) dibuat, 5 pcs × 6 = **30 pcs** |
| 15:06 | Batch 14:00: 4 pcs jenis 255 → 1 label BA.0000117196 |

Konsekuensi:
1. **0 label dari bucket 11:00** — `pcsPerLabel` API hanya berisi jenis 255 (ppl 5); untuk jenis 93 app fallback ke **ppl = 100** (`inject_production_input_screen_v3.dart:911`) → `floor(30/100) = 0` label → seluruh 30 pcs carry out.
2. **Carry over 30 pcs orphan** — tidak pernah dikonsumsi; `GET .../outputs/furniture-wip` = `[]`.
3. **Ketidakkonsistenan**: QC 11:00 ditandai downtime ("hasil produksi belang2 dan gosong"), tapi batch 11:00 mencatat 30 pcs non-downtime.

Kaitan dengan 8 vs 7: 6 label × 5 pcs dibuat 13:41 (tepat setelah ganti cetakan) = 30 pcs, persis jumlah pcs batch 11:00. Total akhir 30 + 4 + 1 = **35 pcs = 7 label penuh**, tapi terpecah jadi 8 karena 5 terakhir jadi 4 + 1.

## 4. Kalau Cetakan Diganti, Harusnya Buat InjectProduksi_h Baru — YA

Data live mesin 53 tanggal 18 Okt (`GET /api/production/inject?idMesin=53&tanggal=2026-10-18`), 4 header:

| NoProduksi | Jam | IdCetakan | Warna | CreatedAt (WIB) |
|---|---|---|---|---|
| S.0000037649 | 07:00–15:00 | **4** (KC 2601) | HIJAU APEL | 15:27 |
| S.0000037650 | 15:00–19:15 | 4 | HIJAU APEL | 23:39 |
| S.0000037651 | 19:15–23:00 | 4 | HITAM | 19 Okt 02:15 |
| S.0000037652 | 23:00–07:00 | 4 | HITAM | 19 Okt 07:19 |

Alur "ganti" resmi di tablet = **split-time** (`inject_production_input_screen_v3.dart:1311` → `POST /api/production/inject/split-time/:idMesin/:tgl`, `inject_production_repository.dart:415`). Dialog V3 menerima `lockedIdCetakan` dan mengirim `idCetakan` **baru**; server memutus header pada `hourStart` baru dan membuat `InjectProduksi_h` berikutnya (contoh: S.0000037650 mulai 15:00).

**Tapi di kasus S.0000037649 tidak begitu.** Header dibuat therty jam 15:27 dengan IdCetakan 4, lalu diubah manual jadi 29 dan dikembalikan ke 4 — semuanya lewat `SessionAction: UPDATE`, bukan split-time:
- 12:41 UTC (19:41 WIB) audit: `OldIdCetakan 29 → NewIdCetakan 4` — koreksi **belakangan**, bukan ganti cetakan saat produksi.
- Tidak ada header kedua untuk 07:00–12:00, dan tidak ada catatan `SessionAction: SPLIT` di audit.

Kesimpulan: header S.0000037649 dan batch 11:00-nya (jenis 93 / foot pad) adalah **data basi** dari sebelum sistem cetakan/CreatedAt header ini di-set. Seharusnya ganti cetakan membuat header baru; fakta bahwa itu tidak terjadi (batch 11:00 nyangkut di header 7649 yang sudah dikoreksi ke cetakan 4) itulah sumber kekacauannya. Batch 11:00 jenis 93 perlu dihapus/dikoreksi.

## 5. Dari Tabel Mana Data Jenis 93 Didapat

Data **bukan** dari query tabel DB langsung, melainkan dari **endpoint REST**:

| Endpoint | Field yang dipakai |
|---|---|
| `GET /api/production/inject/batch/S.0000037649` | `idJenis: 93`, `outputCategory: "furnitureWip"`, `pcsInput: 30`, `carryOverOut: 30` |
| `GET /api/production/inject/S.0000037649/formula-inputs` | memetakan `InputId: 93` → `"OUTER FOOT PAD KC HIJAU APEL"`, `InputKategoriKode: "furniturewip"` |
| `GET /api/audit/S.0000037649/history` | `SessionAction`, dan bocoran `TableName` (mis. `InjectProduksiInputFurnitureWIPPartial`) |

Endpoint batch tidak menyertakan nama tabel DB fisik. Nama tabel seperti `InjectProduksiOutput...` / `InjectProduksiInputFurnitureWIPPartial` hanya bocoran dari audit log dan **belum diverifikasi** terhadap skema fisik. Sumber definitif jenis 93 adalah **master jenis barang** (tabel master `idJenis`), tanpa akses skema DB nama tabel persisnya tidak diketahui.

---

## Rekomendasi Tindakan

1. Hapus/koreksi batch 11:00 (id 588) jenis 93 dengan carry over 30 pcs orphan pada S.0000037649.
2. Tinjau label packing BA.0000117279 (1 pcs, belum dicetak) — kemungkinan duplikat koreksi.
3. Selidiki celah: submit batch yang sukses di server tapi gagal di tablet (tanpa idempotency key) → bisa membuat batch ganda + carry over menggantung.
4. Cek header/cetakan mana yang seharusnya valid untuk periode 07:00–12:00 pada mesin 53 tanggal 18 Okt.
