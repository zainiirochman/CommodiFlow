import 'package:commodi_flow/screen/category/edit.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  bool _isLoading = false;

  List<dynamic> _allCategories = [];
  List<dynamic> _filteredCategories = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _applyFilters();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('kategori_transaksi')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allCategories = response;
          _applyFilters();
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

  void _applyFilters() {
    var tempCategory = _allCategories;

    if (_searchQuery.isNotEmpty) {
      tempCategory = tempCategory.where((category) {
        final name = category['nama_kategori']?.toString().toLowerCase() ?? '';
        final jenis = category['jenis']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery) || jenis.contains(_searchQuery);
      }).toList();
    }

    _filteredCategories = tempCategory;
  }

  Future<void> _deleteCategory(String id) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Hapus Data?'),
            content: const Text(
              'Data yang dihapus tidak dapat dikembalikan. Lanjutkan?',
            ),
            actions: [
              TextButton(
                child: const Text(
                  'Batal',
                  style: TextStyle(color: Colors.grey),
                ),
                onPressed: () {
                  Navigator.pop(context, false);
                },
              ),
              TextButton(
                child: const Text(
                  'Hapus',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () {
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await Supabase.instance.client
          .from('kategori_transaksi')
          .delete()
          .eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchCategories();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus data : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Kategori Transaksi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari kategori...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                FocusScope.of(context).unfocus();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          : _buildCategoryList(),
    );
  }

  Widget _buildCategoryList() {
    if (_filteredCategories.isEmpty) {
      return _buildEmptyState('Tidak ada kategori yang ditemukan.');
    }
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: _filteredCategories.length,
      separatorBuilder: (context, index) => Divider(color: Colors.grey),
      itemBuilder: (context, index) {
        final ctxt = _filteredCategories[index];
        final id = ctxt['id'];
        final namaKategori = ctxt['nama_kategori'] ?? '';
        final jenis = ctxt['jenis'] ?? '';
        final isIncome = ctxt['jenis'] == 'Pemasukan';

        return _buildListItem(
          isIncome: isIncome,
          icon: isIncome ? Icons.account_balance_wallet : Icons.receipt_long,
          iconColor: isIncome ? Colors.green : Colors.red,
          title: namaKategori,
          subtitle: jenis,
          onDelete: () => _deleteCategory(id),
          // onEdit: () {
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     SnackBar(
          //       content: Text('Fitur edit kategori belum tersedia.'),
          //       backgroundColor: Colors.orange,
          //     ),
          //   );
          // },
          onEdit: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditPage(itemData: ctxt)),
            );
            if (result == true) {
              await _fetchCategories();
              setState(() {});
            }
          },
        );
      },
    );
  }

  Widget _buildListItem({
    required bool isIncome,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onDelete,
    required VoidCallback onEdit,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: iconColor.withOpacity(0.1),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        'Jenis : $subtitle',
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (BuildContext context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: const [
                Icon(Icons.edit, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text('Edit'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: const [
                Icon(Icons.delete, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Text('Hapus'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
