/* =============================================================================
   Duplikasi mstFormulaProduksi :  pps  ->  pps_test6
   -----------------------------------------------------------------------------
   Struktur yang dipakai skrip ini (dikonfirmasi dari API):
     - header  : IdFormula (identity), MainOutputKategoriId, MainKategori, MainOutputId
     - anak    : IdFormula, InputKategoriId, InputId          (tabel mstFormulaProduksiInput)
     - anak 2  : IdFormula, SecondaryKategoriId, SecondaryId  (tabel mstFormulaProduksiSecondary)
   mstFormulaProduksi TIDAK menyimpan jumlah/pcs - isinya murni daftar
   "input mana yang boleh dipakai untuk output ini" (whitelist).

   >>> WAJIB: jalankan LANGKAH 0 dulu untuk memastikan nama tabel/kolom di DB
       Anda, lalu samakan dengan variabel di LANGKAH 1. Jangan loncat.
   ============================================================================= */

SET NOCOUNT ON;
GO

/* =============================================================================
   LANGKAH 0 — DISCOVERY (read-only, aman dijalankan)
   Jalankan di SQL Server yang memegang kedua database.
   ============================================================================= */
USE master;
GO

SELECT
    t.name                                        AS [table],
    c.name                                        AS [column],
    ty.name                                       AS [tipe],
    c.is_identity                                 AS [identity],
    c.max_length                                  AS [max_len],
    c.is_nullable                                 AS [nullable]
FROM sys.tables t
JOIN sys.columns c  ON c.object_id = t.object_id
JOIN sys.types ty   ON ty.user_type_id = c.user_type_id
WHERE t.name LIKE '%FormulaProduksi%'
ORDER BY t.name, c.column_id;
GO

-- FK antar tabel formula (untuk tahu urutan insert & nama constraint)
SELECT
    fk.name                    AS [fk],
    OBJECT_NAME(fk.parent_object_id)  AS [child],
    OBJECT_NAME(fk.referenced_object_id) AS [parent]
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.parent_object_id) LIKE '%FormulaProduksi%'
   OR OBJECT_NAME(fk.referenced_object_id) LIKE '%FormulaProduksi%';
GO

-- Ringkasan isi saat ini di kedua DB
SELECT 'pps'       AS db_name, COUNT(*) AS jml_formula FROM pps.dbo.mstFormulaProduksi
UNION ALL
SELECT 'pps_test6', COUNT(*) FROM pps_test6.dbo.mstFormulaProduksi;
GO


/* =============================================================================
   LANGKAH 1 — VARIABEL
   Sesuaikan bila nama tabel/kolom berbeda dengan hasil LANGKAH 0.
   ============================================================================= */
--USE pps_test6;      -- <<< database TUJUAN
--GO

SET NOCOUNT ON;

DECLARE @SrcDb      sysname = N'pps';        -- sumber
DECLARE @DstDb      sysname = N'pps_test6';  -- tujuan
DECLARE @SrcHeader   sysname = N'mstFormulaProduksi';
DECLARE @SrcInput    sysname = N'mstFormulaProduksiInput';
DECLARE @SrcSecond   sysname = N'mstFormulaProduksiSecondary';
DECLARE @DstHeader   sysname = N'mstFormulaProduksi';
DECLARE @DstInput    sysname = N'mstFormulaProduksiInput';
DECLARE @DstSecond   sysname = N'mstFormulaProduksiSecondary';

-- Batasi hanya 1 kategori output tertentu? NULL = semua kategori.
-- Contoh: 9 = 'Barang Jadi', 8 = 'Furniture WIP'
DECLARE @OnlyKategoriId int = NULL;

-- Hanya formula untuk output tertentu? NULL = semua.
DECLARE @OnlyMainOutputId int = NULL;


/* =============================================================================
   LANGKAH 2 — PREVIEW (read-only)
   Lihat dulu apa yang akan tersalin. TIDAK ada yang berubah di sini.
   ============================================================================= */
