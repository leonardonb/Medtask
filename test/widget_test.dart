import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:Medtask/ui/pages/home_page.dart';
import 'package:Medtask/viewmodels/med_list_viewmodel.dart';

class FakeMedListViewModel extends MedListViewModel {
  @override
  Future<void> init() async {
    // evita DB/plugins durante teste
  }

  @override
  void onClose() {
    // evita timers do controller real (se existirem)
    super.onClose();
  }
}

void main() {
  testWidgets('Home exibe vazio e abre tela de novo remédio', (tester) async {
    Get.testMode = true;

    if (Get.isRegistered<MedListViewModel>()) {
      Get.delete<MedListViewModel>(force: true);
    }
    Get.put<MedListViewModel>(FakeMedListViewModel(), permanent: true);

    await tester.pumpWidget(
      const GetMaterialApp(home: HomePage()),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum remédio cadastrado.\nToque em Adicionar para começar.'),
      findsOneWidget,
    );

    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Novo Remédio'), findsOneWidget);
  });
}
