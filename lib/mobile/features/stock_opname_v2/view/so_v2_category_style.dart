import 'package:flutter/material.dart';

const Color soV2ThemeBlue = Color(0xFF0D47A1);
const Color soV2ThemeBlueLight = Color(0xFF1565C0);
const Color soV2CompleteGreen = Color(0xFF15803D);

const Map<String, IconData> _soV2CategoryIcons = {
  'bahanbaku': Icons.factory_outlined,
  'washing': Icons.local_laundry_service_outlined,
  'broker': Icons.handshake_outlined,
  'crusher': Icons.recycling_outlined,
  'bonggolan': Icons.grain_outlined,
  'gilingan': Icons.blender_outlined,
  'mixer': Icons.science_outlined,
  'furniturewip': Icons.chair_outlined,
  'barangjadi': Icons.inventory_2_outlined,
  'reject': Icons.delete_outline,
};

IconData soV2IconForCategory(String categoryCode) =>
    _soV2CategoryIcons[categoryCode.toLowerCase()] ??
    Icons.inventory_2_outlined;
