import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_error.dart';
import '../view_model/favorit_view_model.dart';

/// Tombol bintang favorit — tap menambahkan (dengan dialog komentar) bila
/// belum ada di daftar, atau menghapus bila sudah.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.tipe,
    required this.kode,
    this.iconSize = 20,
  });

  final String tipe; // 'laporan' | 'menu'
  final String kode;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Consumer<FavoritViewModel>(
      builder: (context, vm, _) {
        final active = vm.isFavorite(tipe, kode);
        return IconButton(
          tooltip: active ? 'Hapus dari favorit' : 'Tambah ke favorit',
          visualDensity: VisualDensity.compact,
          onPressed: vm.busy ? null : () => _toggle(context, vm, active),
          icon: Icon(
            active ? Icons.star_rounded : Icons.star_border_rounded,
            size: iconSize,
            color: active ? Colors.amber.shade700 : const Color(0xFF9CA3AF),
          ),
        );
      },
    );
  }

  Future<void> _toggle(
    BuildContext context,
    FavoritViewModel vm,
    bool active,
  ) async {
    if (active) {
      await _runToggle(context, () => vm.toggle(tipe: tipe, kode: kode));
      return;
    }
    final komentar = await showDialog<String>(
      context: context,
      builder: (_) => const FavoriteCommentDialog(),
    );
    if (komentar == null) return;
    if (!context.mounted) return;
    await _runToggle(
      context,
      () => vm.toggle(tipe: tipe, kode: kode, komentar: komentar),
    );
  }

  Future<void> _runToggle(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah favorit: ${apiErrorMessage(e)}'),
        ),
      );
    }
  }
}

class FavoriteCommentDialog extends StatefulWidget {
  const FavoriteCommentDialog({super.key});

  @override
  State<FavoriteCommentDialog> createState() => _FavoriteCommentDialogState();
}

class _FavoriteCommentDialogState extends State<FavoriteCommentDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah Favorit'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Komentar (opsional)',
            hintText: 'Tulis catatan untuk favorit ini',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