DECLARE @sql nvarchar(max) = N'
SELECT h.IdFormula, h.MainOutputKategoriId, h.MainKategori, h.MainOutputId,
       (SELECT COUNT(*) FROM ' + QUOTENAME(@SrcDb) + N'.dbo.' + QUOTENAME(@SrcInput)  + N' i WHERE i.IdFormula = h.IdFormula) AS jml_input,
       (SELECT COUNT(*) FROM ' + QUOTENAME(@SrcDb) + N'.dbo.' + QUOTENAME(@SrcSecond) + N' s WHERE s.IdFormula = h.IdFormula) AS jml_secondary
FROM ' + QUOTENAME(@SrcDb) + N'.dbo.' + QUOTENAME(@SrcHeader) + N' h
WHERE (h.MainOutputKategoriId = @k OR @k IS NULL)
  AND (h.MainOutputId         = @m OR @m IS NULL)
  AND NOT EXISTS (
        SELECT 1 FROM ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstHeader) + N' d
        WHERE d.MainOutputKategoriId = h.MainOutputKategoriId
          AND d.MainOutputId         = h.MainOutputId
  )
ORDER BY h.IdFormula;';

EXEC sp_executesql @sql, N'@k int, @m int', @OnlyKategoriId, @OnlyMainOutputId;
GO

/* =============================================================================
   LANGKAH 3 — COPY
   ---------------------------------------------------------------------------
   Strategi: TIDAK menyalin IdFormula. IdFormula di tujuan dibiarkan identity
   yang membuat nomor sendiri, karena menyalin nomor bisa bentrok dengan data
   yang sudah ada. Baris anak dipetakan lewat business key
   (MainOutputKategoriId, MainOutputId).

   SKRIP INI dibungkus transaksi dan di-ROLLBACK di akhir supaya jadi DRY-RUN.
   Hapus baris ROLLBACK hanya setelah Anda yakin.
   ============================================================================= */
BEGIN TRANSACTION;

DECLARE @sql nvarchar(max) = N'
SET NOCOUNT ON;

/* ---------- 3a. header ---------- */
INSERT INTO ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstHeader) + N'
       (MainOutputKategoriId, MainKategori, MainOutputId)
SELECT h.MainOutputKategoriId, h.MainKategori, h.MainOutputId
FROM ' + QUOTENAME(@SrcDb) + N'.dbo.' + QUOTENAME(@SrcHeader) + N' h
WHERE (h.MainOutputKategoriId = @k OR @k IS NULL)
  AND (h.MainOutputId         = @m OR @m IS NULL)
  AND NOT EXISTS (
        SELECT 1 FROM ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstHeader) + N' d
        WHERE d.MainOutputKategoriId = h.MainOutputKategoriId
          AND d.MainOutputId         = h.MainOutputId
  );

/* ---------- 3b. anak: input ---------- */
INSERT INTO ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstInput) + N'
       (IdFormula, InputKategoriId, InputId)
SELECT dn.IdFormula, si.InputKategoriId, si.InputId
FROM ' + QUOTENAME(@SrcDb) + N'.dbo.' + QUOTENAME(@SrcInput) + N' si
JOIN ' + QUOTENAME(@SrcDb) + N'.dbo.' + QUOTENAME(@SrcHeader) + N' sh
     ON sh.IdFormula = si.IdFormula
JOIN ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstHeader) + N' dn
     ON dn.MainOutputKategoriId = sh.MainOutputKategoriId
    AND dn.MainOutputId         = sh.MainOutputId
WHERE (sh.MainOutputKategoriId = @k OR @k IS NULL)
  AND (sh.MainOutputId         = @m OR @m IS NULL)
  AND NOT EXISTS (
        SELECT 1
        FROM ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstInput) + N' di
        WHERE di.IdFormula      = dn.IdFormula
          AND di.InputKategoriId = si.InputKategoriId
          AND di.InputId         = si.InputId
  );

