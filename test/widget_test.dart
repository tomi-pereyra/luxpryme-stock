import 'package:flutter_test/flutter_test.dart';
import 'package:luxpryme_stock/main.dart';

void main() {
  testWidgets('Luxpryme Stock initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LuxprymeStockApp(isConnectedToSupabase: false));
    await tester.pumpAndSettle();

    // Verifica se a tela principal de inventário carregou com a marca Luxpryme
    expect(find.text('Luxpryme Stock'), findsOneWidget);
  });
}
