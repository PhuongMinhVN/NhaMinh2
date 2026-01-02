import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Check if we already have a session to show UI immediately
          final session = Supabase.instance.client.auth.currentSession;
          if (session != null) {
            return const DashboardPage();
          }
          // Otherwise show a loading indicator
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8B1A1A),
              ),
            ),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          return const DashboardPage();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}
