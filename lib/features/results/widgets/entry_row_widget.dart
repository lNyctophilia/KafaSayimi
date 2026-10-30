import 'package:flutter/material.dart';
import '../../../core/models/barcode_entry.dart';
import '../../../core/theme/app_colors.dart';

/// A single editable row in the results table.
class EntryRowWidget extends StatefulWidget {
  final BarcodeEntry entry;
  final int index;
  final ValueChanged<BarcodeEntry> onChanged;
  final VoidCallback onDelete;

  const EntryRowWidget({
    super.key,
    required this.entry,
    required this.index,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  State<EntryRowWidget> createState() => _EntryRowWidgetState();
}

class _EntryRowWidgetState extends State<EntryRowWidget> {
  late TextEditingController _codeController;
  late TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.entry.barcodeCode);
    _qtyController = TextEditingController(text: widget.entry.quantity);
  }

  @override
  void didUpdateWidget(EntryRowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entry.barcodeCode != widget.entry.barcodeCode &&
        _codeController.text != widget.entry.barcodeCode) {
      _codeController.text = widget.entry.barcodeCode;
    }
    if (oldWidget.entry.quantity != widget.entry.quantity &&
        _qtyController.text != widget.entry.quantity) {
      _qtyController.text = widget.entry.quantity;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    widget.onChanged(widget.entry.copyWith(
      barcodeCode: value,
      isQuantityConfident: true,
      confidence: 100.0,
    ));
  }

  void _onQtyChanged(String value) {
    widget.onChanged(widget.entry.copyWith(
      quantity: value,
      isQuantityConfident: true,
      confidence: 100.0,
    ));
  }

  void _showConfidenceInfo(BuildContext context) {
    final isUnder90 = widget.entry.isUnder90;
    final pct = widget.entry.confidencePercentage;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.card,
        content: Row(
          children: [
            Icon(
              isUnder90 ? Icons.error_rounded : Icons.warning_rounded,
              color: isUnder90 ? AppColors.danger : AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUnder90 ? 'Kritik Eminlik: %$pct' : 'Düşük Eminlik: %$pct',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isUnder90 ? AppColors.danger : AppColors.warning,
                    ),
                  ),
                  Text(
                    isUnder90
                        ? 'Yapay zeka %90 altı eminlik tespit etti. Lütfen sayım kağıdındaki değeri doğrulayın.'
                        : 'Okuma eminliği %95 altında. Lütfen kutucuktaki adeti kontrol edin.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isQtyEmpty = widget.entry.quantity.trim().isEmpty;
    final isUnder95 = !isQtyEmpty && widget.entry.isUnder95;
    final isUnder90 = !isQtyEmpty && widget.entry.isUnder90;

    // Card border and background based on confidence:
    // < 90%: Red critical alert
    // < 95%: Amber warning alert
    // Empty: Error outline
    // >= 95%: Normal
    final Color borderColor = isQtyEmpty
        ? colorScheme.error.withValues(alpha: 0.6)
        : isUnder90
            ? AppColors.danger
            : isUnder95
                ? AppColors.warning
                : colorScheme.outlineVariant;

    final double borderWidth = (isQtyEmpty || isUnder90 || isUnder95) ? 1.6 : 1.0;

    final Color cardBgColor = isQtyEmpty
        ? colorScheme.errorContainer.withValues(alpha: 0.2)
        : isUnder90
            ? AppColors.danger.withValues(alpha: 0.14)
            : isUnder95
                ? AppColors.warning.withValues(alpha: 0.08)
                : colorScheme.surface;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      elevation: isQtyEmpty ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      color: cardBgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Row number pill
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isUnder90
                    ? AppColors.danger.withValues(alpha: 0.25)
                    : isUnder95
                        ? AppColors.warning.withValues(alpha: 0.25)
                        : colorScheme.primaryContainer,
                shape: BoxShape.circle,
                border: (isUnder90 || isUnder95)
                    ? Border.all(
                        color: isUnder90 ? AppColors.danger : AppColors.warning,
                        width: 1.2,
                      )
                    : null,
              ),
              child: Text(
                '${widget.index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isUnder90
                      ? AppColors.danger
                      : isUnder95
                          ? AppColors.warning
                          : colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Barcode text field (large, clear, readable)
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Barkod Kodu',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TextFormField(
                    controller: _codeController,
                    onChanged: _onCodeChanged,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: 'RR-XXXX/YYYY',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Quantity field (dedicated box, prominent text)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Adet',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: isQtyEmpty
                              ? colorScheme.error
                              : isUnder90
                                  ? AppColors.danger
                                  : isUnder95
                                      ? AppColors.warning
                                      : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isUnder90) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 14,
                          color: AppColors.danger,
                        ),
                      ] else if (isUnder95) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  TextFormField(
                    controller: _qtyController,
                    onChanged: _onQtyChanged,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isQtyEmpty
                          ? colorScheme.error
                          : isUnder90
                              ? AppColors.danger
                              : isUnder95
                                  ? AppColors.warning
                                  : colorScheme.primary,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: colorScheme.error.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Warning exclamation badge on the right if confidence < 95%
            if (isUnder95) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: isUnder90
                    ? 'Kritik Uyarı: Eminlik %${widget.entry.confidencePercentage} (< %90). Lütfen kontrol edin!'
                    : 'Uyarı: Eminlik %${widget.entry.confidencePercentage} (< %95). Lütfen kontrol edin.',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showConfidenceInfo(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      decoration: BoxDecoration(
                        color: isUnder90
                            ? AppColors.danger.withValues(alpha: 0.18)
                            : AppColors.warning.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isUnder90
                              ? AppColors.danger.withValues(alpha: 0.9)
                              : AppColors.warning.withValues(alpha: 0.9),
                          width: 1.3,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUnder90
                                ? Icons.error_rounded
                                : Icons.warning_rounded,
                            size: 19,
                            color: isUnder90 ? AppColors.danger : AppColors.warning,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '%${widget.entry.confidencePercentage}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isUnder90 ? AppColors.danger : AppColors.warning,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),

            // Delete button
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              iconSize: 22,
              color: colorScheme.error,
              onPressed: () => _confirmDelete(context),
              tooltip: 'Sil',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Satırı Sil'),
        content: Text(
          '"${widget.entry.barcodeCode.isNotEmpty ? widget.entry.barcodeCode : "Boş satır"}" '
          'silinecek. Emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDelete();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
