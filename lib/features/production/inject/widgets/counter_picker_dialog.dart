import 'package:flutter/material.dart';

const _kCounterAccent = Color(0xFF0277BD);
const _kDigitCount = 7;

class CounterPickerDialog extends StatefulWidget {
  const CounterPickerDialog({
    super.key,
    required this.initialValue,
    this.accentColor = _kCounterAccent,
    this.minValue,
  });
  final int initialValue;
  final Color accentColor;
  final int? minValue;

  @override
  State<CounterPickerDialog> createState() => _CounterPickerDialogState();
}

class _CounterPickerDialogState extends State<CounterPickerDialog> {
  static const int _maxValue = 9999999;
  late final List<FixedExtentScrollController> _ctrls;
  late List<int> _digits; // index 0 = most significant

  int get _min => widget.minValue ?? 0;

  int get _value {
    int v = 0;
    for (final d in _digits) {
      v = v * 10 + d;
    }
    return v;
  }

  List<int> _toDigits(int value) {
    final s = value.clamp(0, _maxValue).toString().padLeft(_kDigitCount, '0');
    return s.split('').map(int.parse).toList();
  }

  @override
  void initState() {
    super.initState();
    _digits = _toDigits(widget.initialValue.clamp(_min, _maxValue));
    _ctrls = List.generate(_kDigitCount, (i) {
      return FixedExtentScrollController(initialItem: _digits[i]);
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  void _onDigitChanged(int digitIndex, int newDigit) {
    setState(() => _digits[digitIndex] = newDigit);
  }

  void _resetToMin() {
    final d = _toDigits(_min);
    final from = _value;
    final target = _min;
    // Drum dipaksa lompat (bukan `animateToItem`) supaya posisinya pasti berubah.
    // Drum juga di-reset dari state-nya, karena kalau cuma digit state yang
    // di-update, wheel tetap menampilkan angka lama sampai operator drag
    // manual.
    setState(() => _digits = List<int>.of(d));
    for (var i = 0; i < _kDigitCount; i++) {
      final ctrl = _ctrls[i];
      if (ctrl.hasClients) ctrl.jumpToItem(d[i]);
    }
    // Umpan balik eksplisit supaya operator tahu tap-nya register — kalau
    // angka drum sudah sama dengan odometer, tidak ada perubahan visual
    // sehingga tombol terlihat "tidak berfungsi".
    final msg = ScaffoldMessenger.maybeOf(context);
    msg?.clearSnackBars();
    msg?.showSnackBar(
      SnackBar(
        content: Text(
          from == target
              ? 'Odometer sudah $target'
              : 'Odometer direset: $from → $target',
        ),
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        width: 240,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    final current = _value;
    final min = _min;
    final isBelowMin = current < min;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ───────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.speed_outlined, size: 16, color: accent),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Counter / Odometer',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF9CA3AF),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              if (widget.minValue != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _resetToMin,
                      borderRadius: BorderRadius.circular(6),
                      child: Ink(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.restart_alt_rounded,
                                size: 12, color: accent),
                            const SizedBox(width: 5),
                            Text(
                              'Odometer saat ini: ${widget.minValue}  ·  Ketuk untuk reset',
                              style: TextStyle(
                                fontSize: 10,
                                color: accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── Odometer drum ─────────────────────────────────────
              _OdometerDrum(
                digits: _digits,
                controllers: _ctrls,
                accent: accent,
                onDigitChanged: _onDigitChanged,
              ),

              const SizedBox(height: 10),

              // ── Live readout ──────────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isBelowMin
                      ? const Color(0xFFFEF2F2)
                      : accent.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isBelowMin
                        ? const Color(0xFFFCA5A5)
                        : accent.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBelowMin
                          ? Icons.warning_amber_rounded
                          : Icons.speed_outlined,
                      size: 14,
                      color: isBelowMin ? const Color(0xFFDC2626) : accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isBelowMin
                          ? 'Nilai $current < minimum $min'
                          : 'Nilai: $current',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isBelowMin ? const Color(0xFFDC2626) : accent,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Confirm ───────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBelowMin ? Colors.grey.shade300 : accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  onPressed: isBelowMin
                      ? null
                      // Baca nilai langsung dari drum, bukan capture saat build,
                      // supaya hasil reset/klik terakhir selalu ikut terkirim.
                      : () => Navigator.of(context).pop(_value),
                  child: const Text(
                    'Konfirmasi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Odometer Drum ──────────────────────────────────────────────────────────────

class _OdometerDrum extends StatelessWidget {
  const _OdometerDrum({
    required this.digits,
    required this.controllers,
    required this.accent,
    required this.onDigitChanged,
  });

  final List<int> digits;
  final List<FixedExtentScrollController> controllers;
  final Color accent;
  final void Function(int digitIndex, int newDigit) onDigitChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_kDigitCount * 2 - 1, (i) {
          if (i.isOdd) {
            return Container(
              width: 1,
              height: 80,
              color: accent.withValues(alpha: 0.12),
            );
          }
          final digitIndex = i ~/ 2;
          return _SingleDigitDrum(
            digitIndex: digitIndex,
            currentDigit: digits[digitIndex],
            controller: controllers[digitIndex],
            accent: accent,
            onChanged: (v) => onDigitChanged(digitIndex, v),
          );
        }),
      ),
    );
  }
}

// ── Single Digit Drum ──────────────────────────────────────────────────────────

class _SingleDigitDrum extends StatelessWidget {
  const _SingleDigitDrum({
    required this.digitIndex,
    required this.currentDigit,
    required this.controller,
    required this.accent,
    required this.onChanged,
  });

  final int digitIndex;
  final int currentDigit;
  final FixedExtentScrollController controller;
  final Color accent;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Position label: 1st, 2nd, ... 7th or just show nothing
    const bgColor = Color(0xFFF8FAFC);
    return SizedBox(
      width: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Selection highlight band ─────────────────────────
          Positioned(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accent.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
            ),
          ),
          // ── Fade gradient top ────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 30,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [bgColor, bgColor.withValues(alpha: 0)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          // ── Fade gradient bottom ─────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 30,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [bgColor, bgColor.withValues(alpha: 0)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
              ),
            ),
          ),
          // ── Scroll wheel ─────────────────────────────────────
          SizedBox(
            height: 120,
            child: ListWheelScrollView(
              controller: controller,
              itemExtent: 36,
              perspective: 0.004,
              diameterRatio: 1.6,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => onChanged(i % 10),
              children: List.generate(10, (d) {
                final isSelected = d == currentDigit;
                return Center(
                  child: Text(
                    '$d',
                    style: TextStyle(
                      fontSize: isSelected ? 22 : 15,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w400,
                      color: isSelected
                          ? accent
                          : accent.withValues(alpha: 0.25),
                      letterSpacing: -0.5,
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step button (still exported for potential reuse) ──────────────────────────

class CounterStepBtn extends StatelessWidget {
  const CounterStepBtn({
    super.key,
    required this.icon,
    required this.onTap,
    this.accentColor = _kCounterAccent,
    this.onLongPress,
    this.disabled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color accentColor;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      onLongPress: disabled ? null : onLongPress,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFF3F4F6)
              : accentColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled
                ? const Color(0xFFE5E7EB)
                : accentColor.withValues(alpha: 0.25),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: disabled ? const Color(0xFFD1D5DB) : accentColor,
        ),
      ),
    );
  }
}
