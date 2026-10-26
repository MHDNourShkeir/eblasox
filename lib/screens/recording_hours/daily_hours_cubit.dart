import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smb_connect/smb_connect.dart';

// 🚀 استدعاء مدير الإعدادات المركزية
import '../../../core/config_sync_manager/config_sync_manager.dart';
import 'worker_hour_model.dart';

// --- States ---
abstract class DailyHoursState {}
class DailyHoursInitial extends DailyHoursState {}
class DailyHoursLoading extends DailyHoursState {}
class DailyHoursLoaded extends DailyHoursState {
  final DateTime selectedDate;
  final List<WorkerHour> workers;
  DailyHoursLoaded(this.selectedDate, this.workers);
}
class DailyHoursError extends DailyHoursState {
  final String message;
  DailyHoursError(this.message);
}
class DailyHoursSaving extends DailyHoursState {}
class DailyHoursSaveSuccess extends DailyHoursState {}

// --- Cubit ---
class DailyHoursCubit extends Cubit<DailyHoursState> {
  DailyHoursCubit() : super(DailyHoursInitial());

  String _supervisorSection = '';

  String _getDynamicFileName(DateTime date) {
    return '${DateFormat('MM-yyyy').format(date)}.xlsx';
  }

  // 🚀 دالة لاختلاق مسار الدوام من مسار الـ Config (تماماً كما تفعل المكتبة)
  Future<String> _getDailyHoursFilePath(DateTime date) async {
    final configFilePath = await ConfigSyncManager.getConfigFilePath(); // مثلاً: البرمجة الجديدة/CONFIG/config.xlsx

    // استبدال كلمة config.xlsx باسم الملف الجديد (مثلاً 10-2026.xlsx)
    int lastSlashIndex = configFilePath.lastIndexOf(r'\');
    if (lastSlashIndex == -1) {
      lastSlashIndex = configFilePath.lastIndexOf('/'); // دعم السلاش العادية
    }

    String baseFolder = '';
    if (lastSlashIndex != -1) {
      baseFolder = configFilePath.substring(0, lastSlashIndex);
    } else {
      baseFolder = r'البرمجة الجديدة\CONFIG';
    }

    return '$baseFolder\\${_getDynamicFileName(date)}'.replaceAll(r'\\', r'\');
  }

  Future<void> loadDailyHours(DateTime date, String supervisorSection) async {
    emit(DailyHoursLoading());
    _supervisorSection = supervisorSection;

    try {
      // 🚀 نفس أسلوب السلف 100%
      final host = await ConfigSyncManager.getHost();
      final networkUser = await ConfigSyncManager.getUsername();
      final networkPass = await ConfigSyncManager.getPassword();
      final dailyHoursFilePath = await _getDailyHoursFilePath(date);

      print('====================================');
      print('جاري محاولة الاتصال وقراءة الملف من المسار:');
      print(dailyHoursFilePath);
      print('====================================');

      // الاتصال بنفس الطريقة
      final connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: networkUser,
        password: networkPass,
      );

      // قراءة الملف بنفس الطريقة (openRead)
      final fileObj = await connection.file(dailyHoursFilePath);
      final stream = await connection.openRead(fileObj);
      final List<int> bytesList = [];
      await for (var chunk in stream) {
        bytesList.addAll(chunk);
      }

      if (bytesList.isEmpty) {
        emit(DailyHoursError('الملف فارغ أو غير موجود.'));
        await connection.close();
        return;
      }

      // فك التشفير
      var excel = Excel.decodeBytes(Uint8List.fromList(bytesList));
      String sheetName = DateFormat('MM-yyyy').format(date);

      var sheet = excel.tables[sheetName];
      if (sheet == null) {
        emit(DailyHoursError('ورقة العمل $sheetName غير موجودة داخل الملف.'));
        await connection.close();
        return;
      }

      List<WorkerHour> dailyWorkers = [];
      int targetColumnIndex = 3 + date.day;

      for (int i = 2; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty || row.length < 4) continue;

        String workerId = row[1]?.value?.toString().trim() ?? '';
        String workerName = row[2]?.value?.toString().trim() ?? '';
        String workerSection = row[3]?.value?.toString().trim() ?? '';

        // Strictly skip any row that lacks an ID or Name
        if (workerId.isEmpty || workerName.isEmpty) continue;

        if (workerSection == _supervisorSection) {
          double? currentHours;
          if (row.length > targetColumnIndex && row[targetColumnIndex]?.value != null) {
            currentHours = double.tryParse(row[targetColumnIndex]!.value.toString());
          }

          dailyWorkers.add(WorkerHour(
            id: workerId,
            name: workerName,
            section: workerSection,
            rowIndex: i,
            hours: currentHours,
          ));
        }
      }

      await connection.close();
      emit(DailyHoursLoaded(date, dailyWorkers));

    } catch (e) {
      emit(DailyHoursError('حدث خطأ أثناء الاتصال أو جلب البيانات: $e'));
    }
  }

