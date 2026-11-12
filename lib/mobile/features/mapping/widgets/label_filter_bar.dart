import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/lokasi/lokasi_dropdown.dart';
import '../../../shared/kategori/kategori_dropdown.dart';
import '../view_model/label_view_model.dart';
import '../../../shared/lokasi/lokasi_view_model.dart';
import '../../../shared/lokasi/lokasi_model.dart';

class LabelFilterBar extends StatelessWidget {
  const LabelFilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final labelVm = context.watch<LabelViewModel>();
    final lokasiVm = context.watch<LokasiViewModel>();

    // Cari lokasi yang sedang dipilih (berdasarkan selectedIdLokasi)
    final selectedLokasi = lokasiVm.lokasiList.firstWhere(
          (l) =>
      l.idLokasi == labelVm.selectedIdLokasi &&
          l.blok == labelVm.selectedBlok,
      orElse: () => const Lokasi(idLokasi: '__SEMUA__', blok: '-', enable: true),
    );


    return Row(
      children: [
        // ⬅️ Dropdown Kategori
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: KategoriDropdown(
              value: labelVm.selectedKategori,
              onChanged: (val) => labelVm.setKategori(val),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // ⬅️ Dropdown Lokasi
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: LokasiDropdown(
              value: selectedLokasi,
              includeSemua: true,
              onChanged: (lokasi) {
                if (lokasi == null) {
                  labelVm.setLokasi(idLokasi: null, blok: null);
                } else {
                  labelVm.setLokasi(idLokasi: lokasi.idLokasi, blok: lokasi.blok);
                }
              },

            ),
          ),
        ),
      ],
    );
  }
}
