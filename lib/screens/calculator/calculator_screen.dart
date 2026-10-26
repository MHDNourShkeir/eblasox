import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'calculator_cubit.dart';


class DozenCalculatorScreen extends StatelessWidget {
  const DozenCalculatorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DozenCalculatorCubit(),
      child: const _CalculatorView(),
    );
  }
}

class _CalculatorView extends StatelessWidget {
  const _CalculatorView();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr, // Math is universally LTR
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          leading: Container(),
          actions: [
            IconButton(onPressed: (){Navigator.pop(context);}, icon: Icon(Icons.arrow_forward_rounded))
          ],
          title: const Text('الالة الحاسبة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal.shade700,
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
          elevation: 0,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Display Area
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(24.0),
                  alignment: Alignment.bottomRight,
                  child: BlocBuilder<DozenCalculatorCubit, DozenCalculatorState>(
                    builder: (context, state) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            state.history,
                            style: TextStyle(fontSize: 24, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            state.display,
                            style: TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // Keypad Area
              // Keypad Area
              Expanded(
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))],
                  ),
                  child: Column(
                    children: [
                      // الصفوف الخمسة متساوية الارتفاع والترتيب
                      _buildRow(context, ['C', 'DEL', '÷', '×']),
                      _buildRow(context, ['7', '8', '9', '-']),
                      _buildRow(context, ['4', '5', '6', '+']),
                      // 🚀 وضعنا الـ (=) بجانب الـ 3 ليتساوى مع الصفوف العلوية
                      _buildRow(context, ['1', '2', '3', ' /12 ']),
                      // 🚀 تركنا زرين فقط في الصف الأخير، وسيتمددان تلقائياً لملء العرض بالكامل
                      _buildRow(context, ['0', '=']),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> buttons, {bool isExpanded = false}) {
    final cubit = context.read<DozenCalculatorCubit>();
    Widget rowWidget = Row(
      children: buttons.map((btn) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: CalcButton(
              text: btn,
              onTap: () {
                if (btn == 'C') cubit.onClear();
                else if (btn == 'DEL') cubit.onDelete();
                else if (btn == '=') cubit.onEqualPress();
                else if (['+', '-', '×', '÷'].contains(btn)) cubit.onOperatorPress(btn);
                else if (btn == ' /12 ') cubit.onNumberPress(':');
                else cubit.onNumberPress(btn);
              },
              isOperator: ['+', '-', '×', '÷', '='].contains(btn),
              isAction: ['C', 'DEL'].contains(btn),
              isDozen: btn == ' /12 ',
            ),
          ),
        );
      }).toList(),
    );

    return isExpanded ? Expanded(child: rowWidget) : Expanded(child: rowWidget);
  }
}

class CalcButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool isOperator;
  final bool isAction;
  final bool isDozen;

  const CalcButton({
    Key? key,
    required this.text,
    required this.onTap,
    this.isOperator = false,
    this.isAction = false,
    this.isDozen = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    Border? border;

    if (isOperator) {
      bgColor = Colors.teal.shade600;
      textColor = Colors.white;
    } else if (isAction) {
      bgColor = Colors.red.shade400;
      textColor = Colors.white;
    } else if (isDozen) {
      bgColor = Colors.amber.shade500;
      textColor = Colors.white;
    } else {
      bgColor = Colors.grey.shade50;
      textColor = Colors.teal.shade900;
      border = Border.all(color: Colors.grey.shade200, width: 1.5);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: border,
        boxShadow: (isOperator || isAction || isDozen)
            ? [BoxShadow(color: bgColor.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.teal.withOpacity(0.1),
          highlightColor: Colors.teal.withOpacity(0.05),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: isDozen ? 22 : 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}