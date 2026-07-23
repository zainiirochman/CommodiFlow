// ignore_for_file: unused_local_variable, unused_field

import 'package:commodi_flow/main.dart';
import 'package:commodi_flow/screen/home.dart';
import 'package:commodi_flow/screen/input.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  bool _isLoading = true;
  double _totalPengeluaran = 0;

  List<double> _weeklyIncome = [0, 0, 0, 0];
  List<double> _weeklyExpense = [0, 0, 0, 0];
  double _maxWeeklyAmount = 0;

  List<MapEntry<String, double>> _expenseCategories = [];

  List<double> _weeklyStock = [0, 0, 0, 0];
  double _maxWeeklyStock = 0;

  final List<Color> _pieColors = [
    Colors.red.shade400,
    Colors.orange,
    Colors.blue,
    Colors.teal,
    Colors.purple,
    Colors.grey,
  ];
  String _selectedFilter = 'Bulan Ini';
  final List<String> _filterOptions = [
    'Bulan Ini',
  ]; // Disederhanakan dulu untuk fokus pada bulan aktif

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(
        now.year,
        now.month,
        1,
      ).toIso8601String();
      final lastDayOfMonth = DateTime(
        now.year,
        now.month + 1,
        0,
        23,
        59,
        59,
      ).toIso8601String();

      final transResponse = await supabase
          .from('transaksi')
          .select('*, kategori_transaksi(nama_kategori, jenis)')
          .eq('user_id', userId)
          .gte('tanggal', firstDayOfMonth)
          .lte('tanggal', lastDayOfMonth)
          .order('tanggal', ascending: false);

      double pemasukan = 0;
      double pengeluaran = 0;

      List<double> tempIncome = [0, 0, 0, 0];
      List<double> tempExpense = [0, 0, 0, 0];
      double tempMaxAmount = 0;
      Map<String, double> tempExpenseCat = {};

      for (var item in transResponse) {
        final jenis = item['kategori_transaksi']['jenis'];
        final nominal = (item['nominal'] ?? 0).toDouble();
        final tanggal = DateTime.parse(item['tanggal']);

        int weekIndex = (tanggal.day - 1) ~/ 7;
        if (weekIndex > 3) weekIndex = 3;

        if (jenis == 'Pemasukan') {
          pemasukan += nominal;
          tempIncome[weekIndex] += nominal;
          if (tempIncome[weekIndex] > tempMaxAmount)
            tempMaxAmount = tempIncome[weekIndex];
        } else {
          pengeluaran += nominal;
          tempExpense[weekIndex] += nominal;
          if (tempExpense[weekIndex] > tempMaxAmount)
            tempMaxAmount = tempExpense[weekIndex];

          String catName =
              item['kategori_transaksi']['nama_kategori'] ?? 'Lain-lain';
          tempExpenseCat[catName] = (tempExpenseCat[catName] ?? 0) + nominal;
        }
      }

      var sortedCategories = tempExpenseCat.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final stokResponse = await supabase
          .from('pergerakan_stok')
          .select('*')
          .eq('user_id', userId);

      double totalMasukAllTime = 0;
      double totalKeluarAllTime = 0;
      double masukBulanIni = 0;
      double keluarBulanIni = 0;

      List<double> tempWeeklyStockMove = [0, 0, 0, 0];
      String currentMonthPrefix = firstDayOfMonth.substring(0, 7);

      for (var item in stokResponse) {
        final jenis = item['jenis_pergerakan'];
        final qty = (item['jumlah_kg'] ?? 0).toDouble();
        final tgl = item['tanggal'];

        bool isThisMonth =
            (tgl.compareTo(firstDayOfMonth) >= 0 &&
            tgl.compareTo(lastDayOfMonth) <= 0);

        if (jenis == 'Masuk') {
          totalMasukAllTime += qty;
          if (isThisMonth) {
            masukBulanIni += qty;
            int weekIdx = (DateTime.parse(tgl).day - 1) ~/ 7;
            if (weekIdx > 3) weekIdx = 3;
            tempWeeklyStockMove[weekIdx] += qty;
          }
        } else {
          totalKeluarAllTime += qty;
          if (isThisMonth) {
            keluarBulanIni += qty;
            int weekIdx = (DateTime.parse(tgl).day - 1) ~/ 7;
            if (weekIdx > 3) weekIdx = 3;
            tempWeeklyStockMove[weekIdx] -= qty;
          }
        }
      }

      // Hitung pergerakan stok mingguan berdasarkan stok awal bulan
      double startOfMonthStock =
          (totalMasukAllTime - totalKeluarAllTime) -
          (masukBulanIni - keluarBulanIni);
      List<double> tempWeeklyStock = [0, 0, 0, 0];
      double currentStock = startOfMonthStock;
      double maxStok = currentStock;

      for (int i = 0; i < 4; i++) {
        currentStock += tempWeeklyStockMove[i];
        tempWeeklyStock[i] = currentStock;
        if (currentStock > maxStok) maxStok = currentStock;
      }

      if (mounted) {
        setState(() {
          _totalPengeluaran = pengeluaran;

          _weeklyIncome = tempIncome;
          _weeklyExpense = tempExpense;
          _maxWeeklyAmount = tempMaxAmount;
          _expenseCategories = sortedCategories;
          _weeklyStock = tempWeeklyStock;
          _maxWeeklyStock = maxStok;

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

  Future<void> _openCamera() async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => Input(imagePath: photo.path)),
      );
      _fetchData();
    }
  }

  void _showInputOptions() {
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
                'Pilih Metode Input',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: const Icon(
                    Icons.document_scanner,
                    color: Colors.green,
                  ),
                ),
                title: const Text('Pindai Nota'),
                onTap: () {
                  Navigator.pop(context);
                  _openCamera();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade50,
                  child: const Icon(Icons.edit_note, color: Colors.orange),
                ),
                title: const Text('Input Manual'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const Input(imagePath: ''),
                    ),
                  );
                  _fetchData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Statistik & Laporan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        backgroundColor: Colors.grey[50],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showInputOptions,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.document_scanner, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home, color: Colors.grey),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Home()),
              ),
            ),
            const SizedBox(width: 48),
            IconButton(
              icon: const Icon(Icons.bar_chart, color: Color(0xFF2E7D32)),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: Lottie.asset(
                'assets/lottie/Loading.json',
                height: 250,
                width: 250,
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ringkasan Keuangan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFilter,
                              icon: const Icon(
                                Icons.keyboard_arrow_down,
                                size: 20,
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                              items: _filterOptions
                                  .map(
                                    (String value) => DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (newValue) {},
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- 1. CHART ARUS KAS (BAR CHART) ---
                    _buildChartCard(
                      title: 'Arus Kas (Masuk vs Keluar)',
                      subtitle: 'Perbandingan mingguan dalam bulan ini',
                      child: SizedBox(
                        height: 200,
                        child: BarChart(_buildBarChartData()),
                      ),
                      legend: _buildBarChartLegend(),
                    ),
                    const SizedBox(height: 16),

                    // --- 2. CHART PROPORSI PENGELUARAN (PIE CHART) ---
                    _buildChartCard(
                      title: 'Proporsi Pengeluaran',
                      subtitle: 'Distribusi biaya terbesar bulan ini',
                      child: SizedBox(
                        height: 200,
                        child: _expenseCategories.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada pengeluaran',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: PieChart(_buildPieChartData()),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: _buildPieChartLegend(),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildChartCard(
                      title: 'Pergerakan Stok Gudang',
                      subtitle: 'Tren sisa tonase (Kg) mingguan',
                      child: SizedBox(
                        height: 200,
                        child: LineChart(_buildLineChartData()),
                      ),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 24,
                        ),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        elevation: 1,
                      ),
                      onPressed: () {},
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download, size: 20),
                          const SizedBox(width: 8),
                          Text('Unduh Dalam Bentuk Excel'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? legend,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
          const SizedBox(height: 24),
          child,
          if (legend != null) ...[const SizedBox(height: 16), legend],
        ],
      ),
    );
  }

  BarChartData _buildBarChartData() {
    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: _maxWeeklyAmount == 0 ? 100 : _maxWeeklyAmount * 1.2,
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            String value = '${(rod.toY / 1000000).toStringAsFixed(1)} Jt';
            return BarTooltipItem(
              value,
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            );
          },
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              const titles = ['Mg 1', 'Mg 2', 'Mg 3', 'Mg 4'];
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  titles[value.toInt()],
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      gridData: FlGridData(show: false),
      borderData: FlBorderData(show: false),
      barGroups: [
        _makeBarGroup(0, _weeklyIncome[0], _weeklyExpense[0]),
        _makeBarGroup(1, _weeklyIncome[1], _weeklyExpense[1]),
        _makeBarGroup(2, _weeklyIncome[2], _weeklyExpense[2]),
        _makeBarGroup(3, _weeklyIncome[3], _weeklyExpense[3]),
      ],
    );
  }

  BarChartGroupData _makeBarGroup(int x, double income, double expense) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: income,
          color: Colors.green,
          width: 12,
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: expense,
          color: Colors.red,
          width: 12,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildBarChartLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(Colors.green, 'Pemasukan'),
        const SizedBox(width: 24),
        _legendItem(Colors.red, 'Pengeluaran'),
      ],
    );
  }

  PieChartData _buildPieChartData() {
    List<PieChartSectionData> sections = [];

    for (int i = 0; i < _expenseCategories.length; i++) {
      if (i > 4) break;

      double percentage =
          (_expenseCategories[i].value / _totalPengeluaran) * 100;

      sections.add(
        PieChartSectionData(
          color: _pieColors[i % _pieColors.length],
          value: percentage,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      );
    }

    return PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 30,
      sections: sections,
    );
  }

  Widget _buildPieChartLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _expenseCategories.length > 5 ? 5 : _expenseCategories.length,
        (i) {
          String name = _expenseCategories[i].key;
          if (name.length > 12) name = '${name.substring(0, 12)}...';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: _legendItem(_pieColors[i % _pieColors.length], name),
          );
        },
      ),
    );
  }

  LineChartData _buildLineChartData() {
    double minStok = 0;
    double maxStok = 100;
    if (_weeklyStock.isNotEmpty) {
      minStok = _weeklyStock.reduce((a, b) => a < b ? a : b);
      maxStok = _weeklyStock.reduce((a, b) => a > b ? a : b);
    }

    double range = maxStok - minStok;
    if (range == 0) range = 10;

    return LineChartData(
      gridData: FlGridData(show: false),
      clipData: const FlClipData.all(),
      maxY: maxStok + (range * 0.2),
      minY: minStok - (range * 0.2),
      titlesData: FlTitlesData(
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              const titles = ['Mg1', 'Mg2', 'Mg3', 'Mg4'];
              if (value.toInt() >= 0 && value.toInt() < titles.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    titles[value.toInt()],
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                );
              }
              return const Text('');
            },
          ),
        ),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          isCurved: true,
          color: Colors.orange,
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.orange.withOpacity(0.2),
          ),
          spots: [
            FlSpot(0, _weeklyStock[0]),
            FlSpot(1, _weeklyStock[1]),
            FlSpot(2, _weeklyStock[2]),
            FlSpot(3, _weeklyStock[3]),
          ],
        ),
      ],
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }
}
