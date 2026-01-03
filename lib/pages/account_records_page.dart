import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/accountrecords/account_records_table.dart';
import '../services/account_records_service.dart';

enum LedgerTab { transaction, deposit, withdrawal }

class AccountRecordsPage extends StatefulWidget {
  const AccountRecordsPage({super.key});

  @override
  State<AccountRecordsPage> createState() => _AccountRecordsPageState();
}

class _AccountRecordsPageState extends State<AccountRecordsPage>
    with SingleTickerProviderStateMixin {
  final AccountRecordsService _service = AccountRecordsService();

  // UI state
  LedgerTab _tab = LedgerTab.transaction;
  String _statusUi = "All";

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Data state
  bool _isLoading = false;
  String? _error;
  List<AccountLedgerItem> _items = [];

  // Pagination state
  int _page = 0;
  final int _size = 10;
  AccountLedgerPage? _pageMeta;

  // Filter expansion state
  bool _filtersExpanded = false;

  Timer? _debounce;
  final String _platformCode = "PU4012";

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Elegant color palette
  static const Color primaryAccent = Color(0xFF6366F1);
  static const Color secondaryAccent = Color(0xFF8B5CF6);
  static const Color successAccent = Color(0xFF10B981);
  static const Color cardBg = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _hitApi();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _animController.dispose();
    super.dispose();
  }

  // ------------------ MAPPERS ------------------

  String _tabToApiType(LedgerTab t) {
    switch (t) {
      case LedgerTab.transaction:
        return "TRANSACTION";
      case LedgerTab.deposit:
        return "DEPOSIT";
      case LedgerTab.withdrawal:
        return "WITHDRAWAL";
    }
  }

  String _tabTitle(LedgerTab t) {
    switch (t) {
      case LedgerTab.transaction:
        return "Transaction";
      case LedgerTab.deposit:
        return "Deposits";
      case LedgerTab.withdrawal:
        return "Withdrawals";
    }
  }

  String? _statusToApi(String ui) {
    switch (ui) {
      case "All":
        return null;
      case "Pending":
        return "PENDING";
      case "Confirmed":
        return "CONFIRMED";
      case "Rejected":
        return "REJECTED";
      default:
        return null;
    }
  }

  // ------------------ DATE HELPERS ------------------

  String _isoStart(DateTime d) {
    final dt = DateTime(d.year, d.month, d.day, 0, 0, 0);
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
  }

  String _isoEnd(DateTime d) {
    final dt = DateTime(d.year, d.month, d.day, 23, 59, 59);
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(dt);
  }

  String _prettyDate(DateTime d) => DateFormat("dd MMM yyyy").format(d);

  // ------------------ FILTER CHANGE HANDLING ------------------

  void _resetToFirstPageAndDebounce() {
    setState(() {
      _page = 0;
    });
    _debouncedHit();
  }

  void _debouncedHit() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _hitApi);
  }

  // ------------------ DATE PICKERS ------------------

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: primaryAccent,
              surface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _startDate = picked;
      if (_startDate.isAfter(_endDate)) _endDate = _startDate;
    });

    _resetToFirstPageAndDebounce();
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: primaryAccent,
              surface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _endDate = picked;
      if (_endDate.isBefore(_startDate)) _startDate = _endDate;
    });

    _resetToFirstPageAndDebounce();
  }

  // ------------------ PREFS ------------------

  Future<String> _getWalletIdFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final gamerId = prefs.getString('gamer_id') ?? '';

    if (gamerId.trim().isEmpty) {
      throw Exception("gamer_id not found in SharedPreferences.");
    }

    return gamerId;
  }

  // ------------------ API ------------------

  Future<void> _hitApi() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final walletId = await _getWalletIdFromPrefs();

      final pageRes = await _service.fetchLedger(
        page: _page,
        size: _size,
        sortBy: "date",
        sortDir: "desc",
        walletIds: [walletId],
        platformCode: _platformCode,
        startDateIso: _isoStart(_startDate),
        endDateIso: _isoEnd(_endDate),
        type: _tabToApiType(_tab),
        status: _statusToApi(_statusUi),
      );

      setState(() {
        _pageMeta = pageRes;
        _items = pageRes.content;
        _isLoading = false;
      });

      _animController.forward(from: 0);
    } catch (e) {
      setState(() {
        _pageMeta = null;
        _error = e.toString();
        _items = [];
        _isLoading = false;
      });
    }
  }

  void _onPageChanged(int newPage) {
    if (_isLoading) return;

    final totalPages = _pageMeta?.totalPages ?? 1;
    if (newPage < 0 || newPage >= totalPages) return;

    setState(() => _page = newPage);
    _hitApi();
  }

  // ------------------ UI HELPERS ------------------

  Widget _tabPill({
    required String text,
    required bool selected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? const LinearGradient(
                  colors: [primaryAccent, secondaryAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white.withOpacity(0.08),
          border: Border.all(
            color: selected
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: primaryAccent.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? Colors.white : Colors.white.withOpacity(0.7),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: selected ? Colors.white : Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cardBg.withOpacity(0.6),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  // ------------------ BUILD ------------------

  @override
  Widget build(BuildContext context) {
    final totalElements = _pageMeta?.totalElements ?? 0;
    final totalPages = _pageMeta?.totalPages ?? 1;
    final pageNumber = _pageMeta?.number ?? _page;
    final pageSize = _pageMeta?.size ?? _size;
    final isFirst = _pageMeta?.first ?? (pageNumber == 0);
    final isLast = _pageMeta?.last ?? (pageNumber >= totalPages - 1);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Account Records',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              letterSpacing: -0.5,
              color: Colors.white.withOpacity(0.95),
            ),
          ),
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isLoading ? null : _hitApi,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [primaryAccent, secondaryAccent],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ledger Records',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.95),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "${_tabTitle(_tab)} • $_statusUi",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryAccent, secondaryAccent],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.article_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$totalElements",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _tabPill(
                        text: "Transaction",
                        icon: Icons.swap_horiz_rounded,
                        selected: _tab == LedgerTab.transaction,
                        onTap: () {
                          setState(() => _tab = LedgerTab.transaction);
                          _resetToFirstPageAndDebounce();
                        },
                      ),
                      _tabPill(
                        text: "Deposits",
                        icon: Icons.south_west_rounded,
                        selected: _tab == LedgerTab.deposit,
                        onTap: () {
                          setState(() => _tab = LedgerTab.deposit);
                          _resetToFirstPageAndDebounce();
                        },
                      ),
                      _tabPill(
                        text: "Withdrawals",
                        icon: Icons.north_east_rounded,
                        selected: _tab == LedgerTab.withdrawal,
                        onTap: () {
                          setState(() => _tab = LedgerTab.withdrawal);
                          _resetToFirstPageAndDebounce();
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Compact Filter Bar with Expand Button
                _filterCard(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _filtersExpanded = !_filtersExpanded;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: primaryAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: primaryAccent.withOpacity(0.9),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Filters",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: successAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: successAccent.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  _statusUi,
                                  style: TextStyle(
                                    color: successAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              AnimatedRotation(
                                turns: _filtersExpanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  color: Colors.white.withOpacity(0.6),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Expandable content
                      AnimatedCrossFade(
                        firstChild: const SizedBox.shrink(),
                        secondChild: Column(
                          children: [
                            const SizedBox(height: 16),
                            _dateBox(
                              label: "Start Date",
                              value: _prettyDate(_startDate),
                              icon: Icons.calendar_today_rounded,
                              onTap: _pickStart,
                            ),
                            const SizedBox(height: 12),
                            _dateBox(
                              label: "End Date",
                              value: _prettyDate(_endDate),
                              icon: Icons.event_rounded,
                              onTap: _pickEnd,
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Icon(
                                  Icons.filter_alt_rounded,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  "Status",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _statusUi,
                                      dropdownColor: const Color(0xFF0F172A),
                                      iconEnabledColor: Colors.white70,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                            value: "All", child: Text("All")),
                                        DropdownMenuItem(
                                            value: "Pending",
                                            child: Text("Pending")),
                                        DropdownMenuItem(
                                            value: "Confirmed",
                                            child: Text("Confirmed")),
                                        DropdownMenuItem(
                                            value: "Rejected",
                                            child: Text("Rejected")),
                                      ],
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() => _statusUi = v);
                                        _resetToFirstPageAndDebounce();
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        crossFadeState: _filtersExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: AccountRecordsTable(
                      items: _items,
                      isLoading: _isLoading,
                      error: _error,
                      onRetry: _hitApi,
                      totalElements: totalElements,
                      totalPages: totalPages,
                      pageNumber: pageNumber,
                      pageSize: pageSize,
                      isFirst: isFirst,
                      isLast: isLast,
                      onPageChanged: _onPageChanged,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateBox({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryAccent, secondaryAccent],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.6),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.95),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white.withOpacity(0.6),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}