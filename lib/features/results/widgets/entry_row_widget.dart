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
    final isUnder87 = widget.entry.isUnder87;
    final pct = widget.entry.confidencePercentage;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.card,
        content: Row(
          children: [
            Icon(
              isUnder87 ? Icons.error_rounded : Icons.warning_rounded,
              color: isUnder87 ? AppColors.danger : AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUnder87 ? 'Kritik Eminlik: %$pct' : 'Düşük Eminlik: %$pct',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isUnder87 ? AppColors.danger : AppColors.warning,
                    ),
                  ),
                  Text(
                    isUnder87
                        ? 'Yapay zeka %87 altı eminlik tespit etti. Lütfen sayım kağıdındaki değeri doğrulayın.'
                        : 'Okuma eminliği %92 altında. Lütfen kutucuktaki adeti kontrol edin.',
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
    final isUnder92 = !isQtyEmpty && widget.entry.isUnder92;
    final isUnder87 = !isQtyEmpty && widget.entry.isUnder87;

    // Card border and background:
    // Sadece adet boş ise uyarı çerçevesi gösterilir.
    // Şüpheli satırlarda kart çerçevesi sade bırakılır, uyarı sadece yandaki yüzde rozetinde gösterilir.
    final Color borderColor = isQtyEmpty
        ? colorScheme.error.withValues(alpha: 0.6)
        : colorScheme.outlineVariant;

    final double borderWidth = isQtyEmpty ? 1.6 : 1.0;

    final Color cardBgColor = isQtyEmpty
        ? colorScheme.errorContainer.withValues(alpha: 0.2)
        : colorScheme.surface;

    // Soft, non-glaring badge colors:
    // < 87%: Muted red
    // 87% - 92%: Muted yellow/amber
    const Color badgeRed = Color(0xFFE05368);
    const Color badgeYellow = Color(0xFFE5A93C);
    final Color badgeColor = isUnder87 ? badgeRed : badgeYellow;

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
            // Row number pill (clean, standard style)
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${widget.index + 1}',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onPrimaryContainer,
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
                  Text(
                    'Adet',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isQtyEmpty
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
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

            // Warning exclamation badge on the right if confidence < 92%
            if (isUnder92) ...[
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    ' ',
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  SizedBox(
                    height: 51,
                    child: Tooltip(
                      message: isUnder87
                          ? 'Kritik Uyarı: Eminlik %${widget.entry.confidencePercentage} (< %87). Lütfen kontrol edin!'
                          : 'Uyarı: Eminlik %${widget.entry.confidencePercentage} (< %92). Lütfen kontrol edin.',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showConfidenceInfo(context),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 51,
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: badgeColor.withValues(alpha: 0.65),
                                width: 1.2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isUnder87
                                      ? Icons.error_outline_rounded
                                      : Icons.warning_amber_rounded,
                                  size: 18,
                                  color: badgeColor,
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '%${widget.entry.confidencePercentage}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: badgeColor,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
