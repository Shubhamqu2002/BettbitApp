import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/account_records_service.dart';

class AccountRecordsTable extends StatefulWidget {
  final List<AccountLedgerItem> items;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  // pagination props (from API)
  final int totalElements;
  final int totalPages;
  final int pageNumber; // 0-based
  final int pageSize;
  final bool isFirst;
  final bool isLast;

  final void Function(int pageNumber) onPageChanged;

  const AccountRecordsTable({
    super.key,
    required this.items,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.totalElements,
    required this.totalPages,
    required this.pageNumber,
    required this.pageSize,
    required this.isFirst,
    required this.isLast,
    required this.onPageChanged,
  });

  @override
  State<AccountRecordsTable> createState() => _AccountRecordsTableState();
}

class _AccountRecordsTableState extends State<AccountRecordsTable> {
  final Set<String> _expanded = <String>{};

  String _money(String currency, double v) {
    final f = NumberFormat("#,##0.00", "en_IN");
    return "$currency ${f.format(v)}";
  }

  String _dt(DateTime? d) {
    if (d == null) return "--";
    return DateFormat("dd MMM yyyy, hh:mm a").format(d);
  }

  Color _statusColor(String s) {
    final up = s.toUpperCase();
    if (up == "CONFIRMED") return const Color(0xFF22C55E);
    if (up == "PENDING") return const Color(0xFFF59E0B);
    if (up == "REJECTED") return const Color(0xFFEF4444);
    return Colors.white70;
  }

  Color _typeColor(String t) {
    final up = t.toUpperCase();
    if (up.contains("WITHDRAW")) return const Color(0xFF60A5FA);
    if (up.contains("DEPOSIT")) return const Color(0xFF22C55E);
    if (up.contains("TRANSACTION")) return const Color(0xFFB794F6);
    return Colors.white70;
  }

  Widget _chip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: c,
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: for CONFIRMED show transactionValue, else show amount (PENDING/REJECTED etc.)
  double _displayAmount(AccountLedgerItem it) {
    final st = it.status.trim().toUpperCase();
    if (st == "CONFIRMED") {
      // If your model has transactionValue, this will work directly.
      // If it's nullable in your model, keep the fallback as 0.0.
      return (it.transactionValue);
    }
    return it.amount;
  }