/* ---------- 3c. anak: secondary ---------- */
INSERT INTO ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstSecond) + N'
       (IdFormula, SecondaryKategoriId, SecondaryId)
SELECT dn.IdFormula, ss.SecondaryKategoriId, ss.SecondaryId
FROM ' + QUOTENAME(@SrcDb) + N'.dbo.' + QUOTENAME(@SrcSecond) + N' ss
JOIN ' + QUOTENAME(@SrcDb) + N'.dbo.' + QUOTENAME(@SrcHeader) + N' sh
     ON sh.IdFormula = ss.IdFormula
JOIN ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstHeader) + N' dn
     ON dn.MainOutputKategoriId = sh.MainOutputKategoriId
    AND dn.MainOutputId         = sh.MainOutputId
WHERE (sh.MainOutputKategoriId = @k OR @k IS NULL)
  AND (sh.MainOutputId         = @m OR @m IS NULL)
  AND NOT EXISTS (
        SELECT 1
        FROM ' + QUOTENAME(@DstDb) + N'.dbo.' + QUOTENAME(@DstSecond) + N' ds
        WHERE ds.IdFormula         = dn.IdFormula
          AND ds.SecondaryKategoriId = ss.SecondaryKategoriId
          AND ds.SecondaryId         = ss.SecondaryId
  );
';

EXEC sp_executesql @sql, N'@k int, @m int', @OnlyKategoriId, @OnlyMainOutputId;


/* =============================================================================
   LANGKAH 4 — VERIFIKASI (masih di dalam transaksi)
   ============================================================================= */
SELECT 'SETELAH COPY (belum di-commit)' AS tahap,
       (SELECT COUNT(*) FROM pps.dbo.mstFormulaProduksi)        AS pps_header,
       (SELECT COUNT(*) FROM pps_test6.dbo.mstFormulaProduksi)  AS test_header,
       (SELECT COUNT(*) FROM pps.dbo.mstFormulaProduksiInput)   AS pps_input,
       (SELECT COUNT(*) FROM pps_test6.dbo.mstFormulaProduksiInput) AS test_input,
       (SELECT COUNT(*) FROM pps.dbo.mstFormulaProduksiSecondary) AS pps_secondary,
       (SELECT COUNT(*) FROM pps_test6.dbo.mstFormulaProduksiSecondary) AS test_secondary;

-- formula yang masih ada di pps tapi belum ada di pps_test6 (harus kosong)
SELECT h.IdFormula, h.MainOutputKategoriId, h.MainOutputId, h.MainKategori
FROM pps.dbo.mstFormulaProduksi h
WHERE NOT EXISTS (
    SELECT 1 FROM pps_test6.dbo.mstFormulaProduksi d
    WHERE d.MainOutputKategoriId = h.MainOutputKategoriId
      AND d.MainOutputId         = h.MainOutputId
)
ORDER BY h.IdFormula;
GO

/* =============================================================================
   LANGKAH 5 — COMMIT / ROLLBACK
   ------------------------------------------------------------------
   Default: ROLLBACK (dry-run, tidak mengubah apa pun).
   Kalau hasil LANGKAH 4 sudah benar, ganti ROLLBACK menjadi COMMIT.
   ============================================================================= */
ROLLBACK;   -- <<< ubah jadi:  COMMIT;
GO


/* =============================================================================
   VARIAN: dua database di SQL Server BERBEDA (butuh linked server)
   Buat linked server lebih dulu di server tujuan:
       EXEC sp_addlinkedserver @server='PPS_SRC', @srvproduct='',
            @provider='SQLNCLI', @datasrc='<host pps>';
   Lalu ubah QUOTENAME(@SrcDb) + N'.dbo.' -> N'[PPS_SRC].' + QUOTENAME(@SrcDb) + N'.dbo.'
   di seluruh blok di atas.
   ============================================================================= */


/* =============================================================================
   VARIAN: kalau di server saya ada database pps_test6 tapi nama fisiknya lain
   (mis. pps_test6_dev), cukup ganti @DstDb.
   ============================================================================= */