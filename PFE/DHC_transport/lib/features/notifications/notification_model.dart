class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool read;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    this.createdAt,
  });

  NotificationItem copyWith({bool? read}) => NotificationItem(
        id: id,
        title: title,
        message: message,
        type: type,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  factory NotificationItem.fromMap(Map<String, dynamic> map) => NotificationItem(
        id: map['_id']?.toString() ?? '',
        title: (map['title'] as String?)?.trim() ?? '',
        message: (map['message'] as String?)?.trim() ?? '',
        type: (map['type'] as String?) ?? 'info',
        read: map['read'] == true,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString())
            : null,
      );
}
