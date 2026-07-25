import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<dynamic> _karyawanList = [];
  List<dynamic> _tujuanList = [];

  String? _selectedKaryawanId;
  String? _selectedRole;
  String? _selectedTujuanId;

  final TextEditingController _tanggalCtrl = TextEditingController();
  final TextEditingController _kgCtrl = TextEditingController();
  final TextEditingController _tarifKgCtrl = TextEditingController();
  final TextEditingController _keteranganCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _tanggalCtrl.text =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _fetchDataMaster();
  }

  Future<void> _fetchDataMaster() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final resKaryawan = await Supabase.instance.client
          .from('karyawan')
          .select('*')
          .eq('user_id', userId)
          .eq('status_aktif', true);

      final resTujuan = await Supabase.instance.client
          .from('tarif_tujuan')
          .select('*')
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          _karyawanList = resKaryawan;
          _tujuanList = resTujuan;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveSalary() async {
    if (_selectedKaryawanId == null) {
      _showError('Pilih karyawan terlebih dahulu!');
      return;
    }

    if (_selectedRole == 'Sopir' && _selectedTujuanId == null) {
      _showError('Pilih tujuan pengiriman untuk sopir!');
      return;
    }

    if (_selectedRole == 'Bongkar Muat' &&
        (_kgCtrl.text.isEmpty || _tarifKgCtrl.text.isEmpty)) {
      _showError('Isi jumlah Kg dan Tarif per Kg!');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      int totalGaji = 0;
      double? jumlahKg;
      int? tarifPerKg;
      String detailKeterangan = _keteranganCtrl.text;

      if (_selectedRole == 'Sopir') {
        final tujuan = _tujuanList.firstWhere(
          (t) => t['id'] == _selectedTujuanId,
        );
        totalGaji = tujuan['ongkos'] as int;
        if (detailKeterangan.isEmpty)
          detailKeterangan = 'Gaji Sopir rute: ${tujuan['nama_tujuan']}';
      } else {
        jumlahKg = double.parse(_kgCtrl.text.replaceAll(',', '.'));
        tarifPerKg = int.parse(
          _tarifKgCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        );
        totalGaji = (jumlahKg * tarifPerKg).toInt();
        if (detailKeterangan.isEmpty)
          detailKeterangan = 'Gaji Bongkar Muat ($jumlahKg Kg)';
      }

      final dateParts = _tanggalCtrl.text.split('/');
      final formattedDate = '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';

      var category = await Supabase.instance.client
          .from('kategori_transaksi')
          .select('id')
          .eq('user_id', userId)
          .eq('nama_kategori', 'Gaji Karyawan')
          .maybeSingle();

      String categoryId;
      if (category == null) {
        final newCat = await Supabase.instance.client
            .from('kategori_transaksi')
            .insert({
              'user_id': userId,
              'nama_kategori': 'Gaji Karyawan',
              'jenis': 'Pengeluaran',
            })
            .select('id')
            .single();
        categoryId = newCat['id'];
      } else {
        categoryId = category['id'];
      }

      final newTransaksi = await Supabase.instance.client
          .from('transaksi')
          .insert({
            'user_id': userId,
            'kategori_id': categoryId,
            'nominal': totalGaji,
            'tanggal': formattedDate,
            'keterangan': detailKeterangan,
          })
          .select('id')
          .single();

      await Supabase.instance.client.from('riwayat_gaji').insert({
        'user_id': userId,
        'karyawan_id': _selectedKaryawanId,
        'tanggal': formattedDate,
        'jumlah_kg': jumlahKg,
        'tarif_per_kg': tarifPerKg,
        'tujuan_id': _selectedTujuanId,
        'total_gaji': totalGaji,
        'keterangan': _keteranganCtrl.text,
        'transaksi_id': newTransaksi['id'],
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gaji berhasil dicatat & masuk pengeluaran!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Gagal menyimpan: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  String _formatRupiah(int amount) {
    return 'Rp ' +
        amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  void dispose() {
    _tanggalCtrl.dispose();
    _kgCtrl.dispose();
    _tarifKgCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Input Gaji Karyawan')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedKaryawanId,
                    decoration: const InputDecoration(
                      labelText: 'Pilih Karyawan',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Pilih Karyawan...'),
                    items: _karyawanList.map((k) {
                      return DropdownMenuItem<String>(
                        value: k['id'],
                        child: Text('${k['nama']} (${k['peran']})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedKaryawanId = val;
                        _selectedRole = _karyawanList.firstWhere(
                          (k) => k['id'] == val,
                        )['peran'];

                        _selectedTujuanId = null;
                        _kgCtrl.clear();
                        _tarifKgCtrl.clear();
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _tanggalCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _tanggalCtrl.text =
                              "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  if (_selectedRole == 'Sopir') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detail Sopir',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _selectedTujuanId,
                            decoration: const InputDecoration(
                              labelText: 'Rute Tujuan',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: _tujuanList.map((t) {
                              return DropdownMenuItem<String>(
                                value: t['id'],
                                child: Text(
                                  '${t['nama_tujuan']} - ${_formatRupiah(t['ongkos'])}',
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedTujuanId = val),
                          ),
                        ],
                      ),
                    ),
                  ] else if (_selectedRole == 'Bongkar Muat') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detail Bongkar Muat',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _kgCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Tonase',
                                    border: OutlineInputBorder(),
                                    suffixText: 'Kg',
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _tarifKgCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Tarif / Kg',
                                    border: OutlineInputBorder(),
                                    prefixText: 'Rp',
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (_selectedRole != null) const SizedBox(height: 16),

                  TextField(
                    controller: _keteranganCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan Tambahan (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveSalary,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Simpan Gaji',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
