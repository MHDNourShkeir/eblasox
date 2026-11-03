import 'dart:typed_data';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:smb_connect/smb_connect.dart';

// 🚀 استدعاء مدير الإعدادات المركزية
import '../../../core/config_sync_manager/config_sync_manager.dart';
import 'worker_hour_model.dart';

// --- States ---
abstract class DailyHoursState {}
class DailyHoursNoChanges extends DailyHoursState {}
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
    // سيجلب المسار كما كتبته في الإكسل تماماً
    // تأكد أن المسار في الإكسل يطابق اسم المجلد الحقيقي على الكمبيوتر (الدوام أم daily-records)
    String basePath = await ConfigSyncManager.getDailyRecordsFilePath();

    // تركيب المسار بنفس الطريقة التي نجحت معك في 10-2026
    String finalPath = '$basePath\\${_getDynamicFileName(date)}';

    print('====================================');
    print('مسار الدوام المعتمد:');
    print(finalPath); // سيطبع: /Public/البرمجة الجديدة/CONFIG/daily-records\11-2026.xlsx
    print('====================================');

    return finalPath;
  }

  Future<void> loadDailyHours(DateTime date, String supervisorSection) async {
    emit(DailyHoursLoading());
    _supervisorSection = supervisorSection;

    try {
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

    SmbConnect? connection;

    try {
      final host = await ConfigSyncManager.getHost();
      final networkUser = await ConfigSyncManager.getUsername();
      final networkPass = await ConfigSyncManager.getPassword();

      final dailyHoursFilePath = await _getDailyHoursFilePath(date);

      connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: networkUser,
        password: networkPass,
      );

      // Read the current Excel file from the server.
      final fileObj = await connection.file(dailyHoursFilePath);

      final bytesList = <int>[];

      final stream = await connection.openRead(fileObj);

      await for (var chunk in stream) {
        bytesList.addAll(chunk);
      }

      if (bytesList.isEmpty) {
        emit(DailyHoursError('الملف فارغ أو غير موجود.'));
        return;
      }

      // Decode Excel.
      final excel = Excel.decodeBytes(
        Uint8List.fromList(bytesList),
      );

      final sheetName = DateFormat('MM-yyyy').format(date);

      final sheet = excel.tables[sheetName];

      if (sheet == null) {
        emit(DailyHoursError(
          'ورقة العمل $sheetName غير موجودة داخل الملف.',
        ));
        return;
      }

      final targetColumnIndex = 3 + date.day;

      // ==========================================
      // CHECK IF ANY DATA HAS ACTUALLY CHANGED
      // ==========================================

      bool hasChanges = false;

      for (final worker in workersToSave) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: targetColumnIndex,
            rowIndex: worker.rowIndex,
          ),
        );

        // Current value stored in Excel.
        final oldValue = cell.value?.toString().trim() ?? '';

        // New value entered in the application.
        final newValue = worker.hours;

        // Convert the old Excel value into a number.
        double? oldHours;

        if (oldValue.isNotEmpty) {
          oldHours = double.tryParse(oldValue);
        }

        // Compare old and new values.
        bool isSame;

        if (oldValue.isEmpty) {
          isSame = newValue == null;
        } else if (oldHours == null) {
          // An existing non-empty value that cannot be parsed
          // is treated as different.
          isSame = false;
        } else if (newValue == null) {
          isSame = false;
        } else {
          isSame = (oldHours - newValue).abs() < 0.000001;
        }

        if (!isSame) {
          hasChanges = true;
          break;
        }
      }

      // ==========================================
      // NO CHANGES: DO NOT SAVE THE EXCEL FILE
      // ==========================================

      if (!hasChanges) {
        await connection.close();
        connection = null;

        emit(DailyHoursNoChanges());

        // Restore the loaded state so the screen remains visible.
        emit(DailyHoursLoaded(date, workersToSave));

        return;
      }

      // ==========================================
      // CHANGES FOUND: UPDATE ONLY CHANGED CELLS
      // ==========================================

      for (final worker in workersToSave) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: targetColumnIndex,
            rowIndex: worker.rowIndex,
          ),
        );

        final oldValue = cell.value?.toString().trim() ?? '';

        double? oldHours;

        if (oldValue.isNotEmpty) {
          oldHours = double.tryParse(oldValue);
        }

        final newValue = worker.hours;

        bool isSame;

        if (oldValue.isEmpty) {
          isSame = newValue == null;
        } else if (oldHours == null) {
          isSame = false;
        } else if (newValue == null) {
          isSame = false;
        } else {
          isSame = (oldHours - newValue).abs() < 0.000001;
        }

        // Skip cells that haven't changed.
        if (isSame) continue;

        // Preserve existing cell formatting.
        final oldStyle = cell.cellStyle;

        if (newValue == null) {
          cell.value = null;
        } else {
          final val = newValue.toString().replaceAll('.0', '');
          cell.value = TextCellValue(val);
        }

        if (oldStyle != null) {
          cell.cellStyle = oldStyle;
        }
      }

      // ==========================================
      // SAVE EXCEL FILE
      // ==========================================

      final excelBytes = excel.encode();

      if (excelBytes == null) {
        emit(DailyHoursError('فشل في إنشاء ملف الإكسل.'));
        return;
      }

      try {
        await connection.delete(fileObj);
      } catch (_) {}

      final newFileObj = await connection.createFile(
        dailyHoursFilePath,
      );

      final sink = await connection.openWrite(newFileObj);

      sink.add(excelBytes);

      await sink.close();

      await connection.close();
      connection = null;

      emit(DailyHoursSaveSuccess());

      await loadDailyHours(date, _supervisorSection);

    } catch (e) {
      emit(DailyHoursError('فشل في حفظ البيانات: $e'));
    } finally {
      try {
        await connection?.close();
      } catch (_) {}
    }
  }

}