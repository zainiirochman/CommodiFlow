import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditPage extends StatefulWidget {
  const EditPage({super.key, required this.itemData});
  final Map<String, dynamic> itemData;

  @override
  State<EditPage> createState() => _EditPageState();
}

class _EditPageState extends State<EditPage> {
  bool _isSaving = false;

  final TextEditingController _namaKategoriController = TextEditingController();
  final TextEditingController _jenisKategoriController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    _namaKategoriController.text = widget.itemData['nama_kategori'] ?? '';
    _jenisKategoriController.text = widget.itemData['jenis'] ?? '';
  }

  Future<void> _updateData() async {
    if (_namaKategoriController.text.isEmpty ||
        _jenisKategoriController.text.isEmpty) {
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
      final updatedData = {
        'nama_kategori': _namaKategoriController.text,
        'jenis': _jenisKategoriController.text,
      };

      await Supabase.instance.client
          .from('kategori_transaksi')
          .update(updatedData)
          .eq('id', widget.itemData['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui data: $e'),
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
    _namaKategoriController.dispose();
    _jenisKategoriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Kategori')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _namaKategoriController,
              decoration: InputDecoration(
                labelText: 'Nama Kategori',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),

            DropdownButtonFormField<String>(
              value: _jenisKategoriController.text.isNotEmpty
                  ? _jenisKategoriController.text
                  : null,
              items: const [
                DropdownMenuItem(value: 'Pemasukan', child: Text('Pemasukan')),
                DropdownMenuItem(
                  value: 'Pengeluaran',
                  child: Text('Pengeluaran'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _jenisKategoriController.text = value ?? '';
                });
              },
              decoration: const InputDecoration(
                labelText: 'Jenis Kategori',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32.0),

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
