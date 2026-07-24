import 'package:commodi_flow/screen/category/category.dart';
import 'package:commodi_flow/screen/login.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = false;

  Future<void> _logout() async {
    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.signOut();
      await GoogleSignIn.instance.signOut();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal logout: $error')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final String userName =
        user?.userMetadata?['full_name'] ??
        user?.userMetadata?['name'] ??
        user?.email ??
        'Pengguna';
    final String profilePictureUrl = user?.userMetadata?['avatar_url'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Profil Akun',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
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
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Center(
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Color(0xFF2E7D32),
                            backgroundImage: profilePictureUrl.isNotEmpty
                                ? NetworkImage(profilePictureUrl)
                                : null,
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Image.network(
                              'https://img.icons8.com/?size=100&id=17949&format=png&color=000000',
                              height: 16,
                              width: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Hello Mr.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),

                    Text(
                      userName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            icon: Icons.category_rounded,
                            iconBgColor: Colors.purple.shade50,
                            iconColor: Colors.purple,
                            title: 'Kelola Kategori',
                            subtitle:
                                'Tambah/edit jenis pemasukan & pengeluaran',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const CategoryPage(),
                                ),
                              );
                            },
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            icon: Icons.picture_as_pdf_rounded,
                            iconBgColor: Colors.blue.shade50,
                            iconColor: Colors.blue,
                            title: 'Ekspor Laporan',
                            subtitle:
                                'Unduh laporan laba rugi bulanan (PDF/Excel)',
                            onTap: () {},
                          ),
                          _buildDivider(),
                          _buildMenuItem(
                            icon: Icons.help_outline_rounded,
                            iconBgColor: Colors.orange.shade50,
                            iconColor: Colors.orange,
                            title: 'Bantuan & Dukungan',
                            subtitle: 'Hubungi developer atau baca panduan',
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Fitur ini belum tersedia. Silakan hubungi developer lewat WA wkwkwkwk.',
                                  ),
                                  duration: Duration(seconds: 3),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _buildMenuItem(
                        icon: Icons.logout_rounded,
                        iconBgColor: Colors.red.shade50,
                        iconColor: Colors.red,
                        title: 'Keluar (Logout)',
                        subtitle: 'Keluar dari akun Google ini',
                        titleColor: Colors.red.shade700,
                        hideArrow: true,
                        onTap: _logout,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    Color titleColor = Colors.black87,
    bool hideArrow = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: iconBgColor,
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
      ),
      trailing: hideArrow
          ? null
          : Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.grey.shade400,
            ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 70, right: 20),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}
