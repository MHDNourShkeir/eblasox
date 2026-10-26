import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/config_sync_manager/config_sync_manager.dart';
import '../auth/auth_cubit.dart';

class MainDashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToImages;
  final VoidCallback onNavigateToExcel;
  final VoidCallback onNavigateToSettings;
  final VoidCallback onNavigateToEmployeesManagement;
  final VoidCallback onNavigateToCalculator;

  const MainDashboardScreen({
    super.key,
    required this.onNavigateToImages,
    required this.onNavigateToExcel,
    required this.onNavigateToSettings,
    required this.onNavigateToEmployeesManagement,
    required this.onNavigateToCalculator,
  });

  void _showSettingsPasswordDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text('الحماية والإدارة', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرجاء إدخال كلمة المرور للوصول إلى لوحة الإعدادات:',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'كلمة المرور',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () async {
              // 🚀 جلب كلمة مرور الأدمن من الإعدادات الديناميكية
              final adminPass = await ConfigSyncManager.getAdminPassword();

              if (!context.mounted) return;

              if (passwordController.text == adminPass) {
                Navigator.pop(context);
                onNavigateToSettings();
              } else {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة المرور غير صحيحة!'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('دخول', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    context.read<AuthCubit>().logout();
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final userName = authState is AuthSuccess ? authState.loggedInUser : '';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة التحكم الرئيسية', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue.shade800,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'تسجيل الخروج',
              onPressed: () => _handleLogout(context),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white),
              tooltip: 'الإعدادات والإدارة',
              onPressed: () => _showSettingsPasswordDialog(context),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade800, Colors.grey.shade100],
              stops: const [0.0, 0.3],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  'مرحبا بك $userName',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اختر القسم المطلوب',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildDashboardCard(
                        title: 'كتالوج الصور',
                        subtitle: 'عرض صور الموديلات',
                        icon: Icons.image_rounded,
                        color: Colors.blueAccent,
                        onTap: onNavigateToImages,
                      ),
                      _buildDashboardCard(
                        title: 'ملفات الإكسل',
                        subtitle: 'عرض طلبات التصنيع',
                        icon: Icons.table_chart_rounded,
                        color: Colors.green.shade600,
                        onTap: onNavigateToExcel,
                      ),
                      _buildDashboardCard(
                        title: 'إدارة الموظفين',
                        subtitle: 'السلف ، الدوام',
                        icon: Icons.groups_rounded,
                        color: Colors.indigo.shade600,
                        onTap: onNavigateToEmployeesManagement,
                      ),
                      _buildDashboardCard(
                        title: 'الالة الحاسبة',
                        subtitle: 'حاسبة الدزينات',
                        icon: Icons.calculate,
                        color: Colors.teal.shade700,
                        onTap: onNavigateToCalculator,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: color),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}