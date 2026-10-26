import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smb_connect/smb_connect.dart'; // 🚀 استدعاء مكتبة الـ SMB

import 'package:eblasox/screens/calculator/calculator_screen.dart';
import 'package:eblasox/screens/employee_management/employees_dashboard.dart';
import 'core/config_sync_manager/config_sync_manager.dart';
import 'screens/article_image/article_cubit.dart';
import 'screens/article_image/article_search.dart';
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
    SmbConnect? connection;
    try {
      // 1. جلب بيانات الاتصال من الجهاز (أو الافتراضية إذا كانت أول مرة)
      final host = await ConfigSyncManager.getHost();
      final username = await ConfigSyncManager.getUsername();
      final password = await ConfigSyncManager.getPassword();
      final configPath = await ConfigSyncManager.getConfigFilePath();

      // 2. الاتصال بسيرفر SMB
      connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: username,
        password: password,
      );

      // 3. قراءة ملف config.xlsx وتحويله إلى Bytes
      final fileObj = await connection.file(configPath);
      final stream = await connection.openRead(fileObj);

      final List<int> excelFileBytes = [];
      await for (var chunk in stream) {
        excelFileBytes.addAll(chunk);
      }

      await connection.close();

      // 4. تمرير الملف لمدير المزامنة للتحقق من الإصدار وتحديث الإعدادات محلياً
      if (excelFileBytes.isNotEmpty) {
        await ConfigSyncManager.syncConfigWithServer(excelFileBytes);
      }

    } catch (e) {
      debugPrint('⚠️ خطأ أثناء مزامنة الإعدادات: $e');
      try {
        await connection?.close();
      } catch (_) {}
      // سيستمر التطبيق بالعمل باستخدام الإعدادات المحفوظة مسبقاً (Fallback)
    }

    // 5. إنهاء شاشة التحميل والانتقال للتطبيق
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

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthSuccess) {
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
      onNavigateToCalculator:  () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const DozenCalculatorScreen()));
      },
    );
  }
}