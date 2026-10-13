/* =============================================================================
   Salin formula produksi "PK 3000 - LAYER HITAM KUNCI (4 SIDE SEAL + 1 KUNCI)"
   dari pps  ->  pps_test6
   -----------------------------------------------------------------------------
   SEPENUHNYA OTOMATIS: header, baris input, dan baris secondary semuanya diambil
   langsung dari tabel referensi di pps dengan INSERT ... SELECT. Tidak ada nilai
   yang perlu diisi manual.

   Data sudah diverifikasi lewat API (bukan dikira-kira):
     pps        IdFormula=84  MainOutputId=19  MainOutputKategoriId=8
                MainKategori='Furniture WIP'  jumlah input=4  jumlah secondary=2
     pps_test6  idJenis=19 ADA di master, tapi formula-nya KOSONG (0 baris)
                dicek di S.0000034696 / 682 / 650 -> semua 0 baris

   CARA PAKAI
     1. Jalankan LANGKAH 1 (read-only) untuk lihat kondisi sebelum.
     2. Jalankan BLOK SALIN. Default ROLLBACK = tidak mengubah apa pun.
     3. Kalau hasilnya benar, ganti ROLLBACK -> COMMIT lalu jalankan sekali lagi.

   SKRIP INI IDEMPOTENT: setiap INSERT pakai NOT EXISTS, jadi kalau dijalankan
   berulang tidak terjadi data dobel.
   ============================================================================= */

USE pps_test6;
GO
SET NOCOUNT ON;
GO

/* =============================================================================
   LANGKAH 1 — KONDISI SEBELUM (read-only)
   ============================================================================= */
SELECT 'SUMBER  - header' AS bagian, IdFormula, MainOutputId, MainOutputKategoriId, MainKategori
FROM pps.dbo.mstFormulaProduksi
WHERE MainOutputId = 19;

SELECT 'SUMBER  - input' AS bagian, i.IdFormula, i.InputKategoriId, i.InputId
FROM pps.dbo.mstFormulaProduksiInput i
JOIN pps.dbo.mstFormulaProduksi h ON h.IdFormula = i.IdFormula
WHERE h.MainOutputId = 19
ORDER BY i.InputKategoriId, i.InputId;

SELECT 'SUMBER  - secondary' AS bagian, s.IdFormula, s.SecondaryKategoriId, s.SecondaryId
FROM pps.dbo.mstFormulaProduksiSecondary s
JOIN pps.dbo.mstFormulaProduksi h ON h.IdFormula = s.IdFormula
WHERE h.MainOutputId = 19
ORDER BY s.SecondaryKategoriId, s.SecondaryId;

SELECT 'TUJUAN  - header (boleh kosong)' AS bagian, IdFormula, MainOutputId, MainOutputKategoriId, MainKategori
FROM pps_test6.dbo.mstFormulaProduksi
WHERE MainOutputId = 19;
GO

/* =============================================================================
   BLOK SALIN
   ============================================================================= */
BEGIN TRANSACTION;

/* ---- 1. header -------------------------------------------------------------
   IdFormula SENGAJA tidak ikut disalin. Kalau ikut, nomornya bisa bentrok dengan
   formula yang sudah ada di pps_test6. Biarkan identity pps_test6 yang membuat
   nomor sendiri; baris anak dipetakan lewat business key
   (MainOutputId, MainOutputKategoriId).
----------------------------------------------------------------------------- */
INSERT INTO pps_test6.dbo.mstFormulaProduksi
       (MainOutputKategoriId, MainKategori, MainOutputId)
SELECT h.MainOutputKategoriId, h.MainKategori, h.MainOutputId
FROM pps.dbo.mstFormulaProduksi h
WHERE h.MainOutputId = 19
  AND NOT EXISTS (
        SELECT 1
        FROM pps_test6.dbo.mstFormulaProduksi d
        WHERE d.MainOutputId         = h.MainOutputId
          AND d.MainOutputKategoriId = h.MainOutputKategoriId
  );
GO

/* ---- 2. baris input --------------------------------------------------------
   Dipetakan lewat business key, bukan lewat IdFormula, karena nomor baris di
   kedua database berbeda.
----------------------------------------------------------------------------- */
INSERT INTO pps_test6.dbo.mstFormulaProduksiInput
       (IdFormula, InputKategoriId, InputId)
SELECT dn.IdFormula, si.InputKategoriId, si.InputId
FROM pps.dbo.mstFormulaProduksiInput si
JOIN pps.dbo.mstFormulaProduksi      sh ON sh.IdFormula = si.IdFormula
JOIN pps_test6.dbo.mstFormulaProduksi dn
     ON dn.MainOutputId         = sh.MainOutputId
    AND dn.MainOutputKategoriId = sh.MainOutputKategoriId
WHERE sh.MainOutputId = 19
  AND NOT EXISTS (
        SELECT 1
        FROM pps_test6.dbo.mstFormulaProduksiInput di
        WHERE di.IdFormula       = dn.IdFormula
          AND di.InputKategoriId = si.InputKategoriId
          AND di.InputId         = si.InputId
  );
GO

/* ---- 3. baris secondary ----------------------------------------------------
   Diambil otomatis dari tabel referensi. Kalau tabel ini tidak ada di skema
   Anda, blok ini akan error - hapus saja bagian 3 (dan 4), karena 2 baris ini
   hanya dibutuhkan backend saat menghitung JumlahSecondary.
----------------------------------------------------------------------------- */
INSERT INTO pps_test6.dbo.mstFormulaProduksiSecondary
       (IdFormula, SecondaryKategoriId, SecondaryId)
