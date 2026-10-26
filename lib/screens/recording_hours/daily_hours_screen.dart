import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' as intl;
import 'daily_hours_cubit.dart';
import 'worker_hour_model.dart';

class DailyHoursScreen extends StatefulWidget {
  final String supervisorSection;

  const DailyHoursScreen({super.key, required this.supervisorSection});

  @override
  _DailyHoursScreenState createState() => _DailyHoursScreenState();
}

class _DailyHoursScreenState extends State<DailyHoursScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    context.read<DailyHoursCubit>().loadDailyHours(_selectedDate, widget.supervisorSection);
  }

  void _selectDate(BuildContext context) async {
    final now = DateTime.now();
    // تحديد اليوم الأول من الشهر الحالي
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDayOfMonth, // يمنع العودة لأشهر أو سنوات سابقة
      lastDate: now,              // يمنع التقدم لأيام أو أشهر أو سنوات قادمة
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade800,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      context.read<DailyHoursCubit>().loadDailyHours(picked, widget.supervisorSection);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('تسجيل الدوام', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.indigo.shade800,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [

            IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              tooltip: 'تغيير التاريخ',
              onPressed: () => _selectDate(context),
            )
          ],
        ),
        body: Column(
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.indigo.shade800,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تاريخ اليوم',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        intl.DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.read<DailyHoursCubit>().setAllToNine(),
                    icon: const Icon(Icons.fact_check_rounded, color: Colors.indigo),
                    label: const Text(
                      'تثبيت الكل (9)',
                      style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Workers List
            Expanded(
              child: BlocConsumer<DailyHoursCubit, DailyHoursState>(
                listener: (context, state) {
                  if (state is DailyHoursSaveSuccess) {
                    _showSnackBar('تم حفظ الدوام بنجاح!', Colors.green.shade700);
                  } else if (state is DailyHoursError) {
                    _showSnackBar(state.message, Colors.red.shade700);
                  }
                },
                builder: (context, state) {
                  if (state is DailyHoursLoading || state is DailyHoursSaving) {
                    return Center(
                      child: CircularProgressIndicator(color: Colors.indigo.shade800),
                    );
                  } else if (state is DailyHoursLoaded) {
                    if (state.workers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off_rounded, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'لا يوجد عمال في هذا القسم\nأو لم يتم فتح ملف هذا اليوم بعد.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), // padding bottom for FAB
                      itemCount: state.workers.length,
                      itemBuilder: (context, index) {
                        final worker = state.workers[index];
                        return _buildWorkerCard(worker, context);
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),

        // FAB
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.read<DailyHoursCubit>().saveDailyHours(),
          label: const Text('حفظ الإدخالات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
          icon: const Icon(Icons.save_rounded, color: Colors.white),
          backgroundColor: Colors.green.shade600,
          elevation: 4,
        ),
      ),
    );
  }

  Widget _buildWorkerCard(WorkerHour worker, BuildContext context) {
    bool isAbsent = worker.hours == null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isAbsent ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isAbsent
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isAbsent ? Colors.grey.shade300 : Colors.transparent,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Worker Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    worker.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isAbsent ? Colors.grey.shade500 : Colors.black87,
                      decoration: isAbsent ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (isAbsent) ...[
                    const SizedBox(height: 4),
                    Text(
                      'غائب',
                      style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),

            // Controls
            Row(
              children: [
                // Clear/Absent Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => context.read<DailyHoursCubit>().updateWorkerHour(worker.id, null),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.person_off_rounded,
                        color: isAbsent ? Colors.grey.shade400 : Colors.red.shade300,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Stepper Pill
                Container(
                  decoration: BoxDecoration(
                    color: isAbsent ? Colors.transparent : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isAbsent ? Colors.grey.shade300 : Colors.indigo.shade100),
                  ),
                  child: Row(
                    children: [
                      // Minus Button
                      InkWell(
                        onTap: () {
                          double current = worker.hours ?? 9.0;
                          if (current > 0) {
                            context.read<DailyHoursCubit>().updateWorkerHour(worker.id, current - 0.5);
                          }
                        },
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Icon(Icons.remove, color: isAbsent ? Colors.grey.shade400 : Colors.indigo.shade700, size: 20),
                        ),
                      ),

                      // Value Text
                      Container(
                        constraints: const BoxConstraints(minWidth: 36),
                        alignment: Alignment.center,
                        child: Text(
                          isAbsent ? '--' : worker.hours.toString().replaceAll(RegExp(r'\.0$'), ''),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isAbsent ? Colors.grey.shade500 : Colors.indigo.shade900,
                          ),
                        ),
                      ),

                      // Plus Button
                      InkWell(
                        onTap: () {
                          double current = worker.hours ?? 8.5; // Starts at 9 if they were absent
                          context.read<DailyHoursCubit>().updateWorkerHour(worker.id, current + 0.5);
                        },
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Icon(Icons.add, color: isAbsent ? Colors.grey.shade400 : Colors.indigo.shade700, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}