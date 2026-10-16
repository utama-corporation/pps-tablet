import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/view_model/permission_view_model.dart';

class LabelSelectionScreen extends StatelessWidget {
  const LabelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final perm = context.watch<PermissionViewModel>();

    // ===== permissions per menu =====
    final canReadBahanBaku = perm.can(
      'penerimaanbahanbaku:read',
    ); // Label Bahan Baku
    final canReadWashing = perm.can('label_washing:read');
    final canReadBroker = perm.can('label_broker:read');
    final canReadBonggolan = perm.can('label_bonggolan:read');
    final canReadCrusher = perm.can(
      'label_crusher:read',
    ); // <-- kalau crusher belum ada permission khusus
    final canReadGilingan = perm.can('label_gilingan:read');
    final canReadMixer = perm.can('label_mixer:read');
    final canReadFurnitureWip = perm.can('label_furniturewip:read');
    final canReadPacking = perm.can(
      'label_barangjadi:read',
    ); // <-- kamu punya packing:read (bukan label_packing)
    final canReadReject = perm.can('label_reject:read');
    final canReadBahanPendukung = perm.can('label_bahanpendukung:read');

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildLabelCard(
            context,
            title: 'Label Bahan Baku',
            subtitle: 'Buat label untuk Bahan Baku',
            icon: Icons.label,
            enabled: canReadBahanBaku,
            onTap: canReadBahanBaku
                ? () => Navigator.pushNamed(context, '/label/bahan-baku')
                : null,
          ),

          _buildLabelCard(
            context,
            title: 'Label Washing',
            subtitle: 'Buat label untuk proses washing',
            icon: Icons.label,
            enabled: canReadWashing,
            onTap: canReadWashing
                ? () => Navigator.pushNamed(context, '/label/washing')
                : null,
          ),

          const SizedBox(height: 16),

          _buildLabelCard(
            context,
            title: 'Label Broker',
            subtitle: 'Buat label untuk proses broker',
            icon: Icons.label,
            enabled: canReadBroker,
            onTap: canReadBroker
                ? () => Navigator.pushNamed(context, '/label/broker')
                : null,
          ),

          const SizedBox(height: 16),

          _buildLabelCard(
            context,
            title: 'Label Bonggolan',
            subtitle: 'Buat label untuk proses bonggolan',
            icon: Icons.label,
            enabled: canReadBonggolan,
            onTap: canReadBonggolan
                ? () => Navigator.pushNamed(context, '/label/bonggolan')
                : null,
          ),

          _buildLabelCard(
            context,
            title: 'Label Crusher',
            subtitle: 'Buat label untuk proses crusher',
            icon: Icons.label,
            enabled: canReadCrusher,
            onTap: canReadCrusher
                ? () => Navigator.pushNamed(context, '/label/crusher')
                : null,
          ),

          _buildLabelCard(
            context,
            title: 'Label Gilingan',
            subtitle: 'Buat label untuk proses gilingan',
            icon: Icons.label,
            enabled: canReadGilingan,
            onTap: canReadGilingan
                ? () => Navigator.pushNamed(context, '/label/gilingan')
                : null,
          ),

          _buildLabelCard(
            context,
            title: 'Label Mixer',
            subtitle: 'Buat label untuk proses mixer',
            icon: Icons.label,
            enabled: canReadMixer,
            onTap: canReadMixer
                ? () => Navigator.pushNamed(context, '/label/mixer')
                : null,
          ),

          _buildLabelCard(
            context,
            title: 'Label Furniture WIP',
            subtitle: 'Buat label untuk proses FWIP',
            icon: Icons.label,
            enabled: canReadFurnitureWip,
            onTap: canReadFurnitureWip
                ? () => Navigator.pushNamed(context, '/label/furniture_wip')
                : null,
          ),

          _buildLabelCard(
            context,
            title: 'Label Barang Jadi',
            subtitle: 'Buat label untuk proses Barang Jadi',
            icon: Icons.label,
            enabled: canReadPacking,
            onTap: canReadPacking
                ? () => Navigator.pushNamed(context, '/label/packing')
                : null,
          ),

          _buildLabelCard(
            context,
            title: 'Label Reject',
            subtitle: 'Buat label untuk proses Reject',
            icon: Icons.label,
            enabled: canReadReject,
            onTap: canReadReject
                ? () => Navigator.pushNamed(context, '/label/reject')
                : null,
          ),

          _buildLabelCard(
            context,
            title: 'Label Bahan Pendukung',
            subtitle: 'Kelola label dari penerimaan bahan pendukung',
            icon: Icons.label,
            enabled: canReadBahanPendukung,
            onTap: canReadBahanPendukung
                ? () =>
                      Navigator.pushNamed(context, '/label/bahan-pendukung')
                : null,
          ),
        ],
      ),
    );
  }

  // 🔹 Reusable builder untuk setiap kartu label
  Widget _buildLabelCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
  }) {
    final Color baseColor = enabled ? Colors.blue : Colors.grey;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: Card(
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          onTap: enabled ? onTap : null,
          contentPadding: const EdgeInsets.all(20),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: baseColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 28, color: baseColor),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: enabled ? Colors.black87 : Colors.black45,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: enabled ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: baseColor),
        ),
      ),
    );
  }
}
