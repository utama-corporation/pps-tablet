import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../components/app_search_dropdown.dart';
import 'lokasi_view_model.dart';
import 'lokasi_model.dart';

class LokasiDropdown extends StatelessWidget {
  final Lokasi? value;
  final ValueChanged<Lokasi?>? onChanged;
  final String hint;
  final bool includeSemua;
  final Lokasi semuaOption;

  const LokasiDropdown({
    super.key,
    this.value,
    this.onChanged,
    this.hint = 'Pilih Lokasi',
    this.includeSemua = true,
    this.semuaOption = const Lokasi(idLokasi: '__SEMUA__', blok: '-', enable: true),
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<LokasiViewModel>(
      builder: (context, vm, _) {
        // Siapkan daftar lokasi (plus opsi "Semua" bila diminta)
        final lokasiItems = <Lokasi>[
          if (includeSemua) semuaOption,
          ...vm.lokasiList,
        ];

        final effectiveValue = value ?? (includeSemua ? semuaOption : null);

        // Tentukan helperText (prioritas: error → empty)
        final String? helperText = vm.errorMessage.isNotEmpty
            ? 'Error: ${vm.errorMessage}'
            : (vm.lokasiList.isEmpty ? 'Tidak ada data lokasi' : null);

        return AppSearchDropdown<Lokasi>(
          value: effectiveValue,
          items: lokasiItems,
          enabled: !vm.isLoading,
          isLoading: vm.isLoading,
          helperText: helperText,
          onRetry: vm.errorMessage.isNotEmpty
              ? () => context.read<LokasiViewModel>().fetchLokasiList()
              : null,

          hint: hint,
          searchHint: 'Cari…',

          // label tampilan
          itemAsString: (l) {
            if (l.idLokasi == '__SEMUA__') return 'Lokasi (Semua)';
            return l.idLokasi.isEmpty ? l.blok : '${l.blok}${l.idLokasi}';
          },

          // pastikan equality berdasarkan blok+id
          compareFn: (a, b) => a.blok == b.blok && a.idLokasi == b.idLokasi,

          // pencarian fleksibel
          filterFn: (l, filter) {
            final q = filter.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
            final k1 = ('${l.blok}${l.idLokasi}')
                .toLowerCase()
                .replaceAll(RegExp(r'[\s\-_]'), '');
            final k2 = l.blok.toLowerCase();
            return k1.contains(q) || k2.contains(q);
          },

          onChanged: (picked) {
            if (onChanged == null) return;
            if (picked?.idLokasi == '__SEMUA__') {
              onChanged!(null);
            } else {
              onChanged!(picked);
            }
          },
        );
      },
    );
  }
}
