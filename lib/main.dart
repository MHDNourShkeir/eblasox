import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/config_sync_manager/config_sync_manager.dart';
import 'core/config_sync_manager/role_manager/role_manager.dart';
import 'screens/article_image/article_cubit.dart';
import 'screens/article_image/article_search.dart';
import 'screens/auth/auth_cubit.dart';
import 'screens/auth/login_screen.dart';
import 'screens/calculator/calculator_screen.dart';
import 'screens/employee_management/employees_dashboard.dart';
import 'screens/excel_search_screen/excel_search.dart';
import 'screens/excel_search_screen/excel_viewer_cubit.dart';
import 'screens/home/home_screen.dart';
import 'screens/management/mangement_cubit.dart';
import 'screens/management/management_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmbApp());
}

// ======================================================
// MAIN APP
// ======================================================

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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await ConfigSyncManager.fetchAndSyncFromServer(
        clearSessionOnUpdate: true,
      );
    } catch (error, stackTrace) {
      debugPrint('Configuration initialization error: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (mounted) {
        setState(() {
          _isAppReady = true;
        });
      }
    }
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
        // AUTH: Always initialized at startup.
        BlocProvider<AuthCubit>(
          lazy: false,
          create: (_) => AuthCubit()..checkSession(),
        ),

        // IMAGES: Created only when an authorized user opens this screen.
        BlocProvider<ArticleCubit>(lazy: true, create: (_) => ArticleCubit()),

        // EXCEL: Created only when an authorized user opens this screen.
        BlocProvider<ExcelCubit>(lazy: true, create: (_) => ExcelCubit()),

        // SETTINGS: Created only when settings are opened.
        BlocProvider<ManagementCubit>(
          lazy: true,
          create: (_) => ManagementCubit(),
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

// ======================================================
// AUTH WRAPPER
// ======================================================

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthSuccess) {
          return const DashboardWrapper();
        }

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

        return const LoginScreen();
      },
    );
  }
}

// ======================================================
// DASHBOARD WRAPPER
// ======================================================

class DashboardWrapper extends StatelessWidget {
  const DashboardWrapper({super.key});

  // ----------------------------------------------------
  // CHECK USER PERMISSION
  // ----------------------------------------------------

  bool _hasPermission(
    BuildContext context,
    int screenId,
    Set<int> permissions,
  ) {
    final allowed = RoleManager.shouldLoadData(screenId, permissions);

    if (!allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ليس لديك صلاحية للوصول إلى هذا القسم')),
      );
    }

    return allowed;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;

    if (authState is! AuthSuccess) {
      return const SizedBox.shrink();
    }

    final permissions = authState.allowedScreens;

    return MainDashboardScreen(
      // =================================================
      // SCREEN 1: IMAGES
      // =================================================

      onNavigateToImages: () {
        if (!_hasPermission(context, RoleManager.images, permissions)) {
          return;
        }

        // Create ArticleCubit and load data only now.
        context.read<ArticleCubit>().loadArticles();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ArticleListScreen()),
        );
      },

      // =================================================
      // SCREEN 2: EXCEL
      // =================================================
      onNavigateToExcel: () {
        if (!_hasPermission(context, RoleManager.excel, permissions)) {
          return;
        }

        // Create ExcelCubit and load data only now.
        context.read<ExcelCubit>().loadExcelFiles();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExcelListScreen()),
        );
      },

      // =================================================
      // SCREEN 3: EMPLOYEES
      // =================================================
      onNavigateToEmployeesManagement: () {
        if (!_hasPermission(context, RoleManager.employees, permissions)) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmployeesManagementScreen()),
        );
      },

      // =================================================
      // SCREEN 4: CALCULATOR
      // =================================================
      onNavigateToCalculator: () {
        if (!_hasPermission(context, RoleManager.calculator, permissions)) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DozenCalculatorScreen()),
        );
      },

      // =================================================
      // SETTINGS
      // =================================================
      onNavigateToSettings: () {
        // Settings are loaded independently.
        // They do not trigger article or Excel loading.
        context.read<ManagementCubit>().loadSettings();

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ManagementScreen()),
        );
      },
    );
  }
}
