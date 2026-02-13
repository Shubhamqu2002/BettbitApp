// lib/components/home/vendor_filter_components.dart
import 'package:flutter/material.dart';

class VendorFilterButton extends StatelessWidget {
  final bool isDisabled;
  final String label;
  final VoidCallback? onTap;

  const VendorFilterButton({
    super.key,
    required this.isDisabled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded,
                size: 18, color: Colors.white.withOpacity(0.92)),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.90),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VendorFilterSheet {
  /// Opens bottom sheet showing vendors in a 3-column grid.
  static Future<void> open<T>({
    required BuildContext context,
    required String title,
    required List<T> vendors,
    required String selectedVendorCode,

    /// Extractors
    required String Function(T v) vendorCodeOf,
    required String Function(T v) vendorNameOf,
    required String Function(T v) vendorImageUrlOf,

    /// Helpers from your screen (keeps exact image logic)
    required String Function(String raw) normalizeImageUrl,
    required Widget Function({
      required String url,
      required BoxFit fit,
      EdgeInsetsGeometry padding,
      Alignment alignment,
      double? iconSize,
    }) networkImageSmart,

    /// Actions
    required Future<void> Function() onSelectAll,
    required Future<void> Function(T vendor) onSelectVendor,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) {
        return _VendorFilterSheetBody<T>(
          title: title,
          vendors: vendors,
          selectedVendorCode: selectedVendorCode,
          vendorCodeOf: vendorCodeOf,
          vendorNameOf: vendorNameOf,
          vendorImageUrlOf: vendorImageUrlOf,
          normalizeImageUrl: normalizeImageUrl,
          networkImageSmart: networkImageSmart,
          onSelectAll: onSelectAll,
          onSelectVendor: onSelectVendor,
        );
      },
    );
  }
}

class _VendorFilterSheetBody<T> extends StatelessWidget {
  final String title;
  final List<T> vendors;
  final String selectedVendorCode;

  final String Function(T v) vendorCodeOf;
  final String Function(T v) vendorNameOf;
  final String Function(T v) vendorImageUrlOf;

  final String Function(String raw) normalizeImageUrl;

  final Widget Function({
    required String url,
    required BoxFit fit,
    EdgeInsetsGeometry padding,
    Alignment alignment,
    double? iconSize,
  }) networkImageSmart;

  final Future<void> Function() onSelectAll;
  final Future<void> Function(T vendor) onSelectVendor;

  const _VendorFilterSheetBody({
    required this.title,
    required this.vendors,
    required this.selectedVendorCode,
    required this.vendorCodeOf,
    required this.vendorNameOf,
    required this.vendorImageUrlOf,
    required this.normalizeImageUrl,
    required this.networkImageSmart,
    required this.onSelectAll,
    required this.onSelectVendor,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Container(
      height: h * 0.80,
      decoration: BoxDecoration(
        color: const Color(0xFF05070A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select a vendor to filter games',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.65),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _chip(label: selectedVendorCode == 'ALL'
                    ? 'ALL'
                    : selectedVendorCode),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: GridView.builder(
                itemCount: 1 + vendors.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // ✅ 3 in one row
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.86,
                ),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = selectedVendorCode == 'ALL';
                    return _vendorTile(
                      isSelected: isSelected,
                      name: 'ALL',
                      image: null,
                      onTap: () async {
                        Navigator.of(context).pop();
                        await onSelectAll();
                      },
                      networkImageSmart: networkImageSmart,
                    );
                  }

                  final v = vendors[index - 1];
                  final code = vendorCodeOf(v);
                  final isSelected = code == selectedVendorCode;

                  final rawLogo = vendorImageUrlOf(v);
                  final logoUrl = normalizeImageUrl(rawLogo);

                  return _vendorTile(
                    isSelected: isSelected,
                    name: vendorNameOf(v),
                    image: logoUrl,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await onSelectVendor(v);
                    },
                    networkImageSmart: networkImageSmart,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _chip({required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(0.90),
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Widget _vendorTile({
    required bool isSelected,
    required String name,
    required String? image,
    required Future<void> Function() onTap,
    required Widget Function({
      required String url,
      required BoxFit fit,
      EdgeInsetsGeometry padding,
      Alignment alignment,
      double? iconSize,
    }) networkImageSmart,
  }) {
    return InkWell(
      onTap: () {
        // fire-and-forget inside sheet
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF21C8F6), Color(0xFF637BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: !isSelected ? Colors.white.withOpacity(0.04) : null,
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.95)
                : Colors.white.withOpacity(0.10),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: Colors.black.withOpacity(0.35),
                  alignment: Alignment.center,
                  child: (image == null || image.trim().isEmpty)
                      ? Icon(
                          Icons.apps_rounded,
                          size: 34,
                          color:
                              Colors.white.withOpacity(isSelected ? 1.0 : 0.75),
                        )
                      : networkImageSmart(
                          url: image,
                          fit: BoxFit.contain,
                          padding: const EdgeInsets.all(10),
                          iconSize: 28,
                          alignment: Alignment.center,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
