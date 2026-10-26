import 'package:flutter/material.dart';
import '../screens/article_image/article_search.dart';
import '../screens/employee_management/employees_dashboard.dart';
import '../screens/excel_search_screen/excel_search.dart';
import '../screens/home/home_screen.dart';
import '../screens/management/management_screen.dart';

class DashboardWrapper extends StatelessWidget {
  const DashboardWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MainDashboardScreen(
      onNavigateToImages: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) =>  ArticleListScreen()));
      },
      onNavigateToExcel: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) =>  ExcelListScreen()));
      },
      onNavigateToSettings: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const
        ManagementScreen()));
      },
      onNavigateToEmployeesManagement: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeesManagementScreen()));
      },
      onNavigateToCalculator: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeesManagementScreen()));
      },
    );
  }
}