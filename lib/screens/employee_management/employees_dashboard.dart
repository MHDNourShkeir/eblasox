import 'package:eblasox/screens/recording_hours/daily_hours_screen.dart';
import 'package:eblasox/screens/recording_hours/daily_hours_cubit.dart'; // 🚀 لا تنسَ استدعاء الـ Cubit
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // 🚀 استدعاء مكتبة البلوك
import 'package:shared_preferences/shared_preferences.dart';
import 'advances/advances_screen.dart';

class EmployeesManagementScreen extends StatelessWidget {
  const EmployeesManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الموظفين', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.indigo.shade800,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.indigo.shade800, Colors.grey.shade100],
              stops: const [0.0, 0.3],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'الخدمات الإدارية',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'اختر الخدمة المطلوبة لإدارة شؤون الموظفين',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0,
                      children: [
                        _buildSubDashboardCard(
                          context: context,
                          title: 'نظام السلف',
                          subtitle: 'إدارة وتخريج السلف',
                          icon: Icons.payments_rounded,
                          color: Colors.indigo.shade600,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const AdvancesScreen()),
                            );
                          },
                        ),
                        // 🚀 التعديل هنا: إضافة BlocProvider
                        _buildSubDashboardCard(
                          context: context,
                          title: 'نظام الدوام',
                          subtitle: 'إدارة إدخال الدوام',
                          icon: Icons.calendar_month_outlined,
                          color: Colors.indigo.shade600,
                          onTap: () async {
                            final prefs = await SharedPreferences.getInstance();
                            final loggedInUser = prefs.getString('loggedInUser') ?? '';

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => BlocProvider(
                                    create: (context) => DailyHoursCubit(),
                                    child: DailyHoursScreen(
                                      supervisorSection: loggedInUser,
                                    ),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubDashboardCard({
    required BuildContext context,
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