import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smb_connect/smb_connect.dart';

// 🚀 استدعاء مدير الإعدادات المركزية
import '../../../core/config_sync_manager/config_sync_manager.dart';


class EmployeeAdvance {
  final String id;
  final String name;
  final String admin;
  double amount;

  EmployeeAdvance({
    required this.id,
    required this.name,
    required this.admin,
    this.amount = 0.0
  });
}

// --- States ---
abstract class AdvancesState {}
class AdvancesInitial extends AdvancesState {}
class AdvancesLoading extends AdvancesState {}
class AdvancesLoaded extends AdvancesState {
  final List<EmployeeAdvance> employees;
  final bool isOpen;
  final List<double> availableAmounts;
  final bool hasSubmittedToday;
  AdvancesLoaded(this.employees, {required this.isOpen, required this.availableAmounts, required this.hasSubmittedToday});
}
class AdvancesExporting extends AdvancesState {
  final List<EmployeeAdvance> employees;
  final bool isOpen;
  final List<double> availableAmounts;
  final bool hasSubmittedToday;
  AdvancesExporting(this.employees, {required this.isOpen, required this.availableAmounts, required this.hasSubmittedToday});
}
class AdvancesExportSuccess extends AdvancesState {
  final List<EmployeeAdvance> employees;
  final bool isOpen;
  final List<double> availableAmounts;
  final bool hasSubmittedToday;
  AdvancesExportSuccess(this.employees, {required this.isOpen, required this.availableAmounts, required this.hasSubmittedToday});
}
class AdvancesError extends AdvancesState {
  final String message;
  AdvancesError(this.message);
}

// --- Cubit ---
class AdvancesCubit extends Cubit<AdvancesState> {
  AdvancesCubit() : super(AdvancesInitial());

  List<EmployeeAdvance> _cachedEmployees = [];
  bool _isAdvancesOpen = false;
  bool _hasSubmittedToday = false;
  List<double> _availableAmounts = [];
  String _currentAdmin = '';

  Future<void> loadEmployeesForCurrentAdmin() async {
    emit(AdvancesLoading());
    try {
      final prefs = await SharedPreferences.getInstance();

      // 🚀 جلب المسارات من الإعدادات الديناميكية بدلاً من الثابتة
      final host = await ConfigSyncManager.getHost();
      final networkUser = await ConfigSyncManager.getUsername();
      final networkPass = await ConfigSyncManager.getPassword();
      final configFilePath = await ConfigSyncManager.getConfigFilePath();
      final advancesFilePath = await ConfigSyncManager.getAdvancesFilePath();

      // اسم المستخدم ما زال يجلب محلياً لأنه يتغير حسب من سجل الدخول
      _currentAdmin = prefs.getString('loggedInUser') ?? '';

      if (_currentAdmin.isEmpty) {
        emit(AdvancesError('لم يتم العثور على اسم المستخدم المسجل. يرجى تسجيل الدخول مجدداً.'));
        return;
      }

      final connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: networkUser,
        password: networkPass,
      );

      // 1. قراءة ملف الإعدادات
      final configFileObj = await connection.file(configFilePath);
      final configStream = await connection.openRead(configFileObj);
      final List<int> configBytesList = [];
      await for (var chunk in configStream) {
        configBytesList.addAll(chunk);
      }
      final configExcel = Excel.decodeBytes(Uint8List.fromList(configBytesList));

      _isAdvancesOpen = false;
      _availableAmounts = [];
      _hasSubmittedToday = false;

      // 🚀 قراءة إعدادات السلف والمبالغ من ورقة advances_management
      if (configExcel.tables.containsKey('advances_management')) {
        final advancesSheet = configExcel.tables['advances_management']!;

        // قراءة الحالة العامة للسلف من الخلية B1 (العمود 1، الصف 0)
        final openCell = advancesSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 0)).value?.toString().trim().toUpperCase();
        if (openCell == 'YES') {
          _isAdvancesOpen = true;
        }

