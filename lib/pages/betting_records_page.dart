// lib/pages/betting_records_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../components/bettingrecords/betting_records_table.dart';
import '../services/betting_records_service.dart';

class BettingRecordsPage extends StatefulWidget {
  const BettingRecordsPage({super.key});

  @override
  State<BettingRecordsPage> createState() => _BettingRecordsPageState();
}

class _BettingRecordsPageState extends State<BettingRecordsPage>
    with SingleTickerProviderStateMixin {
  final BettingRecordsService _service = BettingRecordsService();

  String? _walletId;
  String? _platformCode;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  // Filters
  List<String> _categories = ['ALL'];
  List<GameInfo> _games = [];
  String _selectedCategory = 'ALL';
  String _selectedGameCode = 'ALL';

  // Table data
  List<BetRecord> _records = [];
  int _totalElements = 0;
  int _pageSize = 10;
  int _currentPage = 0;

  bool _isLoadingFilters = false;
  bool _isLoadingTable = false;
  String? _errorMessage;

  // Filter expansion state
  bool _filtersExpanded = false;

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
    _initDates();
    _initData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _initDates() {
    final now = DateTime.now();
    _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final DateTime thirtyDaysBefore =
        _endDate.subtract(const Duration(days: 30));
    _startDate = DateTime(
      thirtyDaysBefore.year,
      thirtyDaysBefore.month,
      thirtyDaysBefore.day,
      0,
      0,
      0,
    );
  }

  Future<void> _initData() async {
    setState(() {
      _isLoadingFilters = true;
      _isLoadingTable = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final walletId = prefs.getString('gamer_id');

      if (walletId == null || walletId.isEmpty) {
        setState(() {
          _errorMessage =
              'Gamer ID (walletId) not found in SharedPreferences.\nPlease ensure it is saved as "gamer_id".';
          _isLoadingFilters = false;
          _isLoadingTable = false;
        });
        return;
      }

      _walletId = walletId;

      final vendorResp = await _service.fetchGameVendorDetails(
        walletId: walletId,
      );

      _platformCode = vendorResp.platformCode ?? 'PU4012';

      final Map<String, GameInfo> unique = {};
      for (final g in vendorResp.games) {
        final key = '${g.gameCode}-${g.gameName}';
        if (!unique.containsKey(key)) {
          unique[key] = g;
        }
      }
      _games = unique.values.toList()
        ..sort((a, b) => a.gameName.compareTo(b.gameName));

      _categories = ['ALL', ...vendorResp.categories];

      _selectedCategory = 'ALL';
      _selectedGameCode = 'ALL';

      setState(() {
        _isLoadingFilters = false;
      });

      await _loadBetRecords(page: 0);
      _animController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load betting records.\nError: $e';
        _isLoadingFilters = false;
        _isLoadingTable = false;
      });
    }
  }

  Future<void> _loadBetRecords({required int page}) async {
    if (_walletId == null || _platformCode == null) return;

    setState(() {
      _isLoadingTable = true;
      _errorMessage = null;
      _currentPage = page;
    });

    try {
      final resp = await _service.fetchBetRecords(
        walletId: _walletId!,
        platformCode: _platformCode!,
        startDate: _startDate,
        endDate: _endDate,
        customizedCategory: _selectedCategory,
        gameCodeOrAll: _selectedGameCode,
        page: page,
        size: _pageSize,
      );

      setState(() {
        _records = resp.records;
        _totalElements = resp.totalElements;
        _pageSize = resp.pageSize;
        _currentPage = resp.pageNumber;
        _isLoadingTable = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load betting records.\nError: $e';
        _isLoadingTable = false;
      });
    }
  }

  String _formatDateForDisplay(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: primaryAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.year, picked.month, picked.day, 0, 0, 0);
      });
      await _loadBetRecords(page: 0);
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: successAccent,
              onPrimary: Colors.white,
              surface: Color(0xFF0F172A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _endDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
      await _loadBetRecords(page: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool loading = _isLoadingFilters || _isLoadingTable;

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
            'Betting Records',
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
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
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
                          Icons.casino_rounded,
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
                              'Bet History',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white.withOpacity(0.95),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'View your betting records',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (loading)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [primaryAccent, secondaryAccent],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        )
                      else
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
                                Icons.receipt_long_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$_totalElements",
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

                // Collapsible Filter Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: cardBg.withOpacity(0.6),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
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
                                  _selectedCategory == 'ALL' 
                                      ? 'All Categories' 
                                      : _selectedCategory,
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
                            _DateField(
                              label: 'Start Date',
                              value: _formatDateForDisplay(_startDate),
                              icon: Icons.calendar_today_rounded,
                              onTap: _pickStartDate,
                            ),
                            const SizedBox(height: 12),
                            _DateField(
                              label: 'End Date',
                              value: _formatDateForDisplay(_endDate),
                              icon: Icons.event_rounded,
                              onTap: _pickEndDate,
                            ),
                            const SizedBox(height: 12),
                            _buildCategoryDropdown(),
                            const SizedBox(height: 12),
                            _buildGameDropdown(),
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

                // Table Section
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: BettingRecordsTable(
                      records: _records,
                      isLoading: loading,
                      currentPage: _currentPage,
                      pageSize: _pageSize,
                      totalElements: _totalElements,
                      errorMessage: _errorMessage,
                      onPageChanged: (page) {
                        _loadBetRecords(page: page);
                      },
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

  Widget _buildCategoryDropdown() {
    return IgnorePointer(
      ignoring: _isLoadingFilters,
      child: Opacity(
        opacity: _isLoadingFilters ? 0.65 : 1,
        child: DropdownButtonFormField<String>(
          value: _selectedCategory,
          isExpanded: true,
          menuMaxHeight: 320,
          dropdownColor: const Color(0xFF0F172A),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.7),
          ),
          decoration: InputDecoration(
            labelText: 'Category',
            labelStyle: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: primaryAccent, width: 2),
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w600,
          ),
          items: _categories.map((cat) {
            final label = cat == 'ALL' ? 'All Categories' : cat;
            return DropdownMenuItem<String>(
              value: cat,
              child: Text(label, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedCategory = value);
            _loadBetRecords(page: 0);
          },
        ),
      ),
    );
  }

  Widget _buildGameDropdown() {
    return IgnorePointer(
      ignoring: _isLoadingFilters,
      child: Opacity(
        opacity: _isLoadingFilters ? 0.65 : 1,
        child: DropdownButtonFormField<String>(
          value: _selectedGameCode,
          isExpanded: true,
          menuMaxHeight: 400,
          dropdownColor: const Color(0xFF0F172A),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.7),
          ),
          decoration: InputDecoration(
            labelText: 'Game',
            labelStyle: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: secondaryAccent, width: 2),
            ),
          ),
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.95),
            fontWeight: FontWeight.w600,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: 'ALL',
              child: Text('All Games'),
            ),
            ..._games.map((game) {
              return DropdownMenuItem<String>(
                value: game.gameCode,
                child: Text(
                  game.gameName,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _selectedGameCode = value);
            _loadBetRecords(page: 0);
          },
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                    colors: [
                      Color(0xFF6366F1),
                      Color(0xFF8B5CF6),
                    ],
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