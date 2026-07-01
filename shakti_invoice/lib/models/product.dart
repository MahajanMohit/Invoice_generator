class Product {
  final int? id;
  final String name;
  final double price;
  final String? category;
  final String? unit; // e.g. "pc", "kg", "ltr"
  final int timesSold; // popularity counter for smart ordering

  Product({
    this.id,
    required this.name,
    required this.price,
    this.category,
    this.unit,
    this.timesSold = 0,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'price': price,
        'category': category,
        'unit': unit,
        'times_sold': timesSold,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        price: (map['price'] as num).toDouble(),
        category: map['category'] as String?,
        unit: map['unit'] as String?,
        timesSold: (map['times_sold'] as int?) ?? 0,
      );

  Product copyWith({
    String? name,
    double? price,
    String? category,
    String? unit,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        timesSold: timesSold,
      );
}
