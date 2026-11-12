import 'package:flutter/material.dart';

class InputIdLabelStockOpnameDialog extends StatefulWidget {
  final Function(String label) onSubmit;

  const InputIdLabelStockOpnameDialog({
    Key? key,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<InputIdLabelStockOpnameDialog> createState() => _InputIdLabelStockOpnameDialogState();
}

class _InputIdLabelStockOpnameDialogState extends State<InputIdLabelStockOpnameDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorText = 'Nomor label tidak boleh kosong';
      });
      return;
    }
    Navigator.of(context).pop(); // Tutup dialog
    widget.onSubmit(text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 10),
      titlePadding: const EdgeInsets.only(left: 24, right: 8, top: 24, bottom: 0),
      title: Stack(
        children: [
          Row(
            children: const [
              Icon(Icons.edit, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Text('Input Manual'),
            ],
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Nomor Label',
              border: const OutlineInputBorder(),
              errorText: _errorText,
            ),
            autofocus: true,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[900],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
