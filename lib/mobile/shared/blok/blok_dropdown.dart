import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'blok_view_model.dart';

class BlokDropdown extends StatelessWidget {
  const BlokDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BlokViewModel>(
      builder: (context, vm, child) {
        if (vm.isLoading) {
          return const CircularProgressIndicator();
        }
        if (vm.errorMessage.isNotEmpty) {
          return Text("Error: ${vm.errorMessage}");
        }
        if (vm.blokList.isEmpty) {
          return const Text("Tidak ada data blok");
        }

        return DropdownButton<int>(
          hint: const Text("Pilih Blok"),
          items: vm.blokList
              .map((blok) => DropdownMenuItem(
            value: blok.idWarehouse,
            child: Text("${blok.blok} (Gudang ${blok.idWarehouse})"),
          ))
              .toList(),
          onChanged: (value) {
            debugPrint("Blok dipilih: $value");
          },
        );
      },
    );
  }
}
