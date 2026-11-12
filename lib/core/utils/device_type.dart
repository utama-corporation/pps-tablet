import 'package:flutter/material.dart';

/// Ponsel (HP) dideteksi dari sisi terkecil layar < 600 dp (pola wps_tablet_v2).
/// Meski rotasi membuat dimensi berubah, ukuran sisi terkecil yang < 600
/// selalu mewakili HP dalam mode portrait maupun landscape.
bool isPhoneDevice(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide < 600;
