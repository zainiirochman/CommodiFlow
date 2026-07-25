import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPage extends StatefulWidget {
  final Map<String, dynamic> salaryData;

  const EditPage({super.key, required this.salaryData});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
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
    _initData();
    _fetchDataMaster();
  }

  void _initData() {
    final data = widget.salaryData;

    _selectedKaryawanId = data['karyawan_id'];
    _selectedRole = data['karyawan'] != null ? data['karyawan']['peran'] : null;

    final dateStr = data['tanggal'] ?? '';
    if (dateStr.isNotEmpty) {
      final date = DateTime.parse(dateStr);
      _tanggalCtrl.text =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }

    _keteranganCtrl.text = data['keterangan'] ?? '';

    if (_selectedRole == 'Sopir') {
      _selectedTujuanId = data['tujuan_id'];
    } else if (_selectedRole == 'Bongkar Muat') {
      final kg = data['jumlah_kg'];
      final tarif = data['tarif_per_kg'];
      if (kg != null) _kgCtrl.text = kg.toString();
      if (tarif != null) _tarifKgCtrl.text = tarif.toString();
    }
  }

  Future<void> _fetchDataMaster() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final resKaryawan = await Supabase.instance.client
          .from('karyawan')
          .select('*')
          .eq('user_id', userId);

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
          SnackBar(
            content: Text('Error memuat data dropdown: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateSalary() async {
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
      int newTotalGaji = 0;
      double? jumlahKg;
      int? tarifPerKg;
      String detailKeterangan = _keteranganCtrl.text;

      if (_selectedRole == 'Sopir') {
        final tujuan = _tujuanList.firstWhere(
          (t) => t['id'] == _selectedTujuanId,
        );
        newTotalGaji = tujuan['ongkos'] as int;
        if (detailKeterangan.isEmpty)
          detailKeterangan = 'Gaji Sopir rute: ${tujuan['nama_tujuan']}';
      } else {
        jumlahKg = double.parse(_kgCtrl.text.replaceAll(',', '.'));
        tarifPerKg = int.parse(
          _tarifKgCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        );
        newTotalGaji = (jumlahKg * tarifPerKg).toInt();
        if (detailKeterangan.isEmpty)
          detailKeterangan = 'Gaji Bongkar Muat ($jumlahKg Kg)';
      }

      final dateParts = _tanggalCtrl.text.split('/');
      final formattedDate = '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';

      await Supabase.instance.client
          .from('riwayat_gaji')
          .update({
            'karyawan_id': _selectedKaryawanId,
            'tanggal': formattedDate,
            'jumlah_kg': jumlahKg,
            'tarif_per_kg': tarifPerKg,
            'tujuan_id': _selectedRole == 'Sopir' ? _selectedTujuanId : null,
            'total_gaji': newTotalGaji,
            'keterangan': _keteranganCtrl.text,
          })
          .eq('id', widget.salaryData['id']);

      final transaksiId = widget.salaryData['transaksi_id'];
      if (transaksiId != null) {
        await Supabase.instance.client
            .from('transaksi')
            .update({
              'nominal': newTotalGaji,
              'tanggal': formattedDate,
              'keterangan': detailKeterangan,
            })
            .eq('id', transaksiId);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gaji berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Gagal memperbarui: $e');
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
      appBar: AppBar(title: const Text('Edit Gaji Karyawan')),
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
                      DateTime initialDate = DateTime.now();
                      try {
                        final parts = _tanggalCtrl.text.split('/');
                        initialDate = DateTime(
                          int.parse(parts[2]),
                          int.parse(parts[1]),
                          int.parse(parts[0]),
                        );
                      } catch (_) {}

                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: initialDate,
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
                    onPressed: _isSaving ? null : _updateSalary,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue,
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
                            'Simpan Perubahan',
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
