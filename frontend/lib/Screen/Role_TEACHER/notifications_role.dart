import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

class TeacherNotification {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final String description;
  final String time;
  final String category;
  final Color categoryColor;
  final String? leaveRequestId; // set when the teacher can approve or decline it
  bool isRead;

  TeacherNotification({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.time,
    required this.category,
    required this.categoryColor,
    this.leaveRequestId,
    this.isRead = false,
  });
}

// What needs the teacher's attention: pending leave requests from students and parents,
// which can be approved or declined here (school-service D17). It used to show sample items.
class TeacherNotificationScreen extends StatefulWidget {
  // The calls can be replaced in tests; by default they go to the API.
  // decide returns null on success, otherwise the reason.
  const TeacherNotificationScreen({super.key, this.loadRequests, this.decide});

  final Future<List<LeaveRequestDto>> Function()? loadRequests;
  final Future<String?> Function(String id, bool approve)? decide;

  @override
  State<TeacherNotificationScreen> createState() =>
      _TeacherNotificationScreenState();
}

class _TeacherNotificationScreenState extends State<TeacherNotificationScreen> {
  String activeFilter = "All";
  final List<String> filters = ["All", "Requests"];
  List<TeacherNotification> notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final requests = await (widget.loadRequests ?? () => ApiService().getLeaveRequests(status: 'Pending'))();
    if (!mounted) return;
    setState(() {
      notifications = requests.map(_fromLeaveRequest).toList();
      _loading = false;
    });
  }

  static TeacherNotification _fromLeaveRequest(LeaveRequestDto r) {
    String day(String iso) {
      final d = DateTime.tryParse(iso);
      return d == null ? iso : DateFormat('MMM d').format(d);
    }

    final dates = r.startDate == r.endDate ? day(r.startDate) : '${day(r.startDate)} – ${day(r.endDate)}';
    final created = r.createdAt;
    return TeacherNotification(
      icon: Icons.person_add_rounded,
      iconColor: const Color(0xFF4A90E2),
      bgColor: const Color(0xFF4A90E2).withValues(alpha: 0.1),
      title: "Leave Request",
      subtitle: "${r.studentName} asked to be excused ($dates).",
      description: "${r.type} leave for ${r.studentName}, $dates.\n\nReason: ${r.reason}",
      time: created == null ? '' : _ago(DateTime.now().difference(created)),
      category: "Requests",
      categoryColor: const Color(0xFF4A90E2),
      leaveRequestId: r.id,
    );
  }

  static String _ago(Duration d) => d.inMinutes < 60
      ? '${d.inMinutes}m ago'
      : d.inHours < 24
          ? '${d.inHours}h ago'
          : '${d.inDays}d ago';

  Future<void> _decide(TeacherNotification item, bool approve) async {
    final id = item.leaveRequestId;
    if (id == null) return;
    final error = await (widget.decide ?? (id, ok) => ApiService().decideLeaveRequest(id, approve: ok))(id, approve);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? (approve ? 'Leave approved. The family was notified.' : 'Leave declined. The family was notified.')),
        backgroundColor: error == null ? const Color(0xFF50E3C2) : const Color(0xFFFF6B6B),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (error == null) setState(() => notifications.remove(item));
  }

  void _markAllRead() {
    setState(() {
      for (var n in notifications) {
        n.isRead = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<TeacherNotification> filteredList = notifications.where((n) {
      if (activeFilter == "All") return true;
      return n.category == activeFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Bounceable(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F6F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0D3B66),
              size: 18,
            ),
          ),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: const Color(0xFF0D3B66),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(
              "Read All",
              style: GoogleFonts.inter(
                color: const Color(0xFF4A90E2),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) =>
                        _buildNotificationCard(filteredList[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          bool isSelected = activeFilter == filters[index];
          return Bounceable(
            onTap: () => setState(() => activeFilter = filters[index]),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0D3B66) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF0D3B66).withValues(alpha: 0.2),
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
    );
  }

  Widget _buildNotificationCard(TeacherNotification item) {
    return Bounceable(
      onTap: () {
        setState(() => item.isRead = true);
        _showNotificationDetail(item);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: item.isRead
              ? null
              : Border.all(
                  color: const Color(0xFF0D3B66).withValues(alpha: 0.1),
                  width: 1,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(item.icon, color: item.iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.category.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item.categoryColor,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        item.time,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!item.isRead)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 20),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFF95738),
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showNotificationDetail(TeacherNotification item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        // Taller when the approve/decline buttons are shown
        height: MediaQuery.of(context).size.height * (item.leaveRequestId != null ? 0.75 : 0.6),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(35),
            topRight: Radius.circular(35),
          ),
        ),
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 30),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                      Text(
                        item.time,
                        style: GoogleFonts.inter(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 35),
            Text(
              "Full Description",
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  item.description,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (item.leaveRequestId != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const ValueKey('decline-leave'),
                      onPressed: () => _decide(item, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: const Color(0xFFFF6B6B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text("Decline", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      key: const ValueKey('approve-leave'),
                      onPressed: () => _decide(item, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF50E3C2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text("Approve", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Close Window",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: Colors.grey.shade200,
          ),
          const SizedBox(height: 20),
          Text(
            "All caught up!",
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          Text(
            "No $activeFilter notifications found.",
            style: GoogleFonts.inter(color: Colors.grey.shade300),
          ),
        ],
      ),
    );
  }
}
