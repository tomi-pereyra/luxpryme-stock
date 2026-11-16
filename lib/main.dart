import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/services/inventory_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/inventory/inventory_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool isConnectedToSupabase = false;
  try {
    if (!AppConstants.defaultSupabaseUrl.contains('SEU_PROJETO')) {
      await Supabase.initialize(
        url: AppConstants.defaultSupabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConstants.defaultSupabaseAnonKey,
      );
      isConnectedToSupabase = true;
    }
  } catch (e) {
    debugPrint('Iniciando em modo catálogo local: $e');
  }

  // Define se o serviço opera conectado ao Supabase ou com o Catálogo Local Inicial da Luxpryme
  InventoryService.instance.setMode(localMode: !isConnectedToSupabase);

  runApp(LuxprymeStockApp(isConnectedToSupabase: isConnectedToSupabase));
}

class LuxprymeStockApp extends StatelessWidget {
  final bool isConnectedToSupabase;

  const LuxprymeStockApp({
    super.key,
    required this.isConnectedToSupabase,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: isConnectedToSupabase
          ? const AuthGate()
          : const InventoryScreen(),
    );
  }
}

/// Roteador reativo quando conectado ao Supabase
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const InventoryScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
