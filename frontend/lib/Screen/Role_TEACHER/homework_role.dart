import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

// Homework = class materials of type assignment (school-service D16). The teacher sees
// their classes' homework with how many students handed it in, and assigns new homework.
class TeacherHomeworkScreen extends StatefulWidget {
  // The calls can be replaced in tests; by default they go to the API.
  // assign returns null on success, otherwise the reason.
  const TeacherHomeworkScreen({
    super.key,
    this.loadClasses,
    this.loadMaterials,
    this.assign,
  });

  final Future<List<ClassroomDto>> Function()? loadClasses;
  final Future<List<MaterialDto>> Function(String classroomId)? loadMaterials;
  final Future<String?> Function(String classroomId, String title, String? description, DateTime? dueAt)? assign;

  @override
  State<TeacherHomeworkScreen> createState() => _TeacherHomeworkScreenState();
}

class _TeacherHomeworkScreenState extends State<TeacherHomeworkScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _filterStatus = 'All';

  List<Map<String, dynamic>> _homeworks = [];
  List<ClassroomDto> _classes = [];
  bool _loading = true;
  static final DateFormat _date = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  // The teacher's own classes; every class when none is assigned to them yet.
  Future<List<ClassroomDto>> _teacherClasses() async {
    final api = ApiService();
    final all = await api.getClassrooms();
    final me = await api.getEntityId();
    final mine = all.where((c) => c.teacherId != null && c.teacherId == me).toList();
    return mine.isNotEmpty ? mine : all;
  }

  Future<void> _load() async {
    final classes = await (widget.loadClasses ?? _teacherClasses)();
    final loadMaterials = widget.loadMaterials ?? ApiService().getMaterials;
    final entries = <(DateTime, Map<String, dynamic>)>[];
    for (final c in classes) {
      for (final m in await loadMaterials(c.id)) {
        if (m.isAssignment) entries.add((m.createdAt, _entry(c, m)));
      }
    }
    entries.sort((a, b) => b.$1.compareTo(a.$1)); // newest first
    if (!mounted) return;
    setState(() {
      _classes = classes;
      _homeworks = entries.map((e) => e.$2).toList();
      _loading = false;
    });
  }

  // Status and priority come from the due date and the hand-ins; they are not stored.
  Map<String, dynamic> _entry(ClassroomDto c, MaterialDto m) {
    final now = DateTime.now();
    final total = c.studentCount;
    final submitted = m.submissionCount;
    final due = m.dueAt;
    final status = total > 0 && submitted >= total
        ? 'Completed'
        : (due != null && due.isBefore(now) ? 'Overdue' : 'Active');
    final daysLeft = due?.difference(now).inDays;
    return {
      'id': m.id,
      'title': m.title,
      'subject': c.subjectName ?? c.name,
      'class': c.name,
      'dueDate': due == null ? 'No due date' : _date.format(due),
      'dueAt': due,
      'assignedDate': _date.format(m.createdAt),
      'status': status,
      'submitted': submitted,
      'total': total,
      'description': m.description ?? 'No description provided.',
      'priority': daysLeft == null ? 'Low' : (daysLeft < 2 ? 'High' : (daysLeft < 7 ? 'Medium' : 'Low')),
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredHomeworks {
    List<Map<String, dynamic>> filtered = _homeworks;
    if (_filterStatus != 'All') {
      filtered = filtered.where((h) => h['status'] == _filterStatus).toList();
    }
    if (_searchController.text.isNotEmpty) {
      final q = _searchController.text.toLowerCase();
      filtered = filtered
          .where(
            (h) =>
                h['title'].toString().toLowerCase().contains(q) ||
                h['subject'].toString().toLowerCase().contains(q) ||
                h['class'].toString().toLowerCase().contains(q),
          )
          .toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      body: NestedScrollView(
        physics: const BouncingScrollPhysics(),
        headerSliverBuilder: (context, _) => [_buildAppBar()],
        body: Column(
          children: [
            _buildStatsRow(),
            _buildSearchAndFilter(),
            Expanded(child: _buildHomeworkList()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      backgroundColor: const Color(0xFF0D3B66),
      elevation: 0,
      pinned: true,
      stretch: true,
      leading: Bounceable(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
      actions: [
        Bounceable(
          onTap: () => _showSortOptions(),
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sort_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D3B66), Color(0xFF14506E)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.assignment_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Homework Manager',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_homeworks.length} assignments total',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    final active = _homeworks.where((h) => h['status'] == 'Active').length;
    final overdue = _homeworks.where((h) => h['status'] == 'Overdue').length;
    final completed = _homeworks
        .where((h) => h['status'] == 'Completed')
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          _buildStatChip('Active', active, const Color(0xFF4A90E2)),
          const SizedBox(width: 10),
          _buildStatChip('Overdue', overdue, const Color(0xFFF95738)),
          const SizedBox(width: 10),
          _buildStatChip('Done', completed, const Color(0xFF27AE60)),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final filters = ['All', 'Active', 'Overdue', 'Completed'];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search homework...',
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                  size: 22,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final selected = _filterStatus == filters[i];
              return GestureDetector(
                onTap: () => setState(() => _filterStatus = filters[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF0D3B66) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF0D3B66)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Text(
                    filters[i],
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : Colors.grey.shade600,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHomeworkList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final items = _filteredHomeworks;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No homework found',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try changing the filter or search query',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildHomeworkCard(items[i]),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final status = hw['status'] as String;
    final submitted = hw['submitted'] as int;
    final total = hw['total'] as int;
    final progress = total == 0 ? 0.0 : submitted / total; // a class may have no students yet
    final priority = hw['priority'] as String;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Active':
        statusColor = const Color(0xFF4A90E2);
        statusIcon = Icons.schedule_rounded;
        break;
      case 'Overdue':
        statusColor = const Color(0xFFF95738);
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'Completed':
        statusColor = const Color(0xFF27AE60);
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
    }

    Color priorityColor;
    switch (priority) {
      case 'High':
        priorityColor = const Color(0xFFF95738);
        break;
      case 'Medium':
        priorityColor = const Color(0xFFF5A623);
        break;
      default:
        priorityColor = const Color(0xFF27AE60);
    }

    return Bounceable(
      onTap: () => _showHomeworkDetail(hw),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: status == 'Overdue'
              ? Border.all(color: statusColor.withValues(alpha: 0.3), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hw['title'],
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D3B66),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${hw['subject']}  •  ${hw['class']}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priority,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: priorityColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Description
            Text(
              hw['description'],
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),

            // Progress bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Submissions',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          Text(
                            '$submitted / $total',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D3B66),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Footer
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  'Due: ${hw['dueDate']}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: status == 'Overdue'
                        ? statusColor
                        : Colors.grey.shade500,
                    fontWeight: status == 'Overdue'
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateHomeworkSheet(),
      backgroundColor: const Color(0xFFF95738),
      elevation: 6,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        'Assign',
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 15,
        ),
      ),
    );
  }

  void _showHomeworkDetail(Map<String, dynamic> hw) {
    final status = hw['status'] as String;
    final submitted = hw['submitted'] as int;
    final total = hw['total'] as int;
    final progress = total == 0 ? 0.0 : submitted / total; // a class may have no students yet

    Color statusColor;
    switch (status) {
      case 'Active':
        statusColor = const Color(0xFF4A90E2);
        break;
      case 'Overdue':
        statusColor = const Color(0xFFF95738);
        break;
      case 'Completed':
        statusColor = const Color(0xFF27AE60);
        break;
      default:
        statusColor = Colors.grey;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hw['title'],
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D3B66),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Info chips
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildInfoChip(
                          Icons.school_rounded,
                          hw['subject'],
                          Colors.purple,
                        ),
                        _buildInfoChip(
                          Icons.class_rounded,
                          hw['class'],
                          Colors.blue,
                        ),
                        _buildInfoChip(
                          Icons.flag_rounded,
                          hw['priority'],
                          hw['priority'] == 'High'
                              ? Colors.red
                              : hw['priority'] == 'Medium'
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Description
                    Text(
                      'Description',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hw['description'],
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dates
                    _buildDetailRow(
                      Icons.event_rounded,
                      'Assigned',
                      hw['assignedDate'],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Icons.event_available_rounded,
                      'Due',
                      hw['dueDate'],
                    ),
                    const SizedBox(height: 24),

                    // Submission progress
                    Text(
                      'Submission Progress',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6F8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$submitted of $total submitted',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D3B66),
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: Bounceable(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F6F8),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  'Edit',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D3B66),
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Bounceable(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    statusColor,
                                    statusColor.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Center(
                                child: Text(
                                  'View Submissions',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey.shade400, size: 20),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF0D3B66),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showCreateHomeworkSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    // By id: the class list is reloaded (new objects) right after assigning.
    String? selectedClassId = _classes.isEmpty ? null : _classes.first.id;
    DateTime? dueDate;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Homework',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildFormLabel('Title'),
                      const SizedBox(height: 8),
                      _buildTextField(titleCtrl, 'Enter homework title'),
                      const SizedBox(height: 20),

                      _buildFormLabel('Description'),
                      const SizedBox(height: 8),
                      _buildTextField(
                        descCtrl,
                        'Enter description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      _buildFormLabel('Class'),
                      const SizedBox(height: 8),
                      if (selectedClassId == null)
                        Text(
                          'You have no classes yet.',
                          style: GoogleFonts.inter(color: Colors.grey.shade600),
                        )
                      else
                        _buildDropdown<String>(
                          value: selectedClassId!,
                          items: _classes.map((c) => c.id).toList(),
                          label: (id) => _classes.firstWhere((c) => c.id == id).name,
                          onChanged: (v) =>
                              setSheetState(() => selectedClassId = v ?? selectedClassId),
                        ),
                      const SizedBox(height: 20),

                      _buildFormLabel('Due date'),
                      const SizedBox(height: 8),
                      Bounceable(
                        key: const ValueKey('pick-due-date'),
                        onTap: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: dueDate ?? now.add(const Duration(days: 7)),
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          // Due at the end of the chosen day
                          if (picked != null) {
                            setSheetState(() => dueDate = DateTime(picked.year, picked.month, picked.day, 23, 59));
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6F8),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.event_rounded, size: 18, color: Color(0xFF0D3B66)),
                              const SizedBox(width: 10),
                              Text(
                                dueDate == null ? 'No due date' : _date.format(dueDate!),
                                style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Submit button
                      Bounceable(
                        key: const ValueKey('assign-homework'),
                        onTap: () async {
                          final title = titleCtrl.text.trim();
                          final classroom = _classes.where((c) => c.id == selectedClassId).firstOrNull;
                          if (title.isEmpty || classroom == null || saving) return;
                          setSheetState(() => saving = true);
                          final description = descCtrl.text.trim();
                          final error = await (widget.assign ?? _assignViaApi)(
                            classroom.id,
                            title,
                            description.isEmpty ? null : description,
                            dueDate,
                          );
                          if (!mounted) return;
                          setSheetState(() => saving = false);
                          if (error == null) Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error ?? 'Homework assigned to ${classroom.name}.',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              backgroundColor: error == null ? const Color(0xFF27AE60) : Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                          if (error == null) await _load();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF95738), Color(0xFFFF7A5C)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFF95738,
                                ).withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              'Assign Homework',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _assignViaApi(String classroomId, String title, String? description, DateTime? dueAt) =>
      ApiService().createAssignment(
        classroomId: classroomId,
        title: title,
        description: description,
        dueAt: dueAt,
      );

  Widget _buildFormLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF0D3B66),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController ctrl,
    String hint, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    String Function(T item)? label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: GoogleFonts.inter(fontSize: 14, color: Colors.black87),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(value: e, child: Text(label?.call(e) ?? e.toString())),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
  
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sort By',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption(
              Icons.calendar_today_rounded,
              'Due Date',
              () => _sortBy('dueDate'),
            ),
            _buildSortOption(
              Icons.flag_rounded,
              'Priority',
              () => _sortBy('priority'),
            ),
            _buildSortOption(
              Icons.bar_chart_rounded,
              'Submissions',
              () => _sortBy('submitted'),
            ),
            _buildSortOption(
              Icons.sort_by_alpha_rounded,
              'Title',
              () => _sortBy('title'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0D3B66)),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF0D3B66),
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  void _sortBy(String field) {
    setState(() {
      _homeworks.sort((a, b) {
        if (field == 'priority') {
          const order = {'High': 0, 'Medium': 1, 'Low': 2};
          return (order[a[field]] ?? 3).compareTo(order[b[field]] ?? 3);
        }
        if (field == 'dueDate') {
          // Real dates, soonest first; homework without a due date last
          final da = a['dueAt'] as DateTime?, db = b['dueAt'] as DateTime?;
          if (da == null || db == null) return da == null ? (db == null ? 0 : 1) : -1;
          return da.compareTo(db);
        }
        final va = a[field], vb = b[field];
        if (va is num && vb is num) return va.compareTo(vb);
        return va.toString().compareTo(vb.toString());
      });
    });
  }
}
