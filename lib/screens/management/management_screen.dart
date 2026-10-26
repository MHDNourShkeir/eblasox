import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'mangement_cubit.dart';

class ManagementScreen extends StatelessWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ManagementCubit()..loadSettings(),
      child: const _ManagementView(),
    );
  }
}

class _ManagementView extends StatefulWidget {
  const _ManagementView();

  @override
  State<_ManagementView> createState() => _ManagementViewState();
}

class _ManagementViewState extends State<_ManagementView> {
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isInitialized = false;

  void _initializeControllers(ManagementLoaded state) {
    if (!_isInitialized) {
      _hostController.text = state.host;
      _userController.text = state.username;
      _passController.text = state.password;
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إعدادات الطوارئ والشبكة', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.blue.shade800,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<ManagementCubit, ManagementState>(
          listener: (context, state) {
            if (state is ManagementSaved) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم حفظ إعدادات الشبكة بنجاح!'), backgroundColor: Colors.green),
              );
              Navigator.pop(context, true);
            } else if (state is ManagementError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            }
          },
          builder: (context, state) {
            if (state is ManagementLoading || state is ManagementInitial) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is ManagementLoaded) {
              _initializeControllers(state);
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.yellow.shade700),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'تنبيه: هذه الإعدادات مخصصة فقط في حال تغيير IP السيرفر ولا يمكن للتطبيق الوصول لملف الإعدادات المركزي.',
                            style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text('إعدادات الاتصال بالسيرفر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue)),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _hostController,
                    decoration: InputDecoration(
                      labelText: 'IP الخادم (Host)',
                      prefixIcon: const Icon(Icons.computer),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _userController,
                    decoration: InputDecoration(
                      labelText: 'اسم مستخدم الشبكة',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة مرور الشبكة',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blue.shade800,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final currentState = context.read<ManagementCubit>().state;

                      if (currentState is ManagementLoaded) {
                        context.read<ManagementCubit>().saveSettings(
                          host: _hostController.text,
                          username: _userController.text,
                          password: _passController.text,
                          // يتم إرسال باقي المسارات كما هي من الـ State لكي لا يتم تفريغها من الكيوبت
                          remoteFolderPath: currentState.remoteFolderPath,
                          subfoldersText: currentState.targetSubfolders.join('\n'),
                          excelRemoteFolderPath: currentState.excelRemoteFolderPath,
                          excelSubfoldersText: currentState.excelTargetSubfolders.join('\n'),
                          adminPassword: currentState.adminPassword,
                          context: context,
                        );
                      }
                    },
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('حفظ إعدادات الشبكة وإعادة التحميل', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}