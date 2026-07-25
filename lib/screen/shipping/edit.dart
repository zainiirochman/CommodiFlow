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

  final TextEditingController _namaTujuanController = TextEditingController();
  final TextEditingController _ongkosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    _namaTujuanController.text = widget.itemData['nama_tujuan'] ?? '';
    _ongkosController.text = widget.itemData['ongkos']?.toString() ?? '';
  }

  Future<void> _updateData() async {
    if (_namaTujuanController.text.isEmpty || _ongkosController.text.isEmpty) {
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
        'nama_tujuan': _namaTujuanController.text,
        'ongkos': _ongkosController.text,
      };

      await Supabase.instance.client
          .from('tarif_tujuan')
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
    _namaTujuanController.dispose();
    _ongkosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Tujuan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _namaTujuanController,
              decoration: InputDecoration(
                labelText: 'Nama Tujuan',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),

            TextField(
              controller: _ongkosController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Ongkos',
                prefixText: 'Rp ',
                border: const OutlineInputBorder(),
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
