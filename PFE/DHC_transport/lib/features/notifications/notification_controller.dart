import 'package:flutter/foundation.dart';

import '../../core/services/notification_service.dart';
import 'notification_model.dart';

enum _Group { today, yesterday, earlier }

class NotificationController extends ChangeNotifier {
  List<NotificationItem> _items = [];
  bool _loading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  ValueChanged<int>? onUnreadCountChanged;

  // ── Read-only accessors ───────────────────────────────────────────────────

  List<NotificationItem> get items => List.unmodifiable(_items);
  bool get loading => _loading;
  bool get isSelectionMode => _isSelectionMode;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  bool get hasUnread => _items.any((e) => !e.read);

  bool get allSelected =>
      _items.isNotEmpty && _selectedIds.length == _items.length;

  List<NotificationItem> get todayItems => _group(_Group.today);
  List<NotificationItem> get yesterdayItems => _group(_Group.yesterday);
  List<NotificationItem> get earlierItems => _group(_Group.earlier);

  bool isSelected(String id) => _selectedIds.contains(id);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      final raw = await const NotificationService().listNotifications();
      _items = raw.map(NotificationItem.fromMap).toList();
    } catch (_) {}
    _loading = false;
    notifyListeners();
    _reportUnread();
  }

  // ── Read state ────────────────────────────────────────────────────────────

  Future<void> markRead(String id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0 || _items[idx].read) return;
    final original = _items[idx];
    _items[idx] = original.copyWith(read: true);
    notifyListeners();
    _reportUnread();
    try {
      await const NotificationService().markAsRead(id);
    } catch (_) {
      _items[idx] = original;
      notifyListeners();
      _reportUnread();
    }
  }

  Future<void> markAllRead() async {
    final originals = List<NotificationItem>.from(_items);
    _items = _items.map((e) => e.copyWith(read: true)).toList();
    notifyListeners();
    _reportUnread();
    try {
      await const NotificationService().markAllRead();
    } catch (_) {
      _items = originals;
      notifyListeners();
      _reportUnread();
    }
  }

  Future<void> markSelectedRead() async {
    final ids = Set<String>.from(_selectedIds);
    for (final id in ids) {
      final idx = _items.indexWhere((e) => e.id == id);
      if (idx >= 0) _items[idx] = _items[idx].copyWith(read: true);
    }
    _selectedIds.clear();
    _isSelectionMode = false;
    notifyListeners();
    _reportUnread();
    for (final id in ids) {
      try {
        await const NotificationService().markAsRead(id);
      } catch (_) {}
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  /// Removes item locally and returns it so the caller can offer undo.
  NotificationItem? removeLocally(String id) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final removed = _items.removeAt(idx);
    _selectedIds.remove(id);
    notifyListeners();
    _reportUnread();
    return removed;
  }

  /// Commits the deletion to the backend. Call after the undo window closes.
  Future<void> commitDelete(String id) async {
    try {
      await const NotificationService().deleteNotification(id);
    } catch (_) {}
  }

  /// Re-inserts a previously removed item (undo path).
  void restoreItem(NotificationItem item) {
    final insertIdx = _items.indexWhere(
      (e) =>
          (e.createdAt ?? DateTime(0))
              .isBefore(item.createdAt ?? DateTime(0)),
    );
    if (insertIdx < 0) {
      _items.add(item);
    } else {
      _items.insert(insertIdx, item);
    }
    notifyListeners();
    _reportUnread();
  }

  Future<void> deleteSelected() async {
    final ids = Set<String>.from(_selectedIds);
    _items.removeWhere((e) => ids.contains(e.id));
    _selectedIds.clear();
    _isSelectionMode = false;
    notifyListeners();
    _reportUnread();
    for (final id in ids) {
      try {
        await const NotificationService().deleteNotification(id);
      } catch (_) {}
    }
  }

  // ── Selection mode ────────────────────────────────────────────────────────

  void enterSelectionMode(String firstId) {
    _isSelectionMode = true;
    _selectedIds.add(firstId);
    notifyListeners();
  }

  void exitSelectionMode() {
    _isSelectionMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    if (_selectedIds.isEmpty) _isSelectionMode = false;
    notifyListeners();
  }

  void toggleSelectAll() {
    if (allSelected) {
      _selectedIds.clear();
      _isSelectionMode = false;
    } else {
      _selectedIds.addAll(_items.map((e) => e.id));
    }
    notifyListeners();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  List<NotificationItem> _group(_Group type) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    return _items.where((item) {
      final local = item.createdAt?.toLocal();
      final day =
          local != null ? DateTime(local.year, local.month, local.day) : null;
      switch (type) {
        case _Group.today:
          return day == null || day == today;
        case _Group.yesterday:
          return day == yesterday;
        case _Group.earlier:
          return day != null && day.isBefore(yesterday);
      }
    }).toList();
  }

  void _reportUnread() {
    final count = _items.where((e) => !e.read).length;
    onUnreadCountChanged?.call(count);
  }
}
