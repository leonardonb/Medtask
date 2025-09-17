# Medtask

Lembretes de medicamentos com notificações locais, adiamento rápido, arquivamento e indicadores de urgência — feito em Flutter.

> **Stack**: Flutter (Dart) + GetX (estado/roteamento) + SharedPreferences (persistência leve) + awesome_notifications (notificações locais).  
> **Plataformas**: foco atual em Android.

---

## ✨ Funcionalidades

- **Lista de medicamentos (Home)**
    - Próxima tomada com **contagem regressiva** e **selos de ATENÇÃO/ATRASADO**.
    - Ações rápidas: **Tomei agora**, **Adiar**, **Pular**, **Editar**, **ON/OFF**, **Excluir**.
    - **Layout responsivo**: cartões organizados em grade para telas maiores (ex.: 2 colunas × 3 linhas), mantendo boa leitura em celulares.

- **Edição/Criação**
    - Primeira dose (data/hora).
    - **Intervalo em Dias / Horas / Minutos** (validação para evitar 0 total).
    - **Arquivamento automático** (data/hora opcionais).
    - **Força ON** ao **inserir** novo medicamento e ao **desarquivar** (evita voltar OFF).

- **Arquivados**
    - Lista separada; **desarquivar** reativa notificações e volta à Home.

- **Notificações**
    - Canais: **Sistema**, **Som do app (alarme.mp3)**, **Vibrar apenas** (sem áudio).
    - **Prévia de som** pela tela de Configurações.
    - Agendamentos exatos e séries com cancelamento por grupo/medicamento.

- **Configurações**
    - Permissão de notificação (Android 13+).
    - Escolha do **som** (Sistema / App / Vibrar apenas).
    - Tema (Sistema/Claro/Escuro).

- **Apresentação (Sobre)**
    - Página “Apresentação” com nome do app, propósito, autor, contato e versão — **definidos pelo desenvolvedor** no código.

---

## 🗂 Estrutura do projeto

```
lib/
├─ core/
│  ├─ notification_service.dart        # Canais, agendamentos, prévias
│  ├─ notification_helpers.dart        # Cancelamentos por med/grupo
│  └─ settings_service.dart            # AlarmChoice/ThemeMode em SharedPreferences
├─ data/
│  └─ services/
│     └─ archive_service.dart          # Arquivar/desarquivar por id
├─ models/
│  └─ medication.dart                  # Modelo Medication
├─ viewmodels/
│  └─ med_list_viewmodel.dart          # Orquestra meds e notificações
└─ ui/
   └─ pages/
      ├─ home_page.dart                # Lista, cartões, grade responsiva
      ├─ archived_meds_page.dart       # Tela de arquivados
      ├─ edit_med_page.dart            # Form com dias/horas/min + auto-archive
      ├─ about/about_page.dart         # Apresentação (conteúdo do dev)
      └─ features/settings/settings_page.dart  # Permissão, som, tema, prévia
```

> Os caminhos e nomes refletem a organização atual do código.

---

## 🧠 Arquitetura

- **MVVM com GetX**: `MedListViewModel` mantém estado reativo (`Obx`) e cuida de cronograma, ON/OFF, reagendamentos e refresh da Home.
- **Persistência leve**: `SharedPreferences` guarda escolha de som, tema e dados de apresentação.
- **Notificações**: centralizadas em `NotificationService` (init de canais, criação/cancelamento de schedules).

---

## 🔔 Notificações (Android)

### Canais recomendados

- **`meds`** — Lembretes padrão com som.
- **`custom`** — Usa `alarme.mp3` do app (colocar arquivo em `android/app/src/main/res/raw/alarme.mp3`).
- **`vibrate_only`** — **Sem som**, apenas vibração (`playSound: false`, `enableVibration: true`).

Exemplo (trecho) de inicialização:

```dart
await AwesomeNotifications().initialize(
  null,
  [
    NotificationChannel(
      channelKey: 'meds',
      channelName: 'Lembretes de remédio',
      channelDescription: 'Alertas recorrentes para tomada de medicamentos',
      importance: NotificationImportance.Max,
      defaultPrivacy: NotificationPrivacy.Public,
      playSound: true,
      enableVibration: true,
      locked: true,
      defaultRingtoneType: DefaultRingtoneType.Alarm,
    ),
    NotificationChannel(
      channelKey: 'custom',
      channelName: 'Som do app',
      channelDescription: 'Usa alarme.mp3 do app',
      importance: NotificationImportance.Max,
      defaultPrivacy: NotificationPrivacy.Public,
      playSound: true,
      enableVibration: true,
      locked: true,
      soundSource: 'resource://raw/alarme',
    ),
    NotificationChannel(
      channelKey: 'vibrate_only',
      channelName: 'Som desativado (só vibrar)',
      channelDescription: 'Vibração sem áudio',
      importance: NotificationImportance.Max,
      defaultPrivacy: NotificationPrivacy.Public,
      playSound: false,
      enableVibration: true,
      locked: true,
    ),
  ],
  debug: false,
);
```

### Dicas de confiabilidade

- **Android 13+**: peça a permissão de notificação em tempo de execução.
- Se usar `preciseAlarm: true`, certifique-se do direito de alarme exato.
- Considere orientar o usuário a isentar o app da otimização de bateria para maior previsibilidade.

---

## 📱 Telas

- **Home**  
  Cartões com nome, próxima tomada, contagem regressiva e badges **ATENÇÃO** / **ATRASADO**; ações rápidas; **grade responsiva** em telas grandes.

- **Edição**  
  **Intervalo em dias/horas/minutos**; **desarquivar** dentro da tela; ao **desarquivar** ou **criar**, o item é **forçado ON** e a navegação retorna à Home.

- **Arquivados**  
  Gestão de itens fora da lista principal; retorno e reativação simples.

- **Configurações**  
  Permissões, tema e **som** (Sistema / App / **Vibrar**). Botão de **Prévia** cria uma notificação no canal selecionado.

- **Apresentação**  
  Exibe Nome/Propósito/Autor/Contato/Versão — definidos pelo desenvolvedor.

---

## ⚙️ Como rodar

1. **Flutter** (channel *stable*) instalado.
2. Dependências:
   ```bash
   flutter pub get
   ```
3. Executar:
   ```bash
   flutter run
   ```
4. Build release (Android):
   ```bash
   flutter build apk --release
   ```
5. Coloque o arquivo de som (opcional, para canal `custom`):  
   `android/app/src/main/res/raw/alarme.mp3`

---

## 🔧 Manutenção

- Mudar o **canal de som** em Configurações dispara `rescheduleAllAfterSoundChange()` no ViewModel para **reagendar** notificações futuras no canal escolhido.
- Ao **desarquivar**, a tela força **enabled = true** e volta para a Home com o item **ON**.
- Ao **criar** um medicamento, o item é salvo e forçado **ON** por padrão.

---

## 📌 Possíveis futuras implementações

- Suporte iOS;
- Testes;
- Backup/Restore (JSON);
- “Soneca mais inteligente” e melhorias de UX;
- Analytics de adesão (on-device);
- Histórico de medicação.

---

## ✍️ Créditos

- Desenvolvimento: **Leonardo Nunes Barros**.
- E-mail: leonardonb@gmail.com

