/// Enveloppe générique pour les réponses paginées de DRF
/// (`rest_framework.pagination.PageNumberPagination`), de la forme :
/// `{"count": 42, "next": "...", "previous": null, "results": [...]}`.
class PaginatedResponse<T> {
  final int count;
  final String? next;
  final String? previous;
  final List<T> results;

  PaginatedResponse({
    required this.count,
    required this.next,
    required this.previous,
    required this.results,
  });

  bool get hasNext => next != null;

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final rawResults = (json['results'] as List<dynamic>? ?? <dynamic>[]);
    return PaginatedResponse<T>(
      count: json['count'] as int? ?? rawResults.length,
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      results: rawResults
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
