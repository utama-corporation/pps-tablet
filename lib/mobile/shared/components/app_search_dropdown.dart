import 'package:flutter/material.dart';
import 'package:dropdown_search/dropdown_search.dart';

class AppSearchDropdown<T> extends StatelessWidget {
  final T? value;
  final List<T> items;
  final ValueChanged<T?>? onChanged;
  final String? hint;
  final String Function(T)? itemAsString;
  final bool enabled;
  final bool showSearchBox;
  final String? searchHint;
  final bool isExpanded;

  // custom compare/filter (kamu sudah punya)
  final bool Function(T, T)? compareFn;
  final bool Function(T, String)? filterFn;

  // ⬇️ UI state dipusatkan di sini
  final bool isLoading;        // tampilkan spinner + disable interaksi
  final String? helperText;    // info kecil di bawah (error/empty/info)
  final VoidCallback? onRetry; // kalau diisi, munculkan tombol Retry

  const AppSearchDropdown({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.itemAsString,
    this.hint,
    this.enabled = true,
    this.showSearchBox = true,
    this.searchHint = 'Cari...',
    this.isExpanded = true,
    this.compareFn,
    this.filterFn,
    this.isLoading = false,
    this.helperText,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveEnabled = enabled && !isLoading;

    // ====== Komponen Dropdown utama ======
    final dropdown = IgnorePointer(
      ignoring: !effectiveEnabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: effectiveEnabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: effectiveEnabled ? Colors.grey.shade400 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, 1),
              blurRadius: 2,
            ),
          ],
        ),
        child: DropdownSearch<T>(
          items: items,
          selectedItem: value,
          enabled: effectiveEnabled,

          // forward compare/filter
          compareFn: compareFn,
          filterFn: filterFn,
          itemAsString: itemAsString,

          // caret → spinner saat loading
          dropdownButtonProps: DropdownButtonProps(
            icon: isLoading
                ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.arrow_drop_down, color: Colors.grey),
            alignment: Alignment.center,
          ),

          // Tampilan komponen tertutup (selected / hint)
          dropdownBuilder: (context, selectedItem) {
            final displayText = selectedItem == null
                ? (hint ?? 'Pilih item')
                : (itemAsString?.call(selectedItem) ?? selectedItem.toString());

            return Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: selectedItem == null
                      ? Colors.grey.shade600
                      : Colors.black87,
                  height: 1.2,
                ),
              ),
            );
          },

          // Popup (menu) + builder untuk loading/empty/error
          popupProps: PopupProps.menu(
            fit: FlexFit.loose,
            showSearchBox: showSearchBox,
            searchDelay: Duration.zero,
            constraints: const BoxConstraints(maxHeight: 500),
            menuProps: MenuProps(
              backgroundColor: Colors.white,
              elevation: 3,
              borderRadius: BorderRadius.circular(8),
            ),
            searchFieldProps: TextFieldProps(
              enabled: effectiveEnabled,
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400, width: 1.2),
                ),
              ),
            ),

            // saat isLoading true, pakai loadingBuilder terlepas dari 'items'
            loadingBuilder: (ctx, str) => const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Memuat data...'),
                ],
              ),
            ),

            emptyBuilder: (ctx, str) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Tidak ada data', style: theme.textTheme.bodyMedium),
            ),

            errorBuilder: (ctx, str, dyn) => Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(str ?? 'Terjadi kesalahan', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.redAccent))),
                  if (onRetry != null)
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),

          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),

          // kalau isLoading, jangan panggil onChanged
          onChanged: isLoading ? null : onChanged,
        ),
      ),
    );

    // ====== HelperText + Retry di bawah komponen (opsional) ======
    if (helperText == null || helperText!.isEmpty) return dropdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        dropdown,
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRetry != null) const Icon(Icons.error_outline, size: 14, color: Colors.redAccent),
            if (onRetry != null) const SizedBox(width: 4),
            // Flexible(
            //   child: Text(
            //     helperText!,
            //     style: theme.textTheme.bodySmall?.copyWith(
            //       color: onRetry != null ? Colors.redAccent : Colors.grey[600],
            //     ),
            //   ),
            // ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
