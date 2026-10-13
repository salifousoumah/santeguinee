/// Zone administrative (`directory.Zone`) : région > préfecture >
/// commune/sous-préfecture > quartier/district.
/// Champs confirmés dans `backend/directory/serializers.py::ZoneSerializer`.
class Zone {
  static const String region = 'region';
  static const String prefecture = 'prefecture';
  static const String communeSousPrefecture = 'commune_sous_prefecture';
  static const String quartierDistrict = 'quartier_district';

  final String id;
  final String type;
  final String nom;
  final String? parent;

  Zone({
    required this.id,
    required this.type,
    required this.nom,
    this.parent,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    return Zone(
      id: json['id'] as String,
      type: json['type'] as String,
      nom: json['nom'] as String,
      parent: json['parent'] as String?,
    );
  }
}
