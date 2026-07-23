import 'dart:io';
import 'dart:convert';
import 'package:commodi_flow/main.dart';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class Input extends StatefulWidget {
  final String imagePath;

  const Input({super.key, required this.imagePath});

  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _errorMessage = '';

  final TextEditingController _nominalCtrl = TextEditingController();
  final TextEditingController _keteranganCtrl = TextEditingController();
  final TextEditingController _tanggalCtrl = TextEditingController();
  final TextEditingController _stokCtrl = TextEditingController();

  String? _selectedKategori;
  String? _selectedNamaKategori;
  final List<String> _kategoriOptions = ['Pemasukan', 'Pengeluaran'];
  List<String> _namaKategoriOptions = [];

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.imagePath.isNotEmpty) {
      _processImageWithRealAI();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _fetchCategories() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('kategori_transaksi')
        .select('nama_kategori')
        .eq('user_id', user.id);

    if (mounted) {
      setState(() {
        _namaKategoriOptions = List<String>.from(
          data.map((item) => item['nama_kategori'] as String),
        );
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_nominalCtrl.text.isEmpty ||
        _tanggalCtrl.text.isEmpty ||
        _selectedKategori == null ||
        _selectedNamaKategori == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap lengkapi semua field yang wajib diisi.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception(
          'Sesi pengguna tidak ditemukan. Silakan login kembali.',
        );
      }
      final dateParts = _tanggalCtrl.text.split('/');
      final formattedDate = '${dateParts[2]}-${dateParts[1]}-${dateParts[0]}';
      final nominalValue = int.parse(
        _nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      );
      var category = await supabase
          .from('kategori_transaksi')
          .select('id')
          .eq('user_id', user.id)
          .eq('nama_kategori', _selectedNamaKategori!)
          .maybeSingle();

      String categoryId;
      if (category == null) {
        final newCat = await supabase
            .from('kategori_transaksi')
            .insert({
              'user_id': user.id,
              'nama_kategori': _selectedNamaKategori,
              'jenis': _selectedKategori,
            })
            .select('id')
            .single();
        categoryId = newCat['id'];
      } else {
        categoryId = category['id'];
      }

      String? imageUrl;
      if (widget.imagePath.isNotEmpty) {
        final file = File(widget.imagePath);
        final fileExt = widget.imagePath.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await supabase.storage.from('nota_images').upload(fileName, file);
        imageUrl = supabase.storage.from('nota_images').getPublicUrl(fileName);
      }

      final newTransaction = await supabase
          .from('transaksi')
          .insert({
            'user_id': user.id,
            'nominal': nominalValue,
            'tanggal': formattedDate,
            'kategori_id': categoryId,
            'keterangan': _keteranganCtrl.text,
            'nota_image_url': imageUrl,
          })
          .select('id')
          .single();

      final String transactionId = newTransaction['id'];
      final stokValue =
          double.tryParse(_stokCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;

      if (stokValue > 0) {
        String jenisPergerakan = _selectedKategori == 'Pemasukan'
            ? 'Keluar'
            : 'Masuk';
        await supabase.from('pergerakan_stok').insert({
          'user_id': user.id,
          'transaksi_id': transactionId,
          'jumlah_kg': stokValue,
          'tanggal': formattedDate,
          'jenis_pergerakan': jenisPergerakan,
          'keterangan': 'Otomatis dari nota ${_keteranganCtrl.text}',
        });
      }

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil disimpan!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan transaksi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _processImageWithRealAI() async {
    try {
      final model = GenerativeModel(model: 'gemini-3.6-flash', apiKey: _apiKey);

      final imageFile = File(widget.imagePath);
      final imageBytes = await imageFile.readAsBytes();

      final prompt = TextPart('''
        Analisis gambar nota atau kuitansi ini. 
        Keluarkan output HANYA berupa JSON valid (tanpa blockquote markdown ```json dan tanpa teks pembuka/penutup).
        Gunakan struktur key persis seperti ini:
        {
          "nominal": "ekstrak total harga, kembalikan hanya angka tanpa pemisah ribuan. contoh: 150000",
          "tanggal": "ekstrak tanggal di nota dengan format DD/MM/YYYY. Jika tidak ada tanggal tertulis, isi dengan '22/07/2026'",
          "kategori": "Analisis apakah ini transaksi uang masuk atau uang keluar. Jika ini adalah bukti beli barang/bayar jasa/ongkos/kuli, balas dengan kata HANYA 'Pengeluaran'. Jika ini adalah bukti hasil jual barang/terima uang, balas dengan kata HANYA 'Pemasukan'.",
          "keterangan": "ekstrak deskripsi barang atau jasa yang dibeli/dijual secara singkat",
          "tonase": "ekstrak berat barang (tonase) dalam satuan kg jika ada di nota. Kembalikan HANYA angkanya. Jika tidak tertulis, isi dengan '0'"
        }
      ''');

      final imagePart = DataPart('image/jpeg', imageBytes);

      final response = await model.generateContent([
        Content.multi([prompt, imagePart]),
      ]);

      String responseText = response.text ?? '{}';
      responseText = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final Map<String, dynamic> aiResult = jsonDecode(responseText);

      String kategoriAI = aiResult['kategori']?.toString() ?? 'Pengeluaran';
      if (!_kategoriOptions.contains(kategoriAI)) {
        kategoriAI = 'Pengeluaran';
      }

      String defaultDate =
          "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";

      if (mounted) {
        setState(() {
          _nominalCtrl.text = aiResult['nominal']?.toString() ?? '';

          String aiDate = aiResult['tanggal']?.toString() ?? '';
          _tanggalCtrl.text = aiDate.isNotEmpty ? aiDate : defaultDate;

          _selectedKategori = kategoriAI;
          _keteranganCtrl.text = aiResult['keterangan']?.toString() ?? '';
          String aiStok = aiResult['tonase']?.toString() ?? '';
          _stokCtrl.text = aiStok.isNotEmpty ? aiStok : '0';

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Gagal membaca gambar. Silakan isi form secara manual. Error: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menganalisis nota.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nominalCtrl.dispose();
    _keteranganCtrl.dispose();
    _tanggalCtrl.dispose();
    _stokCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.imagePath.isNotEmpty ? 'Konfirmasi Nota' : 'Input Transaksi',
        ),
      ),
      body: _isLoading || _isSaving ? _buildLoadingState() : _buildFormState(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/lottie/Loading.json', width: 250, height: 250),
          SizedBox(height: 24),
          Text(
            'Tunggu sebentar...\nJangan tutup aplikasi.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFormState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),

          if (widget.imagePath.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(widget.imagePath),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          if (widget.imagePath.isNotEmpty) const SizedBox(height: 24),
          Text(
            widget.imagePath.isNotEmpty
                ? 'Periksa & Edit Hasil Bacaan:'
                : 'Isi Detail Transaksi:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _nominalCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal (Rp)',
              border: OutlineInputBorder(),
              prefixText: 'Rp ',
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
              if (_tanggalCtrl.text.isNotEmpty) {
                try {
                  final parts = _tanggalCtrl.text.split('/');
                  if (parts.length == 3) {
                    initialDate = DateTime(
                      int.parse(parts[2]),
                      int.parse(parts[1]),
                      int.parse(parts[0]),
                    );
                  }
                } catch (e) {}
              }

              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );

              if (pickedDate != null) {
                String formattedDate =
                    "${pickedDate.day.toString().padLeft(2, '0')}/${pickedDate.month.toString().padLeft(2, '0')}/${pickedDate.year}";

                setState(() {
                  _tanggalCtrl.text = formattedDate;
                });
              }
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedKategori,
            decoration: const InputDecoration(
              labelText: 'Kategori Kas (Uang)',
              border: OutlineInputBorder(),
            ),
            items: _kategoriOptions.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedKategori = newValue;
              });
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value:
                _selectedNamaKategori != null &&
                    _namaKategoriOptions.contains(_selectedNamaKategori)
                ? _selectedNamaKategori
                : null,
            decoration: const InputDecoration(
              labelText: 'Keterangan Kategori',
              border: OutlineInputBorder(),
            ),
            items: _namaKategoriOptions.isEmpty
                ? [const DropdownMenuItem(value: '', child: Text('Memuat...'))]
                : _namaKategoriOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedNamaKategori = newValue;
              });
            },
          ),
          const SizedBox(height: 16),

          TextField(
            controller: _stokCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Tonase (kg)',
              hintText: 'Kosongkan jika bukan transaksi barang',
              border: OutlineInputBorder(),
              suffixText: 'Kg',
            ),
          ),
          const SizedBox(height: 16),

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
            onPressed: _saveTransaction,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Simpan Transaksi', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
