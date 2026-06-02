class PathNode {
  final String id;
  final double latitude;
  final double longitude;
  final int order;
  final String? name;
  final String? category;

  PathNode({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.order,
    this.name,
    this.category,
  });

  factory PathNode.fromJson(Map<String, dynamic> json) {
    return PathNode(
      id: json['id'].toString(),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      order: json['order'] ?? 0,
      name: json['name'],
      category: json['category'],
    );
  }
}