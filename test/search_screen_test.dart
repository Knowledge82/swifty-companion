import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swifty_companion/ui/search_screen.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) {
    return tester.pumpWidget(const MaterialApp(home: SearchScreen()));
  }

  testWidgets('пустой ввод показывает ошибку и не открывает профиль',
      (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Найти'));
    await tester.pump();

    expect(find.text('Введите логин'), findsOneWidget);
    expect(find.text('Здесь будет профиль'), findsNothing);
  });

  testWidgets('корректный логин открывает второй экран, назад возвращает',
      (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), '  VDarsuye ');
    await tester.tap(find.text('Найти'));
    await tester.pumpAndSettle();

    expect(find.text('vdarsuye'), findsOneWidget);
    expect(find.text('Здесь будет профиль'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Найти'), findsOneWidget);
  });
}
