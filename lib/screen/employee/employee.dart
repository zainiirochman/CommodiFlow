import 'package:commodi_flow/screen/employee/edit.dart';
import 'package:commodi_flow/screen/employee/input.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmployeePage extends StatefulWidget {
  const EmployeePage({super.key});

  @override
  State<EmployeePage> createState() => _EmployeePageState();
}

class _EmployeePageState extends State<EmployeePage> {
  bool _isLoading = false;

  List<dynamic> _allEmployee = [];
  List<dynamic> _filteredEmployee = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchEmployee();

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

  Future<void> _fetchEmployee() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('karyawan')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _allEmployee = response;
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
    var tempEmployee = _allEmployee;

    if (_searchQuery.isNotEmpty) {
      tempEmployee = tempEmployee.where((category) {
        final name = category['nama']?.toString().toLowerCase() ?? '';
        final peran = category['peran']?.toString().toLowerCase() ?? '';
        return name.contains(_searchQuery) || peran.contains(_searchQuery);
      }).toList();
    }

    _filteredEmployee = tempEmployee;
  }

  Future<void> _deleteEmployee(String id) async {
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
      await Supabase.instance.client.from('karyawan').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchEmployee();
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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InputPage()),
          );

          if (result == true) {
            await _fetchEmployee();
            setState(() {});
          }
        },
        backgroundColor: Colors.green,
        child: Icon(Icons.add, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
      ),
      appBar: AppBar(
        title: const Text(
          'Data Karyawan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Cari karyawan...',
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
    if (_filteredEmployee.isEmpty) {
      return _buildEmptyState('Tidak ada karyawan yang ditemukan.');
    }
    return RefreshIndicator(
      onRefresh: _fetchEmployee,
      child: ListView.separated(
        padding: EdgeInsets.all(16),
        itemCount: _filteredEmployee.length,
        separatorBuilder: (context, index) => Divider(color: Colors.grey),
        itemBuilder: (context, index) {
          final epxt = _filteredEmployee[index];
          final id = epxt['id'];
          final namaKaryawan = epxt['nama'] ?? '';
          final peran = epxt['peran'] ?? '';

          return _buildListItem(
            icon: Icons.receipt_long,
            iconColor: Colors.orange,
            title: namaKaryawan,
            subtitle: peran,
            onDelete: () => _deleteEmployee(id),
            onEdit: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditPage(itemData: epxt),
                ),
              );
              if (result == true) {
                await _fetchEmployee();
                setState(() {});
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildListItem({
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
        'Peran: $subtitle',
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
