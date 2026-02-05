import 'package:flutter/material.dart';

import 'pages/services/utils/operator_session.dart';
import 'pages/operator_login_page.dart';
import 'pages/operator_dashboard_page.dart';

class OperatorStartPage extends StatelessWidget {
  const OperatorStartPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (OperatorSession.isLoggedIn) {
      return OperatorDashboardPage(
        operatorId: OperatorSession.operatorId!,
      );
    }
    return const OperatorLoginPage();
  }
}
