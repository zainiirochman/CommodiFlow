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

  final TextEditingController _namaKaryawanController = TextEditingController();
  String? _selectedPeranKaryawan;
  final List<String> _peranKaryawanOptions = ['Sopir', 'Bongkar Muat'];

  Future<void> _saveEmployee() async {
    if (_namaKaryawanController.text.isEmpty ||
        _selectedPeranKaryawan == null) {
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
          .from('karyawan')
          .insert({
            'user_id': user.id,
            'nama': _namaKaryawanController.text,
            'peran': _selectedPeranKaryawan,
            'status_aktif': true,
          })
          .select('id')
          .single();

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Karyawan berhasil ditambahkan!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data karyawan: $e'),
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
    _namaKaryawanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tambah Karyawan')),
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
                    'Isi Detail Karyawan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16.0),

                  TextField(
                    controller: _namaKaryawanController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Karyawan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedPeranKaryawan,
                    items: _peranKaryawanOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedPeranKaryawan = newValue;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Peran Karyawan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32.0),

                  ElevatedButton(
                    onPressed: _saveEmployee,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Simpan Karyawan',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
