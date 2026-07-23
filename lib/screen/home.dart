import 'package:commodi_flow/main.dart';
import 'package:commodi_flow/screen/analytics.dart';
import 'package:commodi_flow/screen/input.dart';
import 'package:commodi_flow/screen/profile.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool _isLoading = true;
  List<dynamic> _transactions = [];

  double _totalPemasukan = 0;
  double _totalPengeluaran = 0;
  double _labaBersih = 0;

  double _totalStok = 0;
  double _stokMasukBulanIni = 0;
  double _stokKeluarBulanIni = 0;

  final PageController _pageController = PageController();
  int _currentCardIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    super.dispose();
    _pageController.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });
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

      for (var item in transResponse) {
        final jenis = item['kategori_transaksi']['jenis'];
        final nominal = (item['nominal'] ?? 0).toDouble();

        if (jenis == 'Pemasukan') {
          pemasukan += nominal;
        } else {
          pengeluaran += nominal;
        }
      }

      final stokResponse = await supabase
          .from('pergerakan_stok')
          .select('*')
          .eq('user_id', userId);

      double totalMasukAllTime = 0;
      double totalKeluarAllTime = 0;
      double masukBulanIni = 0;
      double keluarBulanIni = 0;

      for (var item in stokResponse) {
        final jenis = item['jenis_pergerakan'];
        final qty = (item['jumlah_kg'] ?? 0).toDouble();
        final tgl = item['tanggal'];

        bool isThisMonth =
            (tgl.compareTo(firstDayOfMonth) >= 0 &&
            tgl.compareTo(lastDayOfMonth) <= 0);

        if (jenis == 'Masuk') {
          totalMasukAllTime += qty;
          if (isThisMonth) masukBulanIni += qty;
        } else {
          totalKeluarAllTime += qty;
          if (isThisMonth) keluarBulanIni += qty;
        }
      }

      if (mounted) {
        setState(() {
          _transactions = transResponse;
          _totalPemasukan = pemasukan;
          _totalPengeluaran = pengeluaran;
          _labaBersih = pemasukan - pengeluaran;

          _totalStok = totalMasukAllTime - totalKeluarAllTime;
          _stokMasukBulanIni = masukBulanIni;
          _stokKeluarBulanIni = keluarBulanIni;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
    if (withSign) {
      return isIncome ? '+ Rp $result' : '- Rp $result';
    }
    return amount < 0 ? '- Rp $result' : 'Rp $result';
  }

  String _formatTonase(double amount) {
    return '${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} Kg';
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
                subtitle: const Text('Isi form otomatis dari foto'),
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
                subtitle: const Text('Ketik data transaksi secara mandiri'),
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
    final user = Supabase.instance.client.auth.currentUser;
    final String profilePictureUrl = user?.userMetadata?['avatar_url'] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'CommodiFlow',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              backgroundImage: profilePictureUrl.isNotEmpty
                  ? NetworkImage(profilePictureUrl)
                  : null,
              child: profilePictureUrl.isNotEmpty
                  ? null
                  : const Icon(Icons.account_circle, color: Colors.grey),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
          ),
        ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 170,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentCardIndex = index;
                        });
                      },
                      children: [
                        _buildFinancialCard(context),
                        _buildStockCard(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildDotIndicator(0),
                      const SizedBox(width: 8),
                      _buildDotIndicator(1),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0),
                    child: Text(
                      'Transaksi Terakhir',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _transactions.isEmpty
                        ? Center(child: Text('Tidak ada transaksi bulan ini'))
                        : _buildRecentTransactions(),
                  ),
                ],
              ),
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
              icon: const Icon(Icons.home, color: Color(0xFF2E7D32)),
              onPressed: () {},
            ),
            const SizedBox(width: 48),
            IconButton(
              icon: const Icon(Icons.bar_chart, color: Colors.grey),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Laba Bersih (Bulan Ini)',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _formatRupiah(_labaBersih),
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIncomeExpenseInfo(
                  title: 'Pemasukan',
                  amount: _formatRupiah(_totalPemasukan),
                  icon: Icons.arrow_downward,
                  color: Colors.greenAccent,
                ),
                _buildIncomeExpenseInfo(
                  title: 'Pengeluaran',
                  amount: _formatRupiah(_totalPengeluaran),
                  icon: Icons.arrow_upward,
                  color: Colors.redAccent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF57F17), Color(0xFFFFB300)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sisa Stok Gudang (Total)',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              _formatTonase(_totalStok),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildIncomeExpenseInfo(
                  title: 'Masuk (Bln Ini)',
                  amount: _formatTonase(_stokMasukBulanIni),
                  icon: Icons.inventory_2_outlined,
                  color: Colors.white,
                ),
                _buildIncomeExpenseInfo(
                  title: 'Keluar (Bln Ini)',
                  amount: _formatTonase(_stokKeluarBulanIni),
                  icon: Icons.local_shipping_outlined,
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseInfo({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDotIndicator(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 8,
      width: _currentCardIndex == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentCardIndex == index
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildRecentTransactions() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _transactions.length,
      separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
      itemBuilder: (context, index) {
        final trxt = _transactions[index];
        final kategoriData = trxt['kategori_transaksi'] ?? {};

        final isIncome = kategoriData['jenis'] == 'Pemasukan';

        final title = kategoriData['nama_kategori'] ?? 'Transaksi';

        final dateStr = _formatDate(trxt['tanggal']);

        final amount = (trxt['nominal'] ?? 0).toDouble();
        final amountStr = _formatRupiah(
          amount,
          withSign: true,
          isIncome: isIncome,
        );

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundColor: isIncome ? Colors.green[50] : Colors.red[50],
            child: Icon(
              isIncome ? Icons.account_balance_wallet : Icons.receipt_long,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            dateStr,
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          trailing: Text(
            amountStr,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIncome ? Colors.green : Colors.red,
            ),
          ),
        );
      },
    );
  }
}
