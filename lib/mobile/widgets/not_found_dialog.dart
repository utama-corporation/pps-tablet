import 'package:flutter/material.dart';

class NotFoundDialog extends StatelessWidget {
  final String message;
  final Function onConfirm; // Menambahkan callback untuk konfirmasi

  const NotFoundDialog({Key? key, required this.message, required this.onConfirm}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Peringatan'),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Menutup dialog dan tidak melanjutkan
          },
          child: const Text('Tidak'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Menutup dialog
            onConfirm(); // Menjalankan fungsi konfirmasi untuk melanjutkan input
          },
          child: const Text('Ya'),
        ),
      ],
    );
  }
}
