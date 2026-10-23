/* =============================================================================
   Tabel Input MIXER untuk Proses CRUSHER
   -----------------------------------------------------------------------------
  TUJUAN : proses crusher (sama seperti proses broker) harus bisa menerima input
          berlabel Mixer (prefix "H."). Setiap label Mixer punya beberapa SAK;
          proses crusher memakai label mixer utuh (sak-based, boleh partial).

   Tabel yang dibuat:
     1. CrusherProduksiInputMixer         -> input mixer FULL  (sak utuh)
     2. CrusherProduksiInputMixerPartial  -> input mixer PARTIAL (sak sebagian)

   Kontrak API (wajib didukung backend crusher):
     GET    /api/production/crusher/{noCrusherProduksi}/inputs
            -> wajib mengembalikan array "mixer" (object per SAK) dan menambah
               key "mixer" pada object "summary".
            -> tiap element mixer:
               { noMixer, noSak, noMixerPartial?, berat, idJenis?, namaJenis? }
               (partial ditandai oleh noMixerPartial != "")

     POST   /api/production/crusher/{noCrusherProduksi}/inputs
            -> body boleh berisi:
               "mixer"        : [{ noMixer, noSak }]
               "mixerPartial" : [{ noMixer, noSak, berat }]
               (nama key mengikuti(process broker — lihat catatan di bawah)

     DELETE /api/production/crusher/{noCrusherProduksi}/inputs
            -> body boleh berisi:
               "mixer"        : [{ noMixer, noSak }]
               "mixerPartial" : [{ noMixerPartial }]

   CATATAN PENTING:
     - Nama kolom "NoCrusherProduksi" / "NoMixer" / "NoSak" mengikuti gaya tabel
       input crusher yang sudah ada. Bila nama tabel/kolom di DB Anda berbeda,
       jalankan LANGKAH 0 dulu dan sesuaikan kolom di LANGKAH 1.
     - Sumber label mixer adalah tabel label mixer (Mixer_d). Tabel ini hanya
       menyimpan referensi (NoMixer + NoSak) + berat yang dipakai.
     - Kolom "NoMixerPartial" pada tabel partial = kode partial yang dipakai
       backend saat membuat label partial baru (prefix "T." untuk mixer).
   ============================================================================= */

SET NOCOUNT ON;
GO

/* =============================================================================
   LANGKAH 0 — DISCOVERY (read-only, aman dijalankan)
   Untuk melihat tabel input crusher yang sudah ada beserta kolomnya, supaya
   LANGKAH 1 bisa disesuaikan dengan struktur asli DB Anda.
   ============================================================================= */
USE master;
GO

SELECT
    s.name                                        AS [schema],
    t.name                                        AS [table],
    c.name                                        AS [column],
    ty.name                                       AS [tipe],
    c.max_length                                  AS [max_len],
    c.is_identity                                 AS [identity],
    c.is_nullable                                 AS [nullable]
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty  ON ty.user_type_id = c.user_type_id
WHERE t.name LIKE '%Crusher%Produksi%Input%'
   OR t.name LIKE '%Broker%Produksi%Input%'
ORDER BY t.name, c.column_id;
GO

-- FK antar tabel input produksi (untuk melihat pola header -> input)
SELECT
    fk.name                                 AS [fk],
    OBJECT_SCHEMA_NAME(fk.parent_object_id)     AS [child_schema],
    OBJECT_NAME(fk.parent_object_id)       AS [child],
    OBJECT_NAME(fk.referenced_object_id)    AS [parent]
FROM sys.foreign_keys fk
WHERE OBJECT_NAME(fk.parent_object_id) LIKE '%Produksi%Input%'
   OR OBJECT_NAME(fk.referenced_object_id) LIKE '%Produksi%Input%';
GO

-- Ringkasan isi tabel crusher input yang sudah ada
IF OBJECT_ID('pps.dbo.CrusherProduksiInputBahanBaku', 'U') IS NOT NULL
    SELECT 'CrusherProduksiInputBahanBaku' AS [tabel], COUNT(*) AS [jml]
    FROM pps.dbo.CrusherProduksiInputBahanBaku
