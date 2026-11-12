import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/view_model/label_print_lock_socket_manager.dart';

class LabelPrintCountCell extends StatelessWidget {
  const LabelPrintCountCell({
    super.key,
    required this.labelCode,
    required this.rawPrintCount,
  });

  final String labelCode;
  final int rawPrintCount;

  @override
  Widget build(BuildContext context) {
    return Selector<LabelPrintLockSocketManager, _PrintCellState>(
      selector: (_, locks) => _PrintCellState(
        lock: locks.lockOf(labelCode),
        count: locks.printCountOf(labelCode),
      ),
      builder: (_, state, __) {
        final lock = state.lock;
        if (lock != null) {
          return Tooltip(
            message: 'Sedang diprint oleh ${lock.displayUser}',
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFB26A00).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFB26A00).withValues(alpha: 0.30),
                ),
              ),
              child: const Text(
                'Printing',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB26A00),
                ),
              ),
            ),
          );
        }

        final count = state.count ?? rawPrintCount;
        if (count == 0) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              '-',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF0C66E4).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF0C66E4).withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.print_rounded,
                size: 12,
                color: Color(0xFF0C66E4),
              ),
              const SizedBox(width: 4),
              Text(
                '${count}x',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0C66E4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrintCellState {
  final LabelPrintLockInfo? lock;
  final int? count;

  const _PrintCellState({required this.lock, required this.count});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _PrintCellState &&
        other.lock == lock &&
        other.count == count;
  }

  @override
  int get hashCode => Object.hash(lock, count);
}
