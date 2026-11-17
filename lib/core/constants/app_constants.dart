/// Constantes da aplicação Estoque Luxpryme
class AppConstants {
  AppConstants._();

  static const String appName = 'Estoque Luxpryme';
  static const String appTagline = 'Controle de Estoque Industrial';
  static const String appVersion = '1.2.0';
  static const String appDeveloper = 'Tomas Pereyra';
  static const String appDeveloperRole = 'Desenvolvedor & Administrador';

  // Chaves Oficiais do Projeto Supabase Luxpryme
  static const String defaultSupabaseUrl = 'https://kblmdquushszqiqkriqd.supabase.co';
  static const String defaultSupabaseAnonKey = 'sb_publishable_28aAVuNjofV5db5lTcrScQ_SauSFP2p';

  // Nomes das Tabelas
  static const String tableCategories = 'categories';
  static const String tableProducts = 'products';
  static const String tableMasterCategories = 'master_categories';
  static const String tableOperatorPins = 'operator_pins';
  static const String tableStockMovements = 'stock_movements';
}
