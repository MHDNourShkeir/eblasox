import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'order_cubit.dart';


class OrderTemplateScreen extends StatelessWidget {
  final Uint8List excelBytes;

  const OrderTemplateScreen({super.key, required this.excelBytes});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => OrderCubit()..parseExcel(excelBytes),
      child: const _OrderTemplateView(),
    );
  }
}

class _OrderTemplateView extends StatelessWidget {
  const _OrderTemplateView();

  void _openZoomableImage(BuildContext context, Uint8List imageBytes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(imageBytes: imageBytes),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrderCubit, OrderState>(
      builder: (context, state) {
        if (state is OrderLoading || state is OrderInitial) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (state is OrderError) {
          return Scaffold(
            appBar: AppBar(title: const Text('خطأ')),
            body: Center(child: Text(state.message, style: const TextStyle(color: Colors.red))),
          );
        }

        final loadedState = state as OrderLoaded;
        final orderDetails = loadedState.orderDetails;
        final groupedItems = loadedState.groupedItems;
        final orderImage = loadedState.orderImage;
        final mainModelNumber = loadedState.mainModelNumber;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: Colors.grey.shade100,
            appBar: AppBar(
              title: Text('طلب تصنيع: ${orderDetails.manufacturingId}'),
              backgroundColor: Colors.blue.shade800,
            ),
            body: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (orderImage != null)
                          GestureDetector(
                            onTap: () => _openZoomableImage(context, orderImage),
                            child: Stack(
                              alignment: Alignment.bottomLeft,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    orderImage,
                                    width: double.infinity,
                                    height: 280,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.zoom_in, color: Colors.white, size: 18),
                                      SizedBox(width: 4),
                                      Text('انقر للتكبير', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey)),
                          ),

                        const SizedBox(height: 14),

                        if (mainModelNumber.isNotEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade900,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.shade900.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'رقم الموديل: $mainModelNumber',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 16),

                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                _buildInfoRow('الاسم التمويني', orderDetails.notesGender),
                                _buildInfoRow('رقم طلب التصنيع', orderDetails.manufacturingId),
                                _buildInfoRow('الزبون', orderDetails.customer),
                                _buildInfoRow('اسم الطلب', orderDetails.orderName),
                                _buildInfoRow('رمز الاتكيت', orderDetails.labelCode),
                                _buildInfoRow('التشكيلات', orderDetails.designs),
                                _buildInfoRow('ملاحظات الامبلاج', orderDetails.packagingNotes),
                                _buildInfoRow('نوع الخيط', orderDetails.yarnType),
                                _buildInfoRow('طول الساق', orderDetails.legLength),
                                _buildInfoRow('الخط', orderDetails.line),
                                _buildInfoRow('ملاحظات المكنات', orderDetails.machineNotes),
                                _buildInfoRow('خدمات خارجية', orderDetails.externalServices),
                                _buildInfoRow('رمز العلبة', orderDetails.boxCode),
                                _buildInfoRow('مجموع الدزينة', orderDetails.totalDozen),
                                _buildInfoRow('الموسم', orderDetails.season),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'تفاصيل الأصناف والكميات',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: groupedItems.length,
                      itemBuilder: (context, groupIndex) {
                        final group = groupedItems[groupIndex];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.straighten, size: 18, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Text(
                                      'القياس:',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                    Spacer(),
                                    Text(
                                      group.size,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: group.items.length,
                                separatorBuilder: (context, index) => const Divider(height: 1, indent: 12, endIndent: 12),
                                itemBuilder: (context, itemIndex) {
                                  final item = group.items[itemIndex];
                                  return Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('اللون الأساسي:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                  Text(
                                                    item.colorName,
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: [
                                                      if (item.colorCode.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: Colors.amber.shade100,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            'رقم اللون: ${item.colorCode}',
                                                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                                          ),
                                                        ),
                                                      if (item.secondaryColor.isNotEmpty)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                          decoration: BoxDecoration(
                                                            color: Colors.teal.shade50,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            'ثانوي: ${item.secondaryColor}',
                                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                children: [
                                                  const Text('العدد', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                                  Text(
                                                    item.count,
                                                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (item.distribution.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  children: [
                                                    const Text('التوزيع', style: TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.bold)),
                                                    Text(
                                                      item.distribution,
                                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.purple.shade900),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if (item.group != "0" && item.group.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'المجموعة: ${item.group}',
                                            style: TextStyle(fontSize: 12, color: Colors.blue.shade800, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 8),
      ],
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final Uint8List imageBytes;

  const FullScreenImageViewer({super.key, required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('استعراض الصورة', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5.0,
          child: Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
  }
}