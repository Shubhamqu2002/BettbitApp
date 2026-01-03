// lib/components/bettingrecords/betting_records_table.dart
import 'package:flutter/material.dart';
import '../../services/betting_records_service.dart';

class BettingRecordsTable extends StatefulWidget {
  final List<BetRecord> records;
  final bool isLoading;
  final int currentPage;
  final int pageSize;
  final int totalElements;
  final void Function(int page) onPageChanged;
  final String? errorMessage;

  const BettingRecordsTable({
    super.key,
    required this.records,
    required this.isLoading,
    required this.currentPage,
    required this.pageSize,
    required this.totalElements,
    required this.onPageChanged,
    this.errorMessage,
  });

  @override
  State<BettingRecordsTable> createState() => _BettingRecordsTableState();
}

class _BettingRecordsTableState extends State<BettingRecordsTable> {
  final Set<String> _expandedIds = <String>{};

  // Elegant color palette
  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color secondaryAccent = Color(0xFF8B5CF6);
  static const Color successAccent = Color(0xFF10B981);
  static const Color errorAccent = Color(0xFFEF4444);
  static const Color warningAccent = Color(0xFFF59E0B);
  static const Color cardBg = Color(0xFF1E293B);

  void _toggleExpanded(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}\n${two(dt.hour)}:${two(dt.minute)}';
  }

  String _formatAmount(BetRecord record, double value) {
    return '${record.currency} ${value.toStringAsFixed(2)}';
  }

  Color _resultColor(String? resultType) {
    if (resultType == null) return Colors.white;
    final upper = resultType.toUpperCase();
    if (upper.contains('WIN')) return successAccent;
    if (upper.contains('LOSE')) return errorAccent;
    return warningAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryAccent),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading records...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: errorAccent.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: errorAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                widget.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.records.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox_rounded,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No betting records found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final startItem = widget.currentPage * widget.pageSize + 1;
    final endItem = (startItem + widget.records.length - 1)
        .clamp(startItem, widget.totalElements);

    final bool isFirstPage = widget.currentPage == 0;
    final bool isLastPage =
        ((widget.currentPage + 1) * widget.pageSize) >= widget.totalElements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Records List
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: cardBg.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.records.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final record = widget.records[index];
                  final isExpanded = _expandedIds.contains(record.id);
                  final accent = _resultColor(record.resultType);

                  return _RecordCard(
                    record: record,
                    isExpanded: isExpanded,
                    accent: accent,
                    onTap: () => _toggleExpanded(record.id),
                    formatDate: _formatDate,
                    formatAmount: _formatAmount,
                  );
                },
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Pagination footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Showing $startItem–$endItem of ${widget.totalElements}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isFirstPage
                      ? null
                      : () => widget.onPageChanged(widget.currentPage - 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isFirstPage
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      color: isFirstPage
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryAccent, secondaryAccent],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Page ${widget.currentPage + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLastPage
                      ? null
                      : () => widget.onPageChanged(widget.currentPage + 1),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isLastPage
                          ? Colors.white.withOpacity(0.05)
                          : Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: isLastPage
                          ? Colors.white.withOpacity(0.3)
                          : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  final BetRecord record;
  final bool isExpanded;
  final Color accent;
  final VoidCallback onTap;
  final String Function(DateTime?) formatDate;
  final String Function(BetRecord, double) formatAmount;

  const _RecordCard({
    required this.record,
    required this.isExpanded,
    required this.accent,
    required this.onTap,
    required this.formatDate,
    required this.formatAmount,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isExpanded ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded
              ? accent.withOpacity(0.3)
              : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // Main Row
                Row(
                  children: [
                    // Status Indicator
                    Container(
                      width: 4,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accent,
                            accent.withOpacity(0.3),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Game Name & Badge
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  record.gameName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withOpacity(0.95),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: accent.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  record.resultType ?? 'N/A',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Date & Amounts
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.white.withOpacity(0.5),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  formatDate(record.date).replaceAll('\n', ' • '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.6),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _InfoChip(
                                  label: 'Bet',
                                  value: formatAmount(record, record.betAmount),
                                  color: Colors.blue.shade400,
                                ),
                                const SizedBox(width: 8),
                                _InfoChip(
                                  label: 'Win/Loss',
                                  value: formatAmount(record, record.winLoss),
                                  color: accent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Expand Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white.withOpacity(0.7),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),

                // Expanded Details
                if (isExpanded) ...[
                  const SizedBox(height: 16),
                  _ExpandedDetails(
                    record: record,
                    accent: accent,
                    formatDate: formatDate,
                    formatAmount: formatAmount,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedDetails extends StatelessWidget {
  final BetRecord record;
  final Color accent;
  final String Function(DateTime?) formatDate;
  final String Function(BetRecord, double) formatAmount;

  const _ExpandedDetails({
    required this.record,
    required this.accent,
    required this.formatDate,
    required this.formatAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Transaction Details', accent: accent),
          const SizedBox(height: 12),
          _DetailRow(label: 'Transaction ID', value: record.transactionId),
          _DetailRow(label: 'Trace ID', value: record.traceId),
          _DetailRow(label: 'Bet ID', value: record.betId),
          _DetailRow(label: 'Round ID', value: record.roundId),
          
          const SizedBox(height: 16),
          _SectionTitle(title: 'Game Information', accent: accent),
          const SizedBox(height: 12),
          _DetailRow(label: 'Game Code', value: record.gameCode),
          _DetailRow(label: 'Vendor', value: record.vendorCode),
          _DetailRow(label: 'Game Type', value: record.gameType ?? '--'),
          _DetailRow(label: 'Platform', value: record.platformCode),
          
          const SizedBox(height: 16),
          _SectionTitle(title: 'Financial Summary', accent: accent),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Bet Amount',
            value: formatAmount(record, record.betAmount),
          ),
          _DetailRow(
            label: 'Win Amount',
            value: formatAmount(record, record.winAmount),
          ),
          _DetailRow(
            label: 'Loss Amount',
            value: formatAmount(record, record.lossAmount),
          ),
          _DetailRow(
            label: 'Jackpot',
            value: formatAmount(record, record.jackpotAmount),
          ),
          _DetailRow(
            label: 'Closing Balance',
            value: formatAmount(record, record.currentClosingBalance),
          ),
          _DetailRow(
            label: 'Bonus Balance',
            value: formatAmount(record, record.currentBonusBalance),
          ),
          
          if ((record.remarks ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionTitle(title: 'Remarks', accent: accent),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                record.remarks!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color accent;

  const _SectionTitle({
    required this.title,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, accent.withOpacity(0.3)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.95),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}