        // البحث عن مبالغ المدير الحالي
        // نبدأ الحلقة من الصف الثاني أي index 1 (الصف A2 وما بعده)
        for (int i = 1; i < advancesSheet.maxRows; i++) {
          final adminName = advancesSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString().trim();

          // إذا وجدنا سطر المدير الحالي
          if (adminName == _currentAdmin) {
            // نقرأ كل الأعمدة التي بجانبه (ابتداءً من العمود B أي index 1)
            for (int j = 1; j < advancesSheet.maxColumns; j++) {
              final amtStr = advancesSheet.cell(CellIndex.indexByColumnRow(columnIndex: j, rowIndex: i)).value?.toString().replaceAll(',', '').trim();

              if (amtStr != null && amtStr.isNotEmpty) {
                final amt = double.tryParse(amtStr);
                if (amt != null) {
                  _availableAmounts.add(amt); // إضافة المبلغ لقائمة هذا المدير
                }
              }
            }
            break; // نوقف البحث لأننا وجدنا المدير المطلوب وأخذنا مبالغه
          }
        }
      }

      // قراءة أسماء الموظفين
      if (configExcel.tables.containsKey('employees_managment')) {
        final sheet = configExcel.tables['employees_managment']!;
        List<EmployeeAdvance> loadedEmployees = [];

        for (int i = 1; i < sheet.maxRows; i++) {
          final adminCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i)).value?.toString().trim() ?? '';
          final idCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i)).value?.toString().trim() ?? '';
          final nameCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: i)).value?.toString().trim() ?? '';

          if (adminCell == _currentAdmin && idCell.isNotEmpty) {
            loadedEmployees.add(EmployeeAdvance(id: idCell, name: nameCell, admin: adminCell));
          }
        }
        _cachedEmployees = loadedEmployees;
      }

      // 🚀 التحقق مما إذا كان المدير قد قام بالتخريج اليوم (لمنع التكرار)
      try {
        final advFileObj = await connection.file(advancesFilePath);
        final advStream = await connection.openRead(advFileObj);
        final List<int> advBytesList = [];
        await for (var chunk in advStream) {
          advBytesList.addAll(chunk);
        }

        if (advBytesList.isNotEmpty) {
          final advExcel = Excel.decodeBytes(Uint8List.fromList(advBytesList));
          final now = DateTime.now();
          final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
          final sheetName = '$_currentAdmin $dateStr';

          // إذا وجدنا ورقة بتاريخ اليوم وباسم هذا المدير، نغلق الشاشة
          if (advExcel.tables.containsKey(sheetName)) {
            _hasSubmittedToday = true;
          }
        }
      } catch (e) {
        // إذا لم يكن الملف موجوداً، فهذا يعني أنه لم يتم التخريج مسبقاً
      }

      await connection.close();
      emit(AdvancesLoaded(_cachedEmployees, isOpen: _isAdvancesOpen, availableAmounts: _availableAmounts, hasSubmittedToday: _hasSubmittedToday));

    } catch (e) {
      emit(AdvancesError('حدث خطأ أثناء الاتصال أو جلب البيانات: $e'));
    }
  }

  void updateAdvanceAmount(String empId, double amount) {
    if (state is AdvancesLoaded || state is AdvancesExportSuccess) {
      final index = _cachedEmployees.indexWhere((emp) => emp.id == empId);
      if (index != -1) {
        _cachedEmployees[index].amount = amount;
      }
      emit(AdvancesLoaded(List.from(_cachedEmployees), isOpen: _isAdvancesOpen, availableAmounts: _availableAmounts, hasSubmittedToday: _hasSubmittedToday));
    }
  }

  Future<void> exportAdvances() async {
    emit(AdvancesExporting(_cachedEmployees, isOpen: _isAdvancesOpen, availableAmounts: _availableAmounts, hasSubmittedToday: _hasSubmittedToday));

    try {
      final employeesToExport = _cachedEmployees.where((emp) => emp.amount > 0).toList();

      if (employeesToExport.isEmpty) {
        emit(AdvancesError('لم تقم بإدخال أي سلف للتخريج!'));
        emit(AdvancesLoaded(_cachedEmployees, isOpen: _isAdvancesOpen, availableAmounts: _availableAmounts, hasSubmittedToday: _hasSubmittedToday));
        return;
      }

      // 🚀 الاعتماد على الإعدادات الديناميكية أثناء التخريج
      final host = await ConfigSyncManager.getHost();
      final networkUser = await ConfigSyncManager.getUsername();
      final networkPass = await ConfigSyncManager.getPassword();
      final advancesFilePath = await ConfigSyncManager.getAdvancesFilePath();

      final connection = await SmbConnect.connectAuth(
        host: host,
        domain: '',
        username: networkUser,
        password: networkPass,
      );

      final fileObj = await connection.file(advancesFilePath);
      List<int> bytesList = [];
      try {
        final stream = await connection.openRead(fileObj);
        await for (var chunk in stream) {
          bytesList.addAll(chunk);
        }
      } catch (e) { }

      Excel excel;
      if (bytesList.isNotEmpty) {
        excel = Excel.decodeBytes(Uint8List.fromList(bytesList));
      } else {
        excel = Excel.createExcel();
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final sheetName = '$_currentAdmin $dateStr';

      final sheet = excel[sheetName];

      sheet.appendRow([
        TextCellValue('الرقم'),
        TextCellValue('الاسم'),
        TextCellValue('المبلغ'),
      ]);

      for (var emp in employeesToExport) {
        sheet.appendRow([
          TextCellValue(emp.id),
          TextCellValue(emp.name),
          DoubleCellValue(emp.amount),
        ]);
      }

      final excelBytes = excel.encode()!;

      try { await connection.delete(fileObj); } catch (_) {}

      final newFileObj = await connection.createFile(advancesFilePath);
      final sink = await connection.openWrite(newFileObj);
      sink.add(excelBytes);
      await sink.close();
      await connection.close();

      for (var emp in _cachedEmployees) {
        emp.amount = 0.0;
      }

      // 🚀 إغلاق الواجهة فوراً بعد نجاح التخريج
      _hasSubmittedToday = true;

      emit(AdvancesExportSuccess(_cachedEmployees, isOpen: _isAdvancesOpen, availableAmounts: _availableAmounts, hasSubmittedToday: _hasSubmittedToday));

    } catch (e) {
      emit(AdvancesError('فشل في تخريج السلف: $e'));
      emit(AdvancesLoaded(_cachedEmployees, isOpen: _isAdvancesOpen, availableAmounts: _availableAmounts, hasSubmittedToday: _hasSubmittedToday));
    }
  }
}