/// Configuration de l'URL de base de l'API backend (Django + DRF).
///
/// GOTCHA CLASSIQUE (émulateur Android) : un émulateur Android ne peut
/// pas joindre la machine hôte via `127.0.0.1` / `localhost` — ce sont
/// des adresses *internes à l'émulateur lui-même*. L'alias spécial
/// `10.0.2.2` route vers l'hôte qui exécute l'émulateur. C'est pourquoi
/// la valeur par défaut ci-dessous est `http://10.0.2.2:8000`, et NON
/// `http://127.0.0.1:8000` ou `http://localhost:8000`.
///
/// - Émulateur Android + `python manage.py runserver` sur la même
///   machine hôte : valeur par défaut, rien à faire.
/// - Simulateur iOS (macOS) : le simulateur partage le réseau de
///   l'hôte, donc `http://127.0.0.1:8000` fonctionne — surchargez avec
///   `--dart-define=API_BASE_URL=http://127.0.0.1:8000`.
/// - Appareil physique (Android ou iOS) sur le même réseau Wi-Fi que
///   le serveur de développement : utilisez l'adresse IP locale de la
///   machine qui exécute `runserver` (ex. `http://192.168.1.42:8000`),
///   et démarrez le serveur avec
///   `python manage.py runserver 0.0.0.0:8000` pour qu'il écoute sur
///   toutes les interfaces, pas seulement `127.0.0.1`.
/// - Backend déployé ailleurs (serveur distant, démo) : passez son URL
///   complète (avec `https://` si TLS) via `--dart-define`.
///
/// Exemple :
/// ```
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000
/// ```
class ApiConfig {
  ApiConfig._();

  /// URL de base de l'API, sans slash final, sans le préfixe `/api`
  /// (celui-ci est ajouté par chaque service, ex. `/api/accounts/...`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Délai maximum avant qu'une requête HTTP soit abandonnée.
  static const Duration timeout = Duration(seconds: 20);
}