  // ✅ NEW: image row (replaces showing URL text)
  Widget _kvImage(String k, String? url) {
    final u = (url ?? "").trim();
    final hasImage = u.isNotEmpty && u != "--";

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              k,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: hasImage
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => _openImageModal(u),
                      child: Container(
                        height: 64,
                        width: 92,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.16)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 14,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              u,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: Colors.white.withOpacity(0.06),
                                  alignment: Alignment.center,
                                  child: SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      value: progress.expectedTotalBytes == null
                                          ? null
                                          : progress.cumulativeBytesLoaded /
                                              (progress.expectedTotalBytes ?? 1),
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, _, __) {
                                return Container(
                                  color: Colors.white.withOpacity(0.06),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.broken_image_rounded,
                                          color: Colors.white.withOpacity(0.65), size: 22),
                                      const SizedBox(height: 6),
                                      Text(
                                        "Failed",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withOpacity(0.72),
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            Positioned(
                              right: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                                ),
                                child: const Icon(
                                  Icons.zoom_out_map_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Text(
                    "--",
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: modal image preview
  void _openImageModal(String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF7C3AED).withOpacity(0.22),
                  const Color(0xFF2563EB).withOpacity(0.18),
                  const Color(0xFF22C55E).withOpacity(0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withOpacity(0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.black.withOpacity(0.35),
                          alignment: Alignment.center,
                          child: SizedBox(
                            height: 26,
                            width: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.6,
                              value: progress.expectedTotalBytes == null
                                  ? null
                                  : progress.cumulativeBytesLoaded /
                                      (progress.expectedTotalBytes ?? 1),
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, _, __) {
                        return Container(
                          color: Colors.black.withOpacity(0.35),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.broken_image_rounded,
                                  color: Colors.white.withOpacity(0.75), size: 42),
                              const SizedBox(height: 10),
                              Text(
                                "Unable to load image",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _skeleton() {
    return ListView.separated(
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        return Container(
          height: 92,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.black.withOpacity(0.35),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
        );
      },
    );
  }

  int _fromIndex() {
    if (widget.totalElements == 0) return 0;
    return (widget.pageNumber * widget.pageSize) + 1;
  }

  int _toIndex() {
    final calc = (widget.pageNumber * widget.pageSize) + widget.items.length;
    if (calc > widget.totalElements) return widget.totalElements;
    return calc;
  }

  Widget _paginationBar() {
    final hasPages = widget.totalPages > 1;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C3AED).withOpacity(0.18),
            const Color(0xFF2563EB).withOpacity(0.14),
            const Color(0xFF22C55E).withOpacity(0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "Showing ${_fromIndex()}-${_toIndex()} of ${widget.totalElements}",
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          if (hasPages) ...[
            _navBtn(
              icon: Icons.chevron_left_rounded,
              enabled: !widget.isFirst,
              onTap: () => widget.onPageChanged(widget.pageNumber - 1),
            ),
            const SizedBox(width: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(widget.totalPages, (i) {
                  final selected = i == widget.pageNumber;
                  return GestureDetector(
                    onTap: () => widget.onPageChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: selected
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFF7C3AED).withOpacity(0.95),
                                  const Color(0xFF2563EB).withOpacity(0.90),
                                ],
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.10),
                                  Colors.white.withOpacity(0.06),
                                ],
                              ),
                        border: Border.all(
                          color: selected
                              ? Colors.white.withOpacity(0.22)
                              : Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Text(
                        "${i + 1}",
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 4),
            _navBtn(
              icon: Icons.chevron_right_rounded,
              enabled: !widget.isLast,
              onTap: () => widget.onPageChanged(widget.pageNumber + 1),
            ),
          ],
        ],
      ),
    );
  }

  Widget _navBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: enabled ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.06),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: Icon(
          icon,
          color: enabled ? Colors.white : Colors.white.withOpacity(0.35),
          size: 20,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) return _skeleton();

    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 34),
              const SizedBox(height: 10),
              Text(
                widget.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: widget.onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.16),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.items.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: Center(
              child: Text(
                "No records found for this filter.",
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
            ),
          ),
          _paginationBar(),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            itemCount: widget.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final it = widget.items[index];
              final isOpen = _expanded.contains(it.ledgerId);

              final statusC = _statusColor(it.status);
              final txType = (it.transactionType.isNotEmpty
                      ? it.transactionType
                      : (it.remarks ?? "--"))
                  .toUpperCase();
              final typeC = _typeColor(txType);

              final shownAmount = _displayAmount(it); // ✅ here

              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7C3AED).withOpacity(0.30),
                      const Color(0xFF2563EB).withOpacity(0.22),
                      const Color(0xFF22C55E).withOpacity(0.16),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: isOpen,
                          onChanged: (v) {
                            setState(() {
                              if (isOpen) {
                                _expanded.remove(it.ledgerId);
                              } else {
                                _expanded.add(it.ledgerId);
                              }
                            });
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          side: BorderSide(color: Colors.white.withOpacity(0.35)),
                          activeColor: const Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.receipt_long_rounded,
                                      color: Colors.white70, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _dt(it.date),
                                      style: const TextStyle(
                                        fontSize: 12.8,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: typeC.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: typeC.withOpacity(0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      txType.contains("WITHDRAW")
                                          ? Icons.north_east_rounded
                                          : txType.contains("DEPOSIT")
                                              ? Icons.south_west_rounded
                                              : Icons.swap_horiz_rounded,
                                      size: 16,
                                      color: typeC,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      txType,
                                      style: TextStyle(
                                        fontSize: 11.8,
                                        fontWeight: FontWeight.w900,
                                        color: typeC,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    _chip(it.currency, const Color(0xFF60A5FA)),
                                    const SizedBox(width: 10),
                                    _chip(it.status.isEmpty ? "--" : it.status, statusC),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // ✅ CHANGED: show transactionValue for CONFIRMED, else amount
                            Text(
                              _money(it.currency, shownAmount),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF00E5FF),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Bal: ${_money(it.currency, it.currentBalance)}",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.78),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Bonus: ${_money(it.currency, it.bonusBalance)}",
                              style: TextStyle(
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      duration: const Duration(milliseconds: 220),
                      crossFadeState:
                          isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      firstChild: const SizedBox(height: 0),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.28),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _kv("Wallet ID", it.walletId),
                              _kv("User Name", it.userName),
                              _kv("Transaction ID", it.transactionId),

                              // ✅ CHANGED: same place where you show Amount
                              _kv("Amount", _money(it.currency, shownAmount)),

                              _kv("Current Balance", _money(it.currency, it.currentBalance)),
                              _kv("Bonus Balance", _money(it.currency, it.bonusBalance)),
                              _kv("Transaction Type",
                                  it.transactionType.isEmpty ? "--" : it.transactionType),
                              _kv("Status", it.status.isEmpty ? "--" : it.status),
                              _kv("Payment Method", it.paymentMethod ?? "--"),
                              _kvImage("Image", it.imageUrl),
                              _kv("Address", it.address ?? "--"),
                              _kv("Crypto Amount", it.cryptoAmount?.toString() ?? "--"),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _paginationBar(),
      ],
    );
  }
}
