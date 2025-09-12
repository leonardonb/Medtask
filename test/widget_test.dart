import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:medtask/ui/pages/home_page.dart';
import 'package:medtask/lib/viewmodels/med_list_viewmodel.dart';

class FakeMedListViewModel extends MedListViewModel {
  @override
  Future<void> init() async {} // evita inicialização de plugins/DB nos testes
}

void main() {
  testWidgets('Home exibe vazio e abre tela de novo item', (tester) async {
    Get.testMode = true;
    Get.put(FakeMedListViewModel(), permanent: true);

    await tester.pumpWidget(
      const GetMaterialApp(home: HomePage()),
    );

    expect(find.text('Nenhum remédio. Toque + para adicionar.'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Novo'), findsOneWidget); // título da AppBar em EditMedPage
  });
}
