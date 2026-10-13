class Genre {
  final String id;
  final String name;

  const Genre({required this.id, required this.name});

  factory Genre.fromMap(Map<String, dynamic> map) => Genre(
        id: map['id'] as String,
        name: map['name'] as String,
      );
}
