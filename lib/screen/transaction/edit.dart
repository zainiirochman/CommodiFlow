import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPage extends StatefulWidget {
  final Map<String, dynamic> itemData;
  final String tableName;

  const EditPage({super.key, required this.itemData, required this.tableName});

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  bool _isSaving = false;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _tanggalCtrl = TextEditingController();
  final TextEditingController _keteranganCtrl = TextEditingController();

  String? _selectedJenisStok;
  final List<String> _jenisStokOptions = ['Masuk', 'Keluar', 'Susut'];

  bool get _isTransaksi => widget.tableName == 'transaksi';

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final dateStr = widget.itemData['tanggal'] ?? '';
    if (dateStr.isNotEmpty) {
      final date = DateTime.parse(dateStr);
      _tanggalCtrl.text =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }

    _keteranganCtrl.text = widget.itemData['keterangan'] ?? '';

    if (_isTransaksi) {
      final nominal = (widget.itemData['nominal'] ?? 0).toInt();
      _amountCtrl.text = nominal.toString();
    } else {
      final qty = (widget.itemData['jumlah_kg'] ?? 0).toDouble();
      _amountCtrl.text = qty.toStringAsFixed(0);
      _selectedJenisStok = widget.itemData['jenis_pergerakan'];
    }
  }

  Future<void> _updateData() async {
    if (_amountCtrl.text.isEmpty || _tanggalCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi data wajib!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final dateParts = _tanggalCtrl.text.split('/');
      final formattedDate = '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';

      final amountValue = double.parse(
        _amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''),
      );

      Map<String, dynamic> updatePayload = {
        'tanggal': formattedDate,
        'keterangan': _keteranganCtrl.text,
      };

      if (_isTransaksi) {
        updatePayload['nominal'] = amountValue.toInt();
      } else {
        updatePayload['jumlah_kg'] = amountValue;
        updatePayload['jenis_pergerakan'] = _selectedJenisStok;
      }

      await Supabase.instance.client
          .from(widget.tableName)
          .update(updatePayload)
          .eq('id', widget.itemData['id']);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tanggalCtrl.dispose();
    _keteranganCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTransaksi ? 'Edit Transaksi' : 'Edit Stok'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _isTransaksi ? 'Nominal (Rp)' : 'Tonase / Berat',
                border: const OutlineInputBorder(),
                prefixText: _isTransaksi ? 'Rp ' : null,
                suffixText: !_isTransaksi ? 'Kg' : null,
              ),
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

            if (!_isTransaksi) ...[
              DropdownButtonFormField<String>(
                value: _selectedJenisStok,
                decoration: const InputDecoration(
                  labelText: 'Jenis Pergerakan',
                  border: OutlineInputBorder(),
                ),
                items: _jenisStokOptions
                    .map(
                      (val) => DropdownMenuItem(value: val, child: Text(val)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedJenisStok = val),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _keteranganCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Keterangan (Opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isSaving ? null : _updateData,
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
                      'Simpan Perubahan',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
