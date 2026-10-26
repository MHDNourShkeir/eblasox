import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smb_connect/smb_connect.dart';
import '../../core/config_sync_manager/config_sync_manager.dart';
import 'excel_viewer_cubit.dart';
import 'order/order_template.dart';


class ExcelListScreen extends StatefulWidget {
  const ExcelListScreen({super.key});

  @override
  State<ExcelListScreen> createState() => _ExcelListScreenState();
}

class _ExcelListScreenState extends State<ExcelListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _remoteFolderPath = ''; // لحفظ المسار الأساسي لترتيب النصوص

  @override
  void initState() {
    super.initState();
    _loadRemotePath();
  }

  // 🚀 جلب مسار مجلد الإكسل الرئيسي ليتم استخدامه في ترتيب الواجهة
  Future<void> _loadRemotePath() async {
    _remoteFolderPath = await ConfigSyncManager.getExcelRemotePath();
    if (mounted) setState(() {});
  }

  Future<void> _openExcelFile(BuildContext context, ExcelFileItem fileItem) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('جاري تحميل تفاصيل الطلب...'),
              ],
            ),
          ),
        ),
      ),
    );

    SmbConnect? connection;
    try {
      // 🚀 جلب بيانات الاتصال ديناميكياً قبل الفتح
      final host = await ConfigSyncManager.getHost();
      final username = await ConfigSyncManager.getUsername();
      final password = await ConfigSyncManager.getPassword();

      connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: username,
        password: password,
      );

      final fileObj = await connection.file(fileItem.fullPath);
      final stream = await connection.openRead(fileObj);

      final List<int> bytesList = [];
      await for (var chunk in stream) {
        bytesList.addAll(chunk);
      }

      final bytes = Uint8List.fromList(bytesList);
      await connection.close();

      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTemplateScreen(
              excelBytes: bytes,
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحميل الملف: $e')),
        );
      }
      try {
        await connection?.close();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('ابحث عن طلب التصنيع', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'إعادة مسح المجلدات',
              onPressed: () => context.read<ExcelCubit>().loadExcelFiles(force: true),
            ),
          ],
        ),
        body: Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'اكتب اسم ملف الإكسل للبحث...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: BlocBuilder<ExcelCubit, ExcelState>(
                    builder: (context, state) {
                      if (state is ExcelLoading) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('جاري البحث عن ملفات الإكسل في الخادم...'),
                            ],
                          ),
                        );
                      }
                      if (state is ExcelError) {
                        return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
                      }
                      if (state is ExcelLoaded) {
                        final query = _searchController.text.trim().toLowerCase();
                        if (query.isEmpty) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.table_chart, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text(
                                  'اكتب اسم ملف الإكسل في الأعلى لعرض النتائج',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        }

                        final filtered = state.files.where((file) => file.name.toLowerCase().contains(query)).toList();
                        filtered.sort((a, b) => a.name.compareTo(b.name));

                        if (filtered.isEmpty) {
                          return const Center(
                            child: Text(
                              'لم يتم العثور على ملفات إكسل تطابق بحثك',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final fileItem = filtered[index];

                            // 🚀 تنظيف المسار باستخدام المتغير الديناميكي الذي جلبناه
                            final subtitleText = _remoteFolderPath.isNotEmpty
                                ? fileItem.fullPath.replaceFirst(_remoteFolderPath, '')
                                : fileItem.fullPath;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const Icon(Icons.table_view, color: Colors.green),
                                title: Text(fileItem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: subtitleText.isNotEmpty
                                    ? Text(subtitleText, style: TextStyle(fontSize: 12, color: Colors.grey.shade700))
                                    : null,
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                onTap: () => _openExcelFile(context, fileItem),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}