ELSE
    SELECT 'CrusherProduksiInputBahanBaku' AS [tabel], NULL AS [jml];
GO


/* =============================================================================
   LANGKAH 1 — CREATE TABLE
   Jalankan di database tujuan (mis. pps atau pps_test6).
   Skrip aman dijalankan ulang: tabel yang sudah ada tidak akan di-drop.
   ============================================================================= */
--USE pps;        -- <<< database TUJUAN
--GO

SET NOCOUNT ON;

IF OBJECT_ID('dbo.CrusherProduksiInputMixer', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CrusherProduksiInputMixer
    (
        Id                  INT IDENTITY(1,1) NOT NULL,
        NoCrusherProduksi   VARCHAR(13)    NOT NULL,
        NoMixer             VARCHAR(13)    NOT NULL,
        NoSak               INT            NOT NULL,
        Berat               DECIMAL(18,4)  NULL,
        IdJenis             INT            NULL,
        NamaJenis           NVARCHAR(150)  NULL,
        CreatedAt           DATETIME2(0)   NOT NULL
            CONSTRAINT DF_CrusherProduksiInputMixer_CreatedAt DEFAULT SYSDATETIME(),
        CreatedBy           NVARCHAR(100)  NULL,

        CONSTRAINT PK_CrusherProduksiInputMixer PRIMARY KEY CLUSTERED (Id)
    );

    PRINT '>> Created dbo.CrusherProduksiInputMixer';
END
ELSE
    PRINT '>> dbo.CrusherProduksiInputMixer sudah ada (skip)';
GO

IF OBJECT_ID('dbo.CrusherProduksiInputMixerPartial', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CrusherProduksiInputMixerPartial
    (
        Id                  INT IDENTITY(1,1) NOT NULL,
        NoCrusherProduksi   VARCHAR(13)    NOT NULL,
        NoMixer             VARCHAR(13)    NOT NULL,   -- label mixer asal
        NoSak               INT            NOT NULL,    -- sak asal (label yang dipotong)
        NoMixerPartial      VARCHAR(13)    NOT NULL,   -- kode partial hasil ("T.xxxx")
        Berat               DECIMAL(18,4)  NOT NULL,    -- berat yang dipakai (kg)
        IdJenis             INT            NULL,
        NamaJenis           NVARCHAR(150)  NULL,
        CreatedAt           DATETIME2(0)   NOT NULL
            CONSTRAINT DF_CrusherProduksiInputMixerPartial_CreatedAt DEFAULT SYSDATETIME(),
        CreatedBy           NVARCHAR(100)  NULL,

        CONSTRAINT PK_CrusherProduksiInputMixerPartial PRIMARY KEY CLUSTERED (Id)
    );

    PRINT '>> Created dbo.CrusherProduksiInputMixerPartial';
END
ELSE
    PRINT '>> dbo.CrusherProduksiInputMixerPartial sudah ada (skip)';
GO


/* =============================================================================
   LANGKAH 2 — INDEX
   ============================================================================= */
IF OBJECT_ID('dbo.CrusherProduksiInputMixer', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = 'IX_CrusherProduksiInputMixer_Produksi'
                     AND object_id = OBJECT_ID('dbo.CrusherProduksiInputMixer'))
BEGIN
    CREATE INDEX IX_CrusherProduksiInputMixer_Produksi
        ON dbo.CrusherProduksiInputMixer (NoCrusherProduksi);
    PRINT '>> Created IX_CrusherProduksiInputMixer_Produksi';
END
GO

IF OBJECT_ID('dbo.CrusherProduksiInputMixer', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = 'IX_CrusherProduksiInputMixer_Label'
                     AND object_id = OBJECT_ID('dbo.CrusherProduksiInputMixer'))
BEGIN
    CREATE INDEX IX_CrusherProduksiInputMixer_Label
        ON dbo.CrusherProduksiInputMixer (NoCrusherProduksi, NoMixer, NoSak);
    PRINT '>> Created IX_CrusherProduksiInputMixer_Label';
END
GO

IF OBJECT_ID('dbo.CrusherProduksiInputMixerPartial', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = 'IX_CrusherProduksiInputMixerPartial_Produksi'
                     AND object_id = OBJECT_ID('dbo.CrusherProduksiInputMixerPartial'))
BEGIN
    CREATE INDEX IX_CrusherProduksiInputMixerPartial_Produksi
        ON dbo.CrusherProduksiInputMixerPartial (NoCrusherProduksi);
    PRINT '>> Created IX_CrusherProduksiInputMixerPartial_Produksi';
END
GO

-- Satu kode partial hanya boleh dipakai sekali per produksi crusher.
IF OBJECT_ID('dbo.CrusherProduksiInputMixerPartial', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM sys.indexes
                   WHERE name = 'UX_CrusherProduksiInputMixerPartial_Kode'
                     AND object_id = OBJECT_ID('dbo.CrusherProduksiInputMixerPartial'))
BEGIN
    CREATE UNIQUE INDEX UX_CrusherProduksiInputMixerPartial_Kode
        ON dbo.CrusherProduksiInputMixerPartial (NoCrusherProduksi, NoMixerPartial);
    PRINT '>> Created UX_CrusherProduksiInputMixerPartial_Kode';
END
GO


/* =============================================================================
   LANGKAH 3 — FOREIGN KEY ke header produksi crusher (opsional)
   Hanya dijalankan kalau tabel header crusher benar-benar ada. Bila nama
   header di DB Anda berbeda, skip blok ini (data tetap valid tanpa FK).
   ============================================================================= */
DECLARE @hasHeader BIT = CASE WHEN OBJECT_ID('dbo.CrusherProduksi_h', 'U') IS NOT NULL
                               THEN 1 ELSE 0 END;

IF @hasHeader = 1
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
                   WHERE name = 'FK_CrusherProduksiInputMixer_Produksi')
    BEGIN
        ALTER TABLE dbo.CrusherProduksiInputMixer
            ADD CONSTRAINT FK_CrusherProduksiInputMixer_Produksi
            FOREIGN KEY (NoCrusherProduksi)
            REFERENCES dbo.CrusherProduksi_h (NoCrusherProduksi);
        PRINT '>> FK_CrusherProduksiInputMixer_Produksi created';
    END

    IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys
                   WHERE name = 'FK_CrusherProduksiInputMixerPartial_Produksi')
    BEGIN
        ALTER TABLE dbo.CrusherProduksiInputMixerPartial
            ADD CONSTRAINT FK_CrusherProduksiInputMixerPartial_Produksi
            FOREIGN KEY (NoCrusherProduksi)
            REFERENCES dbo.CrusherProduksi_h (NoCrusherProduksi);
        PRINT '>> FK_CrusherProduksiInputMixerPartial_Produksi created';
    END
