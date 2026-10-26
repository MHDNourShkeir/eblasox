class WorkerHour {
  final String id; // رقم البصمة (العمود B)
  final String name; // الاسم (العمود C)
  final String section; // القسم (العمود D)
  final int rowIndex; // رقم الصف في الإكسل (لحفظ التعديل في نفس المكان)
  double? hours; // عدد الساعات (null تعني غائب)

  WorkerHour({
    required this.id,
    required this.name,
    required this.section,
    required this.rowIndex,
    this.hours,
  });

  WorkerHour copyWith({double? hours, bool clearHours = false}) {
    return WorkerHour(
      id: id,
      name: name,
      section: section,
      rowIndex: rowIndex,
      hours: clearHours ? null : (hours ?? this.hours),
    );
  }
}