import 'package:flutter_bloc/flutter_bloc.dart';

class DozenCalculatorState {
  final String display;
  final String history;

  DozenCalculatorState({required this.display, required this.history});
}

class DozenCalculatorCubit extends Cubit<DozenCalculatorState> {
  DozenCalculatorCubit() : super(DozenCalculatorState(display: "0", history: ""));

  String currentInput = "";
  double? storedValue;
  String? operation;
  bool shouldResetInput = false;

  void onNumberPress(String num) {
    if (shouldResetInput) {
      currentInput = "";
      shouldResetInput = false;
    }

    // Prevent multiple dozen separators
    if (num == ":" && currentInput.contains(":")) return;

    // Auto-prefix with 0 if separator is pressed first
    if (num == ":" && currentInput.isEmpty) {
      currentInput = "0";
    }

    // Prevent typing units >= 12
    if (currentInput.contains(":")) {
      List<String> parts = (currentInput + num).split(":");
      if (parts.length == 2 && parts[1].isNotEmpty) {
        int? units = int.tryParse(parts[1]);
        if (units != null && units >= 12) return;
      }
    }

    if (currentInput == "0" && num != ":") {
      currentInput = num;
    } else {
      currentInput += num;
    }

    emit(DozenCalculatorState(display: _formatActiveInput(currentInput), history: state.history));
  }

  void onOperatorPress(String op) {
    if (currentInput.isEmpty && storedValue == null) return;

    double currentValue = _parseInput(
        currentInput.isEmpty ? (state.display.contains("Error") ? "0" : _deformatDisplay(state.display)) : currentInput
    );

    if (storedValue != null && operation != null && !shouldResetInput) {
      currentValue = _calculate(storedValue!, currentValue, operation!);
    }

    storedValue = currentValue;
    operation = op;
    shouldResetInput = true;

    emit(DozenCalculatorState(
      display: _formatMathResult(storedValue!),
      history: "${_formatMathResult(storedValue!)} $op",
    ));
  }

  void onEqualPress() {
    if (storedValue == null || operation == null) return;

    double currentValue = _parseInput(
        currentInput.isEmpty ? _deformatDisplay(state.display) : currentInput
    );
    double result = _calculate(storedValue!, currentValue, operation!);

    emit(DozenCalculatorState(
      display: _formatMathResult(result),
      history: "${_formatMathResult(storedValue!)} $operation ${_formatMathResult(currentValue)} =",
    ));

    storedValue = null;
    operation = null;

    // Store result formatted as raw internal state (e.g. 9:5) for chaining
    currentInput = _deformatDisplay(_formatMathResult(result));
    shouldResetInput = true;
  }

  void onClear() {
    currentInput = "";
    storedValue = null;
    operation = null;
    shouldResetInput = false;
    emit(DozenCalculatorState(display: "0", history: ""));
  }

  void onDelete() {
    if (shouldResetInput) return;
    if (currentInput.isNotEmpty) {
      currentInput = currentInput.substring(0, currentInput.length - 1);
      if (currentInput.isEmpty) {
        currentInput = "0";
      }
      emit(DozenCalculatorState(display: _formatActiveInput(currentInput), history: state.history));
    }
  }

  // --- Core Dozen Math Logic ---

  double _parseInput(String input) {
    if (input.isEmpty) return 0;
    if (!input.contains(":")) {
      return double.tryParse(input) ?? 0;
    }
    List<String> parts = input.split(":");
    double dozens = double.tryParse(parts[0].isEmpty ? "0" : parts[0]) ?? 0;
    double units = double.tryParse(parts.length > 1 && parts[1].isNotEmpty ? parts[1] : "0") ?? 0;
    return dozens + (units / 12.0); // Convert to purely base-12 scalar
  }

  String _formatMathResult(double value) {
    if (value.isInfinite || value.isNaN) return "Error";

    // Convert base-12 scalar back to total units to find remainder
    int totalUnits = (value * 12).round();
    int dozens = (totalUnits ~/ 12).abs();
    int units = totalUnits.remainder(12).abs();
    String sign = totalUnits < 0 ? "-" : "";

    if (units == 0) return "$sign$dozens";
    if (dozens == 0) return "$sign$units/12";
    return "$sign$dozens $units/12";
  }

  String _formatActiveInput(String rawInput) {
    if (!rawInput.contains(":")) return rawInput;
    List<String> parts = rawInput.split(":");
    String d = parts[0].isEmpty ? "0" : parts[0];
    String u = parts.length > 1 ? parts[1] : "";
    if (u.isEmpty) return "$d _/12";
    return "$d $u/12";
  }

  String _deformatDisplay(String displayStr) {
    if (displayStr.contains("/")) {
      displayStr = displayStr.replaceAll("/12", "").trim();
      List<String> parts = displayStr.split(" ");
      if (parts.length == 1) return "0:${parts[0]}"; // Only fraction
      return "${parts[0]}:${parts[1]}"; // Dozen + fraction
    }
    return displayStr;
  }

  double _calculate(double a, double b, String op) {
    switch (op) {
      case "+": return a + b;
      case "-": return a - b;
      case "×": return a * b;
      case "÷": return b == 0 ? double.infinity : a / b;
      default: return b;
    }
  }
}