class Customer {
  final int? id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;

  // Aggregates (populated by JOIN queries; not stored as columns)
  final int invoiceCount;
  final double totalSpent;
  final String? lastVisit;

  Customer({
    this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.invoiceCount = 0,
    this.totalSpent = 0,
    this.lastVisit,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'address': address,
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as int?,
        name: map['name'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        invoiceCount: (map['invoice_count'] as int?) ?? 0,
        totalSpent: (map['total_spent'] as num?)?.toDouble() ?? 0,
        lastVisit: map['last_visit'] as String?,
      );

  Customer copyWith({
    String? name,
    String? phone,
    String? email,
    String? address,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        invoiceCount: invoiceCount,
        totalSpent: totalSpent,
        lastVisit: lastVisit,
      );
}
