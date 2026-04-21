class ServiceItem {
  final String id;
  final String label;
  final String desc;
  final List<String> tags;
  final bool popular;

  const ServiceItem({
    required this.id,
    required this.label,
    required this.desc,
    required this.tags,
    required this.popular,
  });
}