  void updateWorkerHour(String workerId, double? newHour) {
    if (state is DailyHoursLoaded) {
      final currentState = state as DailyHoursLoaded;
      final updatedWorkers = currentState.workers.map((w) {
        if (w.id == workerId) {
          return w.copyWith(hours: newHour, clearHours: newHour == null);
        }
        return w;
      }).toList();
      emit(DailyHoursLoaded(currentState.selectedDate, updatedWorkers));
    }
  }

  void setAllToNine() {
    if (state is DailyHoursLoaded) {
      final currentState = state as DailyHoursLoaded;
      final updatedWorkers = currentState.workers.map((w) {
        if (w.hours == null) {
          return w.copyWith(hours: 9.0);
        }
        return w;
      }).toList();
      emit(DailyHoursLoaded(currentState.selectedDate, updatedWorkers));
    }
  }

  Future<void> saveDailyHours() async {
    if (state is! DailyHoursLoaded) return;

    final currentState = state as DailyHoursLoaded;
    final date = currentState.selectedDate;
    final workersToSave = currentState.workers;

    emit(DailyHoursSaving());

    try {
      // 🚀 نفس أسلوب التخريج (Export) في السلف 100%
      final host = await ConfigSyncManager.getHost();
      final networkUser = await ConfigSyncManager.getUsername();
      final networkPass = await ConfigSyncManager.getPassword();
      final dailyHoursFilePath = await _getDailyHoursFilePath(date);

      final connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: networkUser,
        password: networkPass,
      );

      final fileObj = await connection.file(dailyHoursFilePath);
      List<int> bytesList = [];
      try {
        final stream = await connection.openRead(fileObj);
        await for (var chunk in stream) {
          bytesList.addAll(chunk);
        }
      } catch (e) {
        emit(DailyHoursError('لا يمكن قراءة الملف للحفظ.'));
        await connection.close();
        return;
      }

      var excel = Excel.decodeBytes(Uint8List.fromList(bytesList));
      String sheetName = DateFormat('MM-yyyy').format(date);
      var sheet = excel.tables[sheetName]!;

      int targetColumnIndex = 3 + date.day;

      // 2. تطبيق التعديلات مع الحفاظ التام على التنسيق (الألوان والحدود)
      for (var worker in workersToSave) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(
          columnIndex: targetColumnIndex,
          rowIndex: worker.rowIndex,
        ));

        // 🚀 1. سحب التنسيق القديم (Style) للخلية والاحتفاظ به
        final oldStyle = cell.cellStyle;

        // 🚀 2. تعديل القيمة كنص (General)
        if (worker.hours == null) {
          cell.value = null; // مسح (غياب)
        } else {
          String val = worker.hours!.toString().replaceAll('.0', '');
          cell.value = TextCellValue(val);
        }

        // 🚀 3. إعادة التنسيق القديم للخلية كما كان بالضبط
        if (oldStyle != null) {
          cell.cellStyle = oldStyle;
        }
      }

      final excelBytes = excel.encode()!;

      try { await connection.delete(fileObj); } catch (_) {}

      final newFileObj = await connection.createFile(dailyHoursFilePath);
      final sink = await connection.openWrite(newFileObj);
      sink.add(excelBytes);
      await sink.close();
      await connection.close();

      emit(DailyHoursSaveSuccess());
      await loadDailyHours(date, _supervisorSection);

    } catch (e) {
      emit(DailyHoursError('فشل في حفظ البيانات: $e'));
    }
  }
}