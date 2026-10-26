import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'auth_cubit.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String? _selectedUser;
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin(BuildContext context) {
    if (_selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('الرجاء اختيار اسم المستخدم', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }
    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('الرجاء إدخال كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    context.read<AuthCubit>().login(_selectedUser!, _passwordController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // خلفية رمادية فاتحة جداً تعطي طابعاً عصرياً
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: BlocConsumer<AuthCubit, AuthState>(
                listener: (context, state) {
                  if (state is AuthError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.message, style: const TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.red.shade700,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // الشعار بدون إطار دائري ليتنفس أكثر
                      Image.asset(
                        'assets/image/logo.png',
                        height: 120,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'مرحباً بك',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.indigo.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'بوابة تسجيل دخول الموظفين',
                        style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 40),

                      // البطاقة بتصميم ناعم ومسطح (Flat & Soft Shadow)
                      Container(
                        padding: const EdgeInsets.all(28.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.withOpacity(0.04),
                              blurRadius: 24,
                              spreadRadius: 8,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: _buildCardContent(context, state),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(BuildContext context, AuthState state) {
    if (state is AuthInitial || state is AuthLoadingUsers) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Column(
          children: [
            CircularProgressIndicator(color: Colors.indigo.shade400),
            const SizedBox(height: 20),
            Text('جاري تحميل بيانات النظام...', style: TextStyle(color: Colors.blueGrey.shade400, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (state is AuthError && state.message.contains('فشل الاتصال')) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.wifi_off_rounded, size: 40, color: Colors.red.shade400),
            ),
            const SizedBox(height: 16),
            Text(state.message, textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade50,
                foregroundColor: Colors.indigo.shade700,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () => context.read<AuthCubit>().fetchUsersFromServer(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    List<AppUser> users = [];
    bool isLoggingIn = false;

    if (state is AuthUsersLoaded) {
      users = state.users;
    } else if (state is AuthLoggingIn) {
      users = state.users;
      isLoggingIn = true;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('اسم المستخدم', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade800)),
            IconButton(
              icon: Icon(Icons.sync_rounded, color: Colors.indigo.shade300, size: 22),
              tooltip: 'تحديث قائمة المستخدمين',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: isLoggingIn ? null : () {
                setState(() => _selectedUser = null);
                context.read<AuthCubit>().fetchUsersFromServer();
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC), // لون رمادي مزرق فاتح جداً
            prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.indigo.shade300),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.blueGrey.shade400),
          hint: Text('اختر حسابك', style: TextStyle(color: Colors.blueGrey.shade300)),
          value: _selectedUser,
          items: users.map((u) {
            return DropdownMenuItem(
              value: u.username,
              child: Text(u.username, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade800)),
            );
          }).toList(),
          onChanged: isLoggingIn ? null : (val) {
            setState(() {
              _selectedUser = val;
            });
          },
        ),

        const SizedBox(height: 24),
        Text('كلمة المرور', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blueGrey.shade800)),
        const SizedBox(height: 10),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          enabled: !isLoggingIn,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.indigo.shade300),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.blueGrey.shade300),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            hintText: '••••••••',
            hintStyle: TextStyle(color: Colors.blueGrey.shade300, letterSpacing: 2),
          ),
        ),

        const SizedBox(height: 36),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            backgroundColor: Colors.indigo.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0, // إزالة الظل التقليدي للزر ليتناسب مع التصميم المسطح
          ),
          onPressed: isLoggingIn ? null : () => _handleLogin(context),
          child: isLoggingIn
              ? const SizedBox(
            height: 24, width: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          )
              : const Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
      ],
    );
  }
}