END
ELSE
    PRINT '>> Header crusher tidak ditemukan - FK dilewati (aman)';
GO


/* =============================================================================
   LANGKAH 4 — VERIFIKASI
   ============================================================================= */
SELECT
    t.name    AS [tabel],
    c.name    AS [kolom],
    ty.name   AS [tipe],
    c.is_identity AS [identity],
    c.is_nullable AS [nullable]
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty  ON ty.user_type_id = c.user_type_id
WHERE t.name IN ('CrusherProduksiInputMixer', 'CrusherProduksiInputMixerPartial')
ORDER BY t.name, c.column_id;
GO

-- Contoh insert (hapus setelah testing)
-- INSERT INTO dbo.CrusherProduksiInputMixer
--     (NoCrusherProduksi, NoMixer, NoSak, Berat, IdJenis, NamaJenis)
-- VALUES
--     ('CR.20260101001', 'H.0000012345', 1, 1250.5000, 12, 'MIXER A');
--
-- INSERT INTO dbo.CrusherProduksiInputMixerPartial
--     (NoCrusherProduksi, NoMixer, NoSak, NoMixerPartial, Berat, IdJenis, NamaJenis)
-- VALUES
--     ('CR.20260101001', 'H.0000012345', 2, 'T.0001', 500.0000, 12, 'MIXER A');
GO
