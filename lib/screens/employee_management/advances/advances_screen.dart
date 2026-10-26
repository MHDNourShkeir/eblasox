import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;

import 'advances_cubit.dart';

class AdvancesScreen extends StatelessWidget {
  const AdvancesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdvancesCubit()..loadEmployeesForCurrentAdmin(),
      child: const _AdvancesView(),
    );
  }
}

class _AdvancesView extends StatelessWidget {
  const _AdvancesView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة سلف الموظفين', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.indigo.shade700,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'تحديث البيانات',
              onPressed: () => context.read<AdvancesCubit>().loadEmployeesForCurrentAdmin(),
            ),
          ],
        ),
        body: BlocConsumer<AdvancesCubit, AdvancesState>(
          listener: (context, state) {
            if (state is AdvancesError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message), backgroundColor: Colors.red),
              );
            } else if (state is AdvancesExportSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تخريج السلف إلى ملف الإكسل بنجاح!'), backgroundColor: Colors.green),
              );
            }
          },
          builder: (context, state) {
            if (state is AdvancesInitial || state is AdvancesLoading) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text('جاري تحميل حالة السلف وبيانات الموظفين...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            List<EmployeeAdvance> employees = [];
            List<double> availableAmounts = [];
            bool isOpen = false;
            bool isExporting = false;
            bool hasSubmittedToday = false;

            if (state is AdvancesLoaded) {
              employees = state.employees;
              isOpen = state.isOpen;
              availableAmounts = state.availableAmounts;
              hasSubmittedToday = state.hasSubmittedToday;
            } else if (state is AdvancesExportSuccess) {
              employees = state.employees;
              isOpen = state.isOpen;
              availableAmounts = state.availableAmounts;
              hasSubmittedToday = state.hasSubmittedToday;
            } else if (state is AdvancesExporting) {
              employees = state.employees;
              isOpen = state.isOpen;
              availableAmounts = state.availableAmounts;
              hasSubmittedToday = state.hasSubmittedToday;
              isExporting = true;
            }

            if (hasSubmittedToday) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_rounded, size: 100, color: Colors.indigo.shade500),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'تم تقديم السلف بنجاح',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'لقد قمت برفع سلف قسمك مسبقاً.\nلا يمكن تقديم الطلبات أكثر من مرة واحدة \n اذا كان هناك اي تعديل يرجى مراجعة الإدارة وشكرا .',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            // CLOSED BY MANAGEMENT STATE
            if (!isOpen) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.lock_clock_rounded, size: 100, color: Colors.red.shade300),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'نظام السلف مغلق حالياً',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'يرجى مراجعة الإدارة لفتح نظام السلف\nأو المحاولة في وقت لاحق.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            if (employees.isEmpty && !isExporting) {
              return const Center(child: Text('لا يوجد موظفين مسجلين تحت إدارتك.'));
            }

            double totalAdvances = employees.fold(0.0, (sum, emp) => sum + emp.amount);
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: employees.length,
                    itemBuilder: (context, index) {
                      final emp = employees[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Icon(Icons.person, color: Colors.indigo.shade600),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<double>(
                                  isExpanded: true,
                                  initialValue: emp.amount > 0 ? emp.amount : null,
                                  decoration: InputDecoration(
                                    labelText: 'المبلغ',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  hint: const Text('اختر', style: TextStyle(fontSize: 12)),
                                  items: [
                                    const DropdownMenuItem<double>(
                                        value: 0.0,
                                        child: Text('لا يوجد', style: TextStyle(color: Colors.grey, fontSize: 13))
                                    ),
                                    ...availableAmounts.map((amt) => DropdownMenuItem<double>(
                                      value: amt,
                                      child: Text(
                                          intl.NumberFormat('#,##0').format(amt),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)
                                      ),
                                    )).toList(),
                                  ],
                                  onChanged: isExporting ? null : (val) {
                                    context.read<AdvancesCubit>().updateAdvanceAmount(emp.id, val ?? 0.0);
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('إجمالي السلف المطلوبة:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          Text(
                            '${intl.NumberFormat('#,##0').format(totalAdvances)} ل.س',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.indigo.shade800),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isExporting || totalAdvances == 0
                            ? null
                            : () => context.read<AdvancesCubit>().exportAdvances(),
                        icon: isExporting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.file_upload, color: Colors.white),
                        label: Text(
                          isExporting ? 'جاري التخريج...' : 'تخريج السلف',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}