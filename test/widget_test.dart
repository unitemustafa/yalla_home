import 'package:flutter_test/flutter_test.dart';

import 'package:yalla_home/yalla_home_app.dart';

void main() {
  testWidgets('shows Yalla Home login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const YallaHomeApp());
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    expect(find.text('أهلاً يا كابتن'), findsOneWidget);
    expect(find.text('رقم الموبايل أو الإيميل'), findsOneWidget);
    expect(find.text('دخول Demo'), findsOneWidget);
  });
}
