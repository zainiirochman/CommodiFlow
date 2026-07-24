import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  bool _isSaving = false;

  final TextEditingController _namaKategoriController = TextEditingController();
  String? _selectedJenisKategori;
  final List<String> _jenisKategoriOptions = ['Pemasukan', 'Pengeluaran'];

  Future<void> _saveCategory() async {
    if (_namaKategoriController.text.isEmpty ||
        _selectedJenisKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua field yang wajib diisi!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User tidak ditemukan. Silakan login kembali.');
      }

      await Supabase.instance.client
          .from('kategori_transaksi')
          .insert({
            'user_id': user.id,
            'nama_kategori': _namaKategoriController.text,
            'jenis': _selectedJenisKategori,
          })
          .select('id')
          .single();

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kategori berhasil ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan kategori: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _namaKategoriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Kategori')),
      body: _isSaving
          ? Center(
              child: Lottie.asset(
                'assets/lottie/Loading.json',
                height: 250,
                width: 250,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Isi Detail Kategori',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.0),

                  TextField(
                    controller: _namaKategoriController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedJenisKategori,
                    items: _jenisKategoriOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedJenisKategori = newValue;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Jenis Kategori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32.0),

                  ElevatedButton(
                    onPressed: _saveCategory,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Simpan Transaksi',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