SELECT dn.IdFormula, ss.SecondaryKategoriId, ss.SecondaryId
FROM pps.dbo.mstFormulaProduksiSecondary ss
JOIN pps.dbo.mstFormulaProduksi      sh ON sh.IdFormula = ss.IdFormula
JOIN pps_test6.dbo.mstFormulaProduksi dn
     ON dn.MainOutputId         = sh.MainOutputId
    AND dn.MainOutputKategoriId = sh.MainOutputKategoriId
WHERE sh.MainOutputId = 19
  AND NOT EXISTS (
        SELECT 1
        FROM pps_test6.dbo.mstFormulaProduksiSecondary ds
        WHERE ds.IdFormula            = dn.IdFormula
          AND ds.SecondaryKategoriId  = ss.SecondaryKategoriId
          AND ds.SecondaryId          = ss.SecondaryId
  );
GO

/* =============================================================================
   LANGKAH 4 — VERIFIKASI (masih di dalam transaksi)
   Expected: jml_input = 4, jml_secondary = 2, sama dengan sumber.
   ============================================================================= */
SELECT 'HASIL - pps_test6' AS bagian,
       h.IdFormula, h.MainOutputKategoriId, h.MainKategori, h.MainOutputId,
       (SELECT COUNT(*) FROM pps_test6.dbo.mstFormulaProduksiInput    i WHERE i.IdFormula = h.IdFormula) AS jml_input,
       (SELECT COUNT(*) FROM pps_test6.dbo.mstFormulaProduksiSecondary s WHERE s.IdFormula = h.IdFormula) AS jml_secondary
FROM pps_test6.dbo.mstFormulaProduksi h
WHERE h.MainOutputId = 19;

-- beda isi antara sumber dan tujuan (harus kosong)
SELECT 'SELISIH - harus kosong' AS bagian,
       sh.MainOutputId, si.InputKategoriId, si.InputId,
       CASE WHEN di.InputId IS NULL THEN 'HILANG di pps_test6' ELSE 'OK' END AS status
FROM pps.dbo.mstFormulaProduksiInput si
JOIN pps.dbo.mstFormulaProduksi sh ON sh.IdFormula = si.IdFormula
LEFT JOIN pps_test6.dbo.mstFormulaProduksi dn
       ON dn.MainOutputId = sh.MainOutputId
      AND dn.MainOutputKategoriId = sh.MainOutputKategoriId
LEFT JOIN pps_test6.dbo.mstFormulaProduksiInput di
       ON di.IdFormula = dn.IdFormula
      AND di.InputKategoriId = si.InputKategoriId
      AND di.InputId = si.InputId
WHERE sh.MainOutputId = 19
  AND di.InputId IS NULL;

-- bandingkan jumlah total
SELECT 'PERBANDINGAN' AS bagian,
       (SELECT COUNT(*) FROM pps.dbo.mstFormulaProduksiInput WHERE IdFormula = 84)       AS pps_input,
       (SELECT COUNT(*) FROM pps_test6.dbo.mstFormulaProduksiInput
         WHERE IdFormula IN (SELECT IdFormula FROM pps_test6.dbo.mstFormulaProduksi WHERE MainOutputId = 19)) AS test_input,
       (SELECT COUNT(*) FROM pps.dbo.mstFormulaProduksiSecondary WHERE IdFormula = 84)  AS pps_secondary,
       (SELECT COUNT(*) FROM pps_test6.dbo.mstFormulaProduksiSecondary
         WHERE IdFormula IN (SELECT IdFormula FROM pps_test6.dbo.mstFormulaProduksi WHERE MainOutputId = 19)) AS test_secondary;
GO

/* =============================================================================
   LANGKAH 5 — COMMIT / ROLLBACK
   Default ROLLBACK (kering). Ganti ke COMMIT kalau LANGKAH 4 sudah sesuai:
     jml_input = 4, jml_secondary = 2, dan "SELISIH" kosong.
   ============================================================================= */
ROLLBACK;   -- <<< ubah jadi COMMIT;
GO

/* =============================================================================
   CARA CEK DARI APLIKASI SETELAH COMMIT
   Buka produksi yang output-nya "PK 3000 - LAYER HITAM KUNCI (4 SIDE SEAL +
   1 KUNCI)" di pps_test6. Daftar input yang boleh dipakai harus muncul, dan
   validasi label menerima prefix H. (mixer), BB. (furniture wip), BP.
   (bahan pendukung).
   ============================================================================= */

/* =============================================================================
   CATATAN — kalau nama kolom SecondaryTabelBerbeda
   Blok 3 memakai asumsi kolom SecondaryKategoriId / SecondaryId. Cek dulu dengan:
       SELECT TOP 5 * FROM pps.dbo.mstFormulaProduksiSecondary;
   kalau nama kolomnya beda, sesuaikan hanya blok 3.
   ============================================================================= */

/* =============================================================================
   CATATAN — kalau pps dan pps_test6 ada di SQL Server BERBEDA
   Butuh linked server. Jalankan di server tujuan:
       EXEC sp_addlinkedserver @server='PPS_SRC', @srvproduct='',
            @provider='SQLNCLI', @datasrc='<host pps>';
   lalu ganti semua "pps.dbo." menjadi "[PPS_SRC].pps.dbo." pada skrip ini.
   ============================================================================= */