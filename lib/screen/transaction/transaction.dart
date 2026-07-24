import 'package:commodi_flow/screen/transaction/edit.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TransactionPage extends StatefulWidget {
  const TransactionPage({super.key});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  bool _isLoading = true;

  List<dynamic> _allTransactions = [];
  List<dynamic> _allStocks = [];

  List<dynamic> _filteredTransactions = [];
  List<dynamic> _filteredStocks = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  DateTime? _startDate;
  DateTime? _endDate;
  String _filterLabel = 'Semua Waktu';

  @override
  void initState() {
    super.initState();
    _fetchData();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final transResponse = await Supabase.instance.client
          .from('transaksi')
          .select('*, kategori_transaksi(nama_kategori, jenis)')
          .eq('user_id', userId)
          .order('tanggal', ascending: false)
          .order('created_at', ascending: false);

      final stokResponse = await Supabase.instance.client
          .from('pergerakan_stok')
          .select('*')
          .eq('user_id', userId)
          .order('tanggal', ascending: false)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allTransactions = transResponse;
          _allStocks = stokResponse;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applyFilters() {
    var tempTrans = _allTransactions;
    var tempStocks = _allStocks;

    if (_startDate != null && _endDate != null) {
      final start = DateTime(
        _startDate!.year,
        _startDate!.month,
        _startDate!.day,
      );
      final end = DateTime(
        _endDate!.year,
        _endDate!.month,
        _endDate!.day,
        23,
        59,
        59,
      );

      tempTrans = tempTrans.where((item) {
        final date = DateTime.parse(item['tanggal']);
        return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();

      tempStocks = tempStocks.where((item) {
        final date = DateTime.parse(item['tanggal']);
        return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
            date.isBefore(end.add(const Duration(seconds: 1)));
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      tempTrans = tempTrans.where((item) {
        final kategori = (item['kategori_transaksi']['nama_kategori'] ?? '')
            .toLowerCase();
        final keterangan = (item['keterangan'] ?? '').toLowerCase();
        return kategori.contains(_searchQuery) ||
            keterangan.contains(_searchQuery);
      }).toList();

      tempStocks = tempStocks.where((item) {
        final keterangan = (item['keterangan'] ?? '').toLowerCase();
        final jenis = (item['jenis_pergerakan'] ?? '').toLowerCase();
        return keterangan.contains(_searchQuery) ||
            jenis.contains(_searchQuery);
      }).toList();
    }

    _filteredTransactions = tempTrans;
    _filteredStocks = tempStocks;
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter Tanggal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              _buildFilterOption('Semua Waktu', () {
                _setFilterDate(null, null, 'Semua Waktu');
                Navigator.pop(context);
              }),
              _buildFilterOption('Hari Ini', () {
                final now = DateTime.now();
                _setFilterDate(now, now, 'Hari Ini');
                Navigator.pop(context);
              }),
              _buildFilterOption('Bulan Ini', () {
                final now = DateTime.now();
                final start = DateTime(now.year, now.month, 1);
                final end = DateTime(now.year, now.month + 1, 0);
                _setFilterDate(start, end, 'Bulan Ini');
                Navigator.pop(context);
              }),
              _buildFilterOption('Tahun Ini', () {
                final now = DateTime.now();
                final start = DateTime(now.year, 1, 1);
                final end = DateTime(now.year, 12, 31);
                _setFilterDate(start, end, 'Tahun Ini');
                Navigator.pop(context);
              }),
              _buildFilterOption('Pilih Rentang Tanggal...', () async {
                Navigator.pop(context);
                _selectCustomDateRange();
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String title, VoidCallback onTap) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _setFilterDate(DateTime? start, DateTime? end, String label) {
    setState(() {
      _startDate = start;
      _endDate = end;
      _filterLabel = label;
      _applyFilters();
    });
  }

  Future<void> _selectCustomDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D32),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final startStr =
          '${picked.start.day}/${picked.start.month}/${picked.start.year}';
      final endStr = '${picked.end.day}/${picked.end.month}/${picked.end.year}';
      _setFilterDate(picked.start, picked.end, '$startStr - $endStr');
    }
  }

  Future<void> _deleteData(String id, String tableName) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Data?'),
            content: const Text(
              'Data yang dihapus tidak dapat dikembalikan. Lanjutkan?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await Supabase.instance.client.from(tableName).delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil dihapus!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- HELPER FORMATTER ---
  String _formatRupiah(
    double amount, {
    bool withSign = false,
    bool isIncome = true,
  }) {
    String result = amount
        .abs()
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
    if (withSign) return isIncome ? '+ Rp $result' : '- Rp $result';
    return amount < 0 ? '- Rp $result' : 'Rp $result';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text(
            'Semua Transaksi',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(140),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      // Search Bar
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Cari transaksi...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.grey,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      FocusScope.of(context).unfocus();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Filter Button
                      InkWell(
                        onTap: _showFilterModal,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _startDate != null
                                ? const Color(0xFF2E7D32)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.filter_list,
                            color: _startDate != null
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Indikator Filter Aktif
                if (_startDate != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 8.0,
                      left: 16,
                      right: 16,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Filter: ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        Chip(
                          label: Text(
                            _filterLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: Colors.orange.shade400,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          deleteIcon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                          onDeleted: () =>
                              _setFilterDate(null, null, 'Semua Waktu'),
                        ),
                      ],
                    ),
                  ),

                // Tab Bar
                const TabBar(
                  labelColor: Color(0xFF2E7D32),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Color(0xFF2E7D32),
                  indicatorWeight: 3,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.account_balance_wallet),
                      text: 'Keuangan',
                    ),
                    Tab(icon: Icon(Icons.inventory_2), text: 'Stok Gudang'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_buildFinancialList(), _buildStockList()]),
      ),
    );
  }

  Widget _buildFinancialList() {
    if (_filteredTransactions.isEmpty) {
      return _buildEmptyState('Tidak ada transaksi keuangan ditemukan.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _filteredTransactions.length,
      separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
      itemBuilder: (context, index) {
        final trxt = _filteredTransactions[index];
        final id = trxt['id'];
        final kategoriData = trxt['kategori_transaksi'] ?? {};
        final isIncome = kategoriData['jenis'] == 'Pemasukan';
        final title = kategoriData['nama_kategori'] ?? 'Transaksi';
        final subtitle = trxt['keterangan'] ?? '';
        final dateStr = _formatDate(trxt['tanggal']);
        final amount = (trxt['nominal'] ?? 0).toDouble();
        final amountStr = _formatRupiah(
          amount,
          withSign: true,
          isIncome: isIncome,
        );

        return _buildListItem(
          isIncome: isIncome,
          icon: isIncome ? Icons.account_balance_wallet : Icons.receipt_long,
          iconColor: isIncome ? Colors.green : Colors.red,
          title: title,
          subtitle: '$dateStr ${subtitle.isNotEmpty ? " • $subtitle" : ""}',
          trailingText: amountStr,
          trailingColor: isIncome ? Colors.green : Colors.red,
          onEdit: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    EditPage(itemData: trxt, tableName: 'transaksi'),
              ),
            );
            if (result == true) {
              await _fetchData();
              setState(() {});
            }
          },
          onDelete: () => _deleteData(id, 'transaksi'),
        );
      },
    );
  }

  Widget _buildStockList() {
    if (_filteredStocks.isEmpty) {
      return _buildEmptyState('Tidak ada riwayat pergerakan stok ditemukan.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: _filteredStocks.length,
      separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
      itemBuilder: (context, index) {
        final stok = _filteredStocks[index];
        final id = stok['id'];
        final jenis = stok['jenis_pergerakan'];
        final isMasuk = jenis == 'Masuk';
        final keterangan = stok['keterangan'] ?? '';
        final dateStr = _formatDate(stok['tanggal']);

        final qty = (stok['jumlah_kg'] ?? 0).toDouble();
        final qtyStr = isMasuk ? '+ $qty Kg' : '- $qty Kg';

        Color iconColor = Colors.orange;
        IconData iconData = Icons.swap_horiz;
        if (jenis == 'Masuk') {
          iconColor = Colors.blue;
          iconData = Icons.input;
        } else if (jenis == 'Keluar') {
          iconColor = Colors.orange;
          iconData = Icons.output;
        } else {
          iconColor = Colors.grey;
          iconData = Icons.trending_down;
        }

        return _buildListItem(
          isIncome: isMasuk,
          icon: iconData,
          iconColor: iconColor,
          title: 'Stok $jenis',
          subtitle: '$dateStr ${keterangan.isNotEmpty ? " • $keterangan" : ""}',
          trailingText: qtyStr,
          trailingColor: iconColor,
          onEdit: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    EditPage(itemData: stok, tableName: 'pergerakan_stok'),
              ),
            );
            if (result == true) {
              await _fetchData();
              setState(() {});
            }
          },
          onDelete: () => _deleteData(id, 'pergerakan_stok'),
        );
      },
    );
  }

  Widget _buildListItem({
    required bool isIncome,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String trailingText,
    required Color trailingColor,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            trailingText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: trailingColor,
              fontSize: 14,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET HELPER EMPTY STATE ---
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
