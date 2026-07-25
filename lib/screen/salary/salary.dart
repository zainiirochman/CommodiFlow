import 'package:commodi_flow/screen/salary/input.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SalaryPage extends StatefulWidget {
  const SalaryPage({super.key});

  @override
  State<SalaryPage> createState() => _SalaryPageState();
}

class _SalaryPageState extends State<SalaryPage> {
  bool _isLoading = true;

  List<dynamic> _allSalaryData = [];
  List<dynamic> _filteredSalaryData = [];
  List<dynamic> _karyawanList = [];

  DateTime? _startDate;
  DateTime? _endDate;
  String _filterDateLabel = 'Semua Waktu';
  String? _selectedKaryawanId;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final responseGaji = await Supabase.instance.client
          .from('riwayat_gaji')
          .select('''
            *,
            karyawan (id, nama, peran),
            tarif_tujuan (nama_tujuan)
          ''')
          .eq('user_id', userId)
          .order('tanggal', ascending: false)
          .order('created_at', ascending: false);

      final responseKaryawan = await Supabase.instance.client
          .from('karyawan')
          .select('id, nama, peran')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _allSalaryData = responseGaji;
          _karyawanList = responseKaryawan;
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
    var temp = _allSalaryData;

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

      temp = temp.where((item) {
        try {
          final date = DateTime.parse(item['tanggal']);
          return date.isAfter(start.subtract(const Duration(seconds: 1))) &&
              date.isBefore(end.add(const Duration(seconds: 1)));
        } catch (_) {
          return false;
        }
      }).toList();
    }

    if (_selectedKaryawanId != null) {
      temp = temp
          .where((item) => item['karyawan_id'] == _selectedKaryawanId)
          .toList();
    }

    setState(() {
      _filteredSalaryData = temp;
    });
  }

  int _calculateTotalFiltered() {
    int total = 0;
    for (var item in _filteredSalaryData) {
      total += (item['total_gaji'] as int? ?? 0);
    }
    return total;
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Riwayat Gaji',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Pilih Karyawan',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedKaryawanId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    hint: const Text('Semua Karyawan'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Semua Karyawan'),
                      ),
                      ..._karyawanList.map(
                        (k) => DropdownMenuItem<String>(
                          value: k['id'],
                          child: Text('${k['nama']} (${k['peran']})'),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() => _selectedKaryawanId = val);
                    },
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Rentang Tanggal',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Semua Waktu'),
                        backgroundColor: _startDate == null
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        onPressed: () => setModalState(() {
                          _startDate = null;
                          _endDate = null;
                          _filterDateLabel = 'Semua Waktu';
                        }),
                      ),
                      ActionChip(
                        label: const Text('Bulan Ini'),
                        backgroundColor: _filterDateLabel == 'Bulan Ini'
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        onPressed: () => setModalState(() {
                          final now = DateTime.now();
                          _startDate = DateTime(now.year, now.month, 1);
                          _endDate = DateTime(now.year, now.month + 1, 0);
                          _filterDateLabel = 'Bulan Ini';
                        }),
                      ),
                      ActionChip(
                        label: const Text('Pilih Rentang...'),
                        backgroundColor: _filterDateLabel.contains('-')
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setModalState(() {
                              _startDate = picked.start;
                              _endDate = picked.end;
                              _filterDateLabel =
                                  '${picked.start.day}/${picked.start.month} - ${picked.end.day}/${picked.end.month}';
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        _applyFilters();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Terapkan Filter'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatRupiah(int amount) {
    return 'Rp ' +
        amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
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
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InputPage()),
          );
          if (result == true) {
            _fetchData();
          }
        },
        shape: const CircleBorder(),
        backgroundColor: Colors.green,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Laporan Gaji',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFF2E7D32)),
            tooltip: 'Filter Data',
            onPressed: _showFilterModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedKaryawanId == null
                                  ? 'Total Keseluruhan'
                                  : 'Total Gaji Karyawan',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatRupiah(_calculateTotalFiltered()),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Periode: $_filterDateLabel',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white54,
                          size: 40,
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _filteredSalaryData.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredSalaryData.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final data = _filteredSalaryData[index];

                            final karyawan = data['karyawan'] ?? {};
                            final namaKaryawan =
                                karyawan['nama'] ?? 'Karyawan Dihapus';
                            final peran =
                                karyawan['peran'] ?? 'Tidak diketahui';

                            final totalGaji = data['total_gaji'] as int;
                            final tanggal = _formatDate(data['tanggal']);

                            final isSopir = peran == 'Sopir';
                            final icon = isSopir
                                ? Icons.local_shipping
                                : Icons.fitness_center;
                            final iconColor = isSopir
                                ? Colors.blue
                                : Colors.orange;

                            String rincian = '';
                            if (isSopir) {
                              final tujuan = data['tarif_tujuan'];
                              rincian =
                                  'Rute: ${tujuan != null ? tujuan['nama_tujuan'] : '?'}';
                            } else {
                              final kg = data['jumlah_kg'] ?? 0;
                              final tarif = data['tarif_per_kg'] ?? 0;
                              rincian = '$kg Kg × ${_formatRupiah(tarif)}';
                            }

                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: iconColor.withOpacity(
                                        0.1,
                                      ),
                                      radius: 24,
                                      child: Icon(
                                        icon,
                                        color: iconColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            namaKaryawan,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            rincian,
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            tanggal,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatRupiah(totalGaji),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Tidak ada riwayat gaji pada filter ini.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
