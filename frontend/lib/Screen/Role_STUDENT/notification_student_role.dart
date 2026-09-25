import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

// --- 1. Notification Data Model ---
class NotificationItem {
  final String id;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final String fullDescription;
  final String time;
  final String tag;
  final Color tagColor;
  bool isNew;

  NotificationItem({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.fullDescription,
    required this.time,
    required this.tag,
    required this.tagColor,
    this.isNew = false,
  });
}

// Look and label for each notification type sent by the school service
const _typeStyles = {
  'Grade': (Icons.emoji_events_rounded, Color(0xFFFFB75E), 'Grades'),
  'Attendance': (Icons.fact_check_rounded, Color(0xFFB86DFF), 'Attendance'),
  'Announcement': (Icons.campaign_rounded, Color(0xFF4A90E2), 'Announcements'),
};

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inHours < 48) return 'Yesterday';
  return DateFormat('d MMM').format(time);
}

NotificationItem notificationItemFromDto(NotificationDto dto) {
  final style =
      _typeStyles[dto.type] ??
      (Icons.notifications_rounded, const Color(0xFF0D3B66), 'Other');
  return NotificationItem(
    id: dto.id,
    icon: style.$1,
    iconColor: style.$2,
    bgColor: style.$2.withValues(alpha: 0.15),
    title: dto.title,
    subtitle: dto.body,
    fullDescription: dto.body,
    time: _relativeTime(dto.createdAt),
    tag: style.$3,
    tagColor: style.$2,
    isNew: !dto.isRead,
  );
}

class NotificationScreen extends StatefulWidget {
  // The data calls can be replaced in tests; by default they go to the API.
  const NotificationScreen({
    super.key,
    this.fetch,
    this.markRead,
    this.markAllRead,
  });

  final Future<List<NotificationDto>> Function()? fetch;
  final Future<bool> Function(String id)? markRead;
  final Future<bool> Function()? markAllRead;

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // --- 2. State Variables ---
  String activeFilter = "All";
  final List<String> filters = [
    "All",
    "Grades",
    "Attendance",
    "Announcements",
    "Seen",
  ];

  List<NotificationItem> allNotifications = [];
  bool _loading = true;
  List<NotificationItem> _filteredList = [];

  List<NotificationItem> _applyFilter() {
    return allNotifications.where((item) {
      if (activeFilter == "All") return true;
      if (activeFilter == "Seen") return !item.isNew;
      return item.tag == activeFilter;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fetch = widget.fetch ?? () => ApiService().getNotifications();
    final items = await fetch();
    if (!mounted) return;
    setState(() {
      allNotifications = items.map(notificationItemFromDto).toList();
      _filteredList = _applyFilter();
      _loading = false;
    });
  }

  // --- 3. Logic: Mark All as Read ---
  Future<void> _markAllAsRead() async {
    final markAllRead =
        widget.markAllRead ?? () => ApiService().markAllNotificationsRead();
    if (!await markAllRead() || !mounted) return;
    setState(() {
      for (var item in allNotifications) {
        item.isNew = false;
      }
      _filteredList = _applyFilter();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: Bounceable(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF0D3B66),
            ),
          ),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D3B66),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          Bounceable(
            onTap: _markAllAsRead,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D3B66).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  "Mark all read",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0D3B66),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          // --- 5. Filter Horizontal List ---
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                bool isSelected = activeFilter == filters[index];
                return Bounceable(
                  onTap: () => setState(() {
                    activeFilter = filters[index];
                    _filteredList = _applyFilter();
                  }),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0D3B66)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF0D3B66).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      filters[index],
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          // --- 6. Notification List ---
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredList.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) =>
                          _buildNotificationCard(_filteredList[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // --- 7. UI Helper: Notification Card ---
  Widget _buildNotificationCard(NotificationItem item) {
    return Bounceable(
      onTap: () {
        if (item.isNew) {
          final markRead =
              widget.markRead ?? (id) => ApiService().markNotificationRead(id);
          markRead(item.id);
        }
        setState(() => item.isNew = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => NotificationDetailScreen(item: item),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: item.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: const Color(0xFF0D3B66),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            item.time,
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (item.isNew) ...[
                            const SizedBox(width: 8),
                            Container(
                              height: 8,
                              width: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF6B6B),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: item.tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.tag.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: item.tagColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 60,
              color: Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "No $activeFilter notifications yet",
            style: GoogleFonts.outfit(
              color: Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You're all caught up!",
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 8. Modern Professional Detail Screen ---
class NotificationDetailScreen extends StatelessWidget {
  final NotificationItem item;
  const NotificationDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Bounceable(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0D3B66),
              size: 18,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: item.iconColor.withValues(alpha: 0.3),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 50),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: item.tagColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.tag.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: item.tagColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "•  ${item.time}",
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.notes_rounded,
                            color: Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "MESSAGE CONTENT",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        item.fullDescription,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 120),
              ],
            ),
          ),
          // Floating Button
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF3F6F8).withValues(alpha: 0),
                    const Color(0xFFF3F6F8).withValues(alpha: 0.9),
                    const Color(0xFFF3F6F8),
                  ],
                ),
              ),
              child: Bounceable(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D3B66),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D3B66).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      "Dismiss Notification",
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
