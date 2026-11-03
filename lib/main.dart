import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/config_sync_manager/config_sync_manager.dart';
import 'core/config_sync_manager/role_manager/role_manager.dart';
import 'screens/article_image/article_cubit.dart';
import 'screens/article_image/article_search.dart';
import 'screens/calculator/calculator_screen.dart';
import 'screens/employee_management/employees_dashboard.dart';
import 'screens/excel_search_screen/excel_viewer_cubit.dart';
import 'screens/excel_search_screen/excel_search.dart';
import 'screens/management/management_screen.dart';
import 'screens/management/mangement_cubit.dart';
import 'screens/auth/auth_cubit.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const SmbApp());
}

// ==========================================
// MAIN APP
// ==========================================

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
    await ConfigSyncManager.fetchAndSyncFromServer(clearSessionOnUpdate: true);

    if (!mounted) return;

    setState(() {
      _isAppReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
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

    return MultiBlocProvider(
      providers: [
        // ==================================
        // AUTH CUBIT
        // Always initialized at startup.
        // ==================================

        BlocProvider<AuthCubit>(
          lazy: false,
          create: (_) => AuthCubit()..checkSession(),
        ),

        // ==================================
        // ARTICLE CUBIT
        // Created ONLY when requested.
        // Data loads when an authorized
        // user opens the image screen.
        // ==================================
        BlocProvider<ArticleCubit>(
          lazy: true,
          create: (_) => ArticleCubit()..loadArticles(force: true),
        ),

        // ==================================
        // EXCEL CUBIT
        // Created ONLY when requested.
        // ==================================
        BlocProvider<ExcelCubit>(
          lazy: true,
          create: (_) => ExcelCubit()..loadExcelFiles(force: true),
        ),

        // ==================================
        // MANAGEMENT CUBIT
        // Created only when settings open.
        // ==================================
        BlocProvider<ManagementCubit>(
          lazy: true,
          create: (_) => ManagementCubit()..loadSettings(),
        ),
      ],

      child: MaterialApp(
        title: 'نظام إدارة المعمل',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

// ==========================================
// AUTH WRAPPER
// ==========================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        // ==================================
        // AUTHENTICATED USER
        // ==================================

        if (state is AuthSuccess) {
          return const DashboardWrapper();
        }

        // ==================================
        // LOADING
        // ==================================

        if (state is AuthInitial ||
            state is AuthLoadingUsers ||
            state is AuthLoggingIn) {
          return Scaffold(
            backgroundColor: Colors.blue.shade800,
            body: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // ==================================
        // LOGIN SCREEN
        // ==================================

        return const LoginScreen();
      },
    );
  }
}

// ==========================================
// DASHBOARD WRAPPER
// ==========================================

class DashboardWrapper extends StatelessWidget {
  const DashboardWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;

    if (authState is! AuthSuccess) {
      return const SizedBox.shrink();
    }

    final permissions = authState.allowedScreens;

    return MainDashboardScreen(
      // ==================================
      // SCREEN 1 - IMAGES
      // ==================================

      onNavigateToImages: () {
        if (!RoleManager.shouldLoadData(RoleManager.images, permissions)) {
          return;
        }

        // This read creates ArticleCubit
        // and loads its data for the first time.
        context.read<ArticleCubit>();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArticleListScreen()),
        );
      },

      // ==================================
      // SCREEN 2 - EXCEL
      // ==================================
      onNavigateToExcel: () {
        if (!RoleManager.shouldLoadData(RoleManager.excel, permissions)) {
          return;
        }

        // This read creates ExcelCubit
        // and loads its data for the first time.
        context.read<ExcelCubit>();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExcelListScreen()),
        );
      },

      // ==================================
      // SETTINGS
      // ==================================
      onNavigateToSettings: () {
        // ManagementCubit is lazy.
        // It loads settings only when requested.
        context.read<ManagementCubit>();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManagementScreen()),
        );
      },

      // ==================================
      // SCREEN 3 - EMPLOYEES
      // ==================================
      onNavigateToEmployeesManagement: () {
        if (!RoleManager.shouldLoadData(RoleManager.employees, permissions)) {
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmployeesManagementScreen()),
        );
      },
      // ==================================
      // SCREEN 4 - CALCULATOR
      // ==================================
      onNavigateToCalculator: () {
        if (!RoleManager.shouldLoadData(RoleManager.calculator, permissions)) {
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DozenCalculatorScreen()),
        );
      },
    );
  }
}
