import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/config_sync_manager/config_sync_manager.dart';
import 'article_cubit.dart';
import 'image_screen.dart';



class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _remoteFolderPath = ''; // لحفظ المسار الأساسي لترتيب النصوص

  @override
  void initState() {
    super.initState();
    _loadRemotePath();
  }

  // 🚀 جلب المسار الأساسي ليتم استخدامه في إخفاء الجزء الطويل من المسار في الواجهة
  Future<void> _loadRemotePath() async {
    _remoteFolderPath = await ConfigSyncManager.getArticleRemotePath();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🚀 جلب بيانات الاتصال ديناميكياً قبل فتح نافذة المعاينة
  void _showImagePreview(BuildContext context, ArticleItem article) async {
    final host = await ConfigSyncManager.getHost();
    final username = await ConfigSyncManager.getUsername();
    final password = await ConfigSyncManager.getPassword();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => ImagePreviewDialog(
        host: host,
        username: username,
        password: password,
        fullFilePath: article.fullPath,
        fileName: article.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          iconTheme: const IconThemeData(color: Colors.white),
          backgroundColor: Colors.blueAccent,
          title: const Text('ابحث عن صورة موديل', style: TextStyle(color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'إعادة مسح المجلدات',
              onPressed: () => context.read<ArticleCubit>().loadArticles(force: true),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'اكتب اسم الموديل للبحث...',
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
                child: BlocBuilder<ArticleCubit, ArticleState>(
                  builder: (context, state) {
                    if (state is ArticleLoading) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('جاري الاتصال وفهرسة مجلدات الصور...'),
                          ],
                        ),
                      );
                    }
                    if (state is ArticleError) {
                      return Center(
                        child: Text(
                          state.message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      );
                    }
                    if (state is ArticleLoaded) {
                      final query = _searchController.text.trim().toLowerCase();
                      if (query.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'اكتب اسم الموديل في الأعلى لعرض النتائج',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '💡 اضغط مطولاً على أي عنصر لمعاينة الصورة سريعة',
                                style: TextStyle(color: Colors.blueGrey, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }

                      final filtered = state.articles.where((a) => a.name.toLowerCase().contains(query)).toList();
                      filtered.sort((a, b) => a.name.compareTo(b.name));

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text(
                            'لم يتم العثور على موديلات تطابق بحثك',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final article = filtered[index];

                          // 🚀 تنظيف المسار الفرعي باستخدام المتغير المجلوب
                          final subtitleText = _remoteFolderPath.isNotEmpty
                              ? article.fullPath.replaceFirst(_remoteFolderPath, '')
                              : article.fullPath;

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: const Icon(Icons.image, color: Colors.blue),
                              title: Text(article.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: subtitleText.isNotEmpty
                                  ? Text(subtitleText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
                                  : null,
                              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () async {
                                // 🚀 جلب بيانات الاتصال ديناميكياً قبل فتح الصورة بحجم كامل
                                final host = await ConfigSyncManager.getHost();
                                final username = await ConfigSyncManager.getUsername();
                                final password = await ConfigSyncManager.getPassword();

                                if (!context.mounted) return;

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ImageViewerScreen(
                                      host: host,
                                      username: username,
                                      password: password,
                                      fullFilePath: article.fullPath,
                                      fileName: article.name,
                                    ),
                                  ),
                                );
                              },
                              onLongPress: () => _showImagePreview(context, article),
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
    );
  }
}