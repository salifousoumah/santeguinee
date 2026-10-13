import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/navigation_principale_screen.dart';
import 'services/api_client.dart';
import 'services/app_session.dart';
import 'services/auth_service.dart';
import 'services/directory_service.dart';
import 'services/local_cache_service.dart';
import 'services/patients_service.dart';
import 'services/scheduling_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nécessaire pour que `DateFormat(..., 'fr_FR')` (dates des créneaux,
  // etc.) dispose de ses symboles français sans lever de
  // LocaleDataException.
  await initializeDateFormatting('fr_FR');
  runApp(const SanteGuineeApp());
}

/// Racine de l'application : construit les services (API, session) une
/// seule fois et les rend disponibles à tout l'arbre de widgets via
/// `provider`.
class SanteGuineeApp extends StatelessWidget {
  const SanteGuineeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        Provider<AuthService>(
          create: (context) => AuthService(context.read<ApiClient>()),
        ),
        Provider<DirectoryService>(
          create: (context) => DirectoryService(context.read<ApiClient>()),
        ),
        Provider<PatientsService>(
          create: (context) => PatientsService(context.read<ApiClient>()),
        ),
        Provider<SchedulingService>(
          create: (context) => SchedulingService(context.read<ApiClient>()),
        ),
        Provider<LocalCacheService>(create: (_) => LocalCacheService()),
        ChangeNotifierProvider<AppSession>(
          create: (context) => AppSession(
            apiClient: context.read<ApiClient>(),
            patientsService: context.read<PatientsService>(),
          )..demarrer(),
        ),
      ],
      child: MaterialApp(
        title: 'SantéGuinée',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr', 'FR'),
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0E7C61),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF0E7C61),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const RacineApp(),
      ),
    );
  }
}

/// Attend la fin du chargement initial de session (jeton +
/// utilisateur sauvegardés, voir `AppSession.demarrer`) avant
/// d'afficher la navigation principale.
class RacineApp extends StatelessWidget {
  const RacineApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    if (!session.chargementInitialFait) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const NavigationPrincipaleScreen();
  }
}
