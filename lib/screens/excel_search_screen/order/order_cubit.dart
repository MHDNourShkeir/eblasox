import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:excel/excel.dart';
import 'package:archive/archive.dart';

class OrderDetails {
  final String artNum;
  final String orderDate;
  final String yarnType;
  final String legLength;
  final String line;
  final String notesGender;
  final String machineType;
  final String machineNotes;
  final String packagingNotes;
  final String externalServices;
  final String machineDelivery;
  final String clientDelivery;
  final String labelCode;
  final String boxCode;
  final String manufacturingId;
  final String orderName;
  final String designs;
  final String totalDozen;
  final String dozenWeight;
  final String fileName;
  final String season;
  final String customer;

  OrderDetails({
    required this.artNum,
    required this.orderDate,
    required this.yarnType,
    required this.legLength,
    required this.line,
    required this.notesGender,
    required this.machineType,
    required this.machineNotes,
    required this.packagingNotes,
    required this.externalServices,
    required this.machineDelivery,
    required this.clientDelivery,
    required this.labelCode,
    required this.boxCode,
    required this.manufacturingId,
    required this.orderName,
    required this.designs,
    required this.totalDozen,
    required this.dozenWeight,
    required this.fileName,
    required this.season,
    required this.customer,
  });
}

class OrderItem {
  final String modelNumber;
  final String size;
  final String colorName;
  final String colorCode;
  final String secondaryColor;
  final String group;
  final String count;
  final String distribution;

  OrderItem({
    required this.modelNumber,
    required this.size,
    required this.colorName,
    required this.colorCode,
    required this.secondaryColor,
    required this.group,
    required this.count,
    required this.distribution,
  });
}

class SizeGroup {
  final String size;
  final List<OrderItem> items;

  SizeGroup({required this.size, required this.items});
}

// States
abstract class OrderState {}
class OrderInitial extends OrderState {}
class OrderLoading extends OrderState {}
class OrderLoaded extends OrderState {
  final OrderDetails orderDetails;
  final List<SizeGroup> groupedItems;
  final Uint8List? orderImage;
  final String mainModelNumber;

  OrderLoaded({
    required this.orderDetails,
    required this.groupedItems,
    required this.orderImage,
    required this.mainModelNumber,
  });
}
class OrderError extends OrderState {
  final String message;
  OrderError(this.message);
}

// Cubit
class OrderCubit extends Cubit<OrderState> {
  OrderCubit() : super(OrderInitial());

  Future<void> parseExcel(Uint8List excelBytes) async {
    emit(OrderLoading());
    try {
      final result = await compute(_parseExcelInBackground, excelBytes);
      emit(OrderLoaded(
        orderDetails: result['details'] as OrderDetails,
        groupedItems: result['groups'] as List<SizeGroup>,
        orderImage: result['image'] as Uint8List?,
        mainModelNumber: result['mainModel'] as String,
      ));
    } catch (e) {
      emit(OrderError("Error parsing Excel: $e"));
    }
  }

  static Map<String, dynamic> _parseExcelInBackground(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel.tables[excel.getDefaultSheet()]!;

    String getCellVal(int colIdx, int rowIdx) {
      try {
        return sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIdx, rowIndex: rowIdx)).value?.toString().trim() ?? "";
      } catch (_) {
        return "";
      }
    }

    List<OrderItem> parsedItems = [];
    double totalSum = 0.0;
    String mainModelNumber = "";

    for (int i = 24; i < sheet.maxRows; i++) {
      final modelCell = getCellVal(9, i); // Column J (9)
      if (modelCell.isEmpty) continue;

      if (mainModelNumber.isEmpty) {
        mainModelNumber = modelCell;
      }

      final countStr = getCellVal(20, i);
      final distStr = getCellVal(24, i);
      final countValue = double.tryParse(countStr) ?? 0.0;
      totalSum += countValue;

      parsedItems.add(OrderItem(
        modelNumber: modelCell,
        size: getCellVal(15, i),
        colorName: getCellVal(16, i),
        colorCode: getCellVal(17, i),
        secondaryColor: getCellVal(18, i),
        group: getCellVal(19, i),
        count: countStr,
        distribution: distStr,
      ));
    }

    final Map<String, List<OrderItem>> map = {};
    for (var item in parsedItems) {
      map.putIfAbsent(item.size, () => []).add(item);
    }

    final groupedItems = map.entries.map((e) => SizeGroup(size: e.key, items: e.value)).toList();
    final formattedSum = totalSum % 1 == 0 ? totalSum.toInt().toString() : totalSum.toString();

    final orderDetails = OrderDetails(
      artNum: getCellVal(9, 24),
      orderDate: getCellVal(15, 1),
      yarnType: getCellVal(15, 2),
      legLength: getCellVal(15, 3),
      line: getCellVal(15, 4),
      notesGender: getCellVal(15, 5),
      machineType: getCellVal(15, 6),
      machineNotes: getCellVal(15, 7),
      packagingNotes: getCellVal(15, 8),
      externalServices: getCellVal(15, 9),
      machineDelivery: getCellVal(15, 10),
      clientDelivery: getCellVal(15, 11),
      labelCode: getCellVal(15, 12),
      boxCode: getCellVal(15, 13),
      manufacturingId: getCellVal(15, 14),
      orderName: getCellVal(15, 15),
      designs: getCellVal(15, 16),
      totalDozen: formattedSum,
      dozenWeight: getCellVal(15, 18),
      fileName: getCellVal(15, 19),
      season: getCellVal(15, 20),
      customer: getCellVal(15, 21),
    );

    Uint8List? orderImage;
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final file in archive) {
      if (file.isFile && file.name.startsWith('xl/media/')) {
        orderImage = file.content as Uint8List;
        break;
      }
    }

    return {
      'details': orderDetails,
      'groups': groupedItems,
      'image': orderImage,
      'mainModel': mainModelNumber,
    };
  }
}