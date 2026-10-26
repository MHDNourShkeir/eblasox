import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/config_sync_manager/config_sync_manager.dart';
import 'screens/article_image/article_cubit.dart';
import 'screens/article_image/article_search.dart';
import 'screens/calculator/calculator_screen.dart';
import 'screens/employee_management/employees_dashboard.dart';
import 'screens/excel_search_screen/excel_viewer_cubit.dart';
import 'screens/management/management_screen.dart';
import 'screens/management/mangement_cubit.dart';
import 'screens/auth/auth_cubit.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/excel_search_screen/excel_search.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  runApp(const SmbApp());
}

class SmbApp extends StatefulWidget {
  const SmbApp({super.key});

  @override
  State<SmbApp> createState() => _SmbAppState();
}

class _SmbAppState extends State<SmbApp> {
  bool _isAppReady = false;

  @override
  void initState() {
    super.initState();
    _syncConfigAndInitialize();
  }

  Future<void> _syncConfigAndInitialize() async {
    // 🚀 مزامنة الإعدادات عند فتح التطبيق (مع مسح الجلسة إذا تغير الإصدار)
    await ConfigSyncManager.fetchAndSyncFromServer(clearSessionOnUpdate: true);

    if (mounted) {
      setState(() {
        _isAppReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🚀 عرض شاشة تحميل بسيطة أثناء الاتصال بالسيرفر لجلب الإعدادات
    if (!_isAppReady) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.teal.shade700,
          body: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    // 🚀 بمجرد الانتهاء، يتم تحميل الكيوبتات بالمسارات الجديدة المحدثة
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ManagementCubit()..loadSettings()),
        BlocProvider(create: (context) => ArticleCubit()..loadArticles()),
        BlocProvider(create: (context) => ExcelCubit()..loadExcelFiles()),
        BlocProvider(create: (context) => AuthCubit()..checkSession()),
      ],
      child: MaterialApp(
        title: 'نظام إدارة المعمل',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isSyncingAfterLogin = false;

  Future<void> _resyncOnLogin(BuildContext context) async {
    setState(() => _isSyncingAfterLogin = true);

    // 1. مزامنة الإعدادات من السيرفر (دون مسح الجلسة الحالية)
    await ConfigSyncManager.fetchAndSyncFromServer(clearSessionOnUpdate: false);

    // 2. تحديث جميع الكيوبتات لتقرأ المسارات الجديدة فوراً
    if (context.mounted) {
      context.read<ManagementCubit>().loadSettings();
      context.read<ArticleCubit>().loadArticles(force: true);
      context.read<ExcelCubit>().loadExcelFiles(force: true);
    }

    if (mounted) {
      setState(() => _isSyncingAfterLogin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        // 🚀 بمجرد نجاح تسجيل الدخول، نقوم بمزامنة الإعدادات وتحديث المسارات
        if (state is AuthSuccess) {
          _resyncOnLogin(context);
        }
      },
      builder: (context, state) {
        if (state is AuthSuccess) {
          // عرض مؤشر تحميل سريع أثناء تحديث المسارات بعد تسجيل الدخول
          if (_isSyncingAfterLogin) {
            return Scaffold(
              backgroundColor: Colors.blue.shade800,
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'جاري مزامنة أحدث الإعدادات...',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }
          return const DashboardWrapper();
        }
        return const LoginScreen();
      },
    );
  }
}

class DashboardWrapper extends StatelessWidget {
  const DashboardWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MainDashboardScreen(
      onNavigateToImages: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ArticleListScreen()));
      },
      onNavigateToExcel: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ExcelListScreen()));
      },
      onNavigateToSettings: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagementScreen()));
      },
      onNavigateToEmployeesManagement: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeesManagementScreen()));
      },
      onNavigateToCalculator: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const DozenCalculatorScreen()));
      },
    );
  }
}