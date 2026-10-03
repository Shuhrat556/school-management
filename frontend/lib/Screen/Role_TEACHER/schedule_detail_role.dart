import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tamdansers/Screen/Role_TEACHER/add_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/announce_to_parents_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/check_attendance_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/input_score_student_role.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

class TeacherScheduleDetailScreen extends StatefulWidget {
  final Map<String, dynamic> classData;
  // Replaceable in tests; by default the class is read from the API.
  final Future<ClassSnapshot?> Function(String classroomId)? loadClass;

  const TeacherScheduleDetailScreen({super.key, required this.classData, this.loadClass});

  @override
  State<TeacherScheduleDetailScreen> createState() =>
      _TeacherScheduleDetailScreenState();
}

class _TeacherScheduleDetailScreenState
    extends State<TeacherScheduleDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> data;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // The class roster with today's attendance and the subject grade (BUGS B36: was made up).
  List<Map<String, dynamic>> students = [];
  bool _loadingStudents = true;
  MaterialDto? _latestHomework;
  List<String> _materialTitles = [];

  @override
  void initState() {
    super.initState();
    data = widget.classData;
    _tabController = TabController(length: 3, vsync: this);
    _loadClass();
    _tabController.addListener(() {
      setState(() {});
    });
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Color get accent => data['accent'] ?? const Color(0xFF4A90E2);
  String get title => data['title'] ?? 'Class';
  String get time => data['time'] ?? '';
  String get room => data['room'] ?? '';
  String get topic => data['topic'] ?? 'General Lesson';
  String get description => data['description'] ?? '';
  String get homework => _latestHomework == null
      ? 'No homework assigned yet.'
      : _latestHomework!.dueAt == null
          ? _latestHomework!.title
          : '${_latestHomework!.title} (due ${DateFormat('MMM d').format(_latestHomework!.dueAt!)})';
  int get studentCount => students.length;
  List<dynamic> get materials => _materialTitles.isNotEmpty ? _materialTitles : (data['materials'] ?? []);
  bool get isDone => data['isDone'] ?? false;
  bool get isCurrent => data['isCurrent'] ?? false;

  int get presentCount =>
      students.where((s) => s['status'] == 'Present').length;
  int get lateCount => students.where((s) => s['status'] == 'Late').length;
  int get absentCount => students.where((s) => s['status'] == 'Absent').length;
  String get _dueLabel {
    final due = _latestHomework?.dueAt;
    if (_latestHomework == null) return 'None';
    if (due == null) return 'No due date';
    return due.isBefore(DateTime.now()) ? 'Overdue' : 'Due ${DateFormat('MMM d').format(due)}';
  }

  double get attendanceRate =>
      students.isEmpty ? 0 : (presentCount + lateCount) / students.length * 100;

  Future<void> _loadClass() async {
    final classroomId = data['classroomId'] as String? ?? '';
    final snapshot = classroomId.isEmpty ? null : await (widget.loadClass ?? _classFromApi)(classroomId);
    if (!mounted) return;
    setState(() {
      students = snapshot?.students ?? [];
      _latestHomework = snapshot?.latestHomework;
      _materialTitles = snapshot?.materials ?? [];
      _loadingStudents = false;
    });
  }

  static String _letter(double score) => score >= 90
      ? 'A'
      : score >= 80
          ? 'B'
          : score >= 70
              ? 'C'
              : score >= 60
                  ? 'D'
                  : 'F';

  Future<ClassSnapshot?> _classFromApi(String classroomId) async {
    final api = ApiService();
    final detail = await api.getClassroomDetail(classroomId);
    if (detail == null) return null;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final marks = {for (final a in await api.getClassroomAttendance(classroomId, today)) a.studentId: a.status};
    // Latest grade per student in this class's subject
    final grades = <String, double>{};
    if (detail.subjectId != null) {
      final all = await api.getGrades(subjectId: detail.subjectId)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      for (final g in all) {
        grades[g.studentId] = g.score;
      }
    }
    final materials = await api.getMaterials(classroomId);
    final homework = materials.where((m) => m.isAssignment).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ClassSnapshot(
      students: [
        for (final s in detail.students)
          {
            'name': '${s.firstName} ${s.lastName}'.trim(),
            'id': s.studentId.length > 8 ? s.studentId.substring(0, 8).toUpperCase() : s.studentId,
            'status': marks[s.studentId] ?? 'Not marked',
            'avatar': s.firstName.isEmpty ? '?' : s.firstName[0].toUpperCase(),
            'grade': grades[s.studentId] == null ? null : _letter(grades[s.studentId]!),
            'score': grades[s.studentId]?.round(),
          },
      ],
      latestHomework: homework.isEmpty ? null : homework.first,
      materials: materials.map((m) => m.title).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: NestedScrollView(
          physics: const BouncingScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildHeroHeader(context),
          ],
          body: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildTabBar(),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildTabContent(),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildTabContent() {
    switch (_tabController.index) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildStudentsTab();
      case 2:
        return _buildActionsTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildHeroHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.height * 0.38,
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
          onTap: () => _showOptionsSheet(context),
          child: Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.more_horiz_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent,
                    accent.withValues(alpha: 0.6),
                    const Color(0xFF0D3B66),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Decorative circles
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: 60,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Giant background icon
            Positioned(
              right: 20,
              bottom: 80,
              child: Icon(
                Icons.school_rounded,
                size: 150,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            // Main content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status badge
                    _buildStatusBadge(),
                    const SizedBox(height: 14),
                    // Title
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Topic
                    Text(
                      topic,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Info chips
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _infoChip(Icons.access_time_rounded, time),
                        _infoChip(Icons.meeting_room_rounded, 'Room $room'),
                        _infoChip(Icons.people_rounded, '$studentCount'),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Attendance mini strip
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniStat(
                            'Present',
                            '$presentCount',
                            const Color(0xFF50E3C2),
                          ),
                          _vDivider(),
                          _miniStat(
                            'Late',
                            '$lateCount',
                            const Color(0xFFFFB75E),
                          ),
                          _vDivider(),
                          _miniStat(
                            'Absent',
                            '$absentCount',
                            const Color(0xFFFF6B6B),
                          ),
                          _vDivider(),
                          _miniStat(
                            'Rate',
                            '${attendanceRate.toStringAsFixed(0)}%',
                            Colors.white,
                          ),
                        ],
                      ),
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

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: isCurrent
            ? Colors.greenAccent.withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isCurrent
              ? Colors.greenAccent.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCurrent)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 7),
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            isCurrent
                ? '🔴  Live Now'
                : isDone
                ? '✅  Completed'
                : '🕐  Upcoming',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 14),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 32,
    color: Colors.white.withValues(alpha: 0.15),
  );

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: const Color(0xFF0D3B66),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D3B66).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade500,
          labelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          dividerColor: Colors.transparent,
          splashBorderRadius: BorderRadius.circular(14),
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Students'),
            Tab(text: 'Actions'),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Today's Lesson
        _sectionCard(
          icon: Icons.lightbulb_rounded,
          iconColor: accent,
          title: "Today's Lesson",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withValues(alpha: 0.12)),
                ),
                child: Text(
                  topic,
                  style: GoogleFonts.outfit(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: GoogleFonts.inter(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Materials
        if (materials.isNotEmpty)
          _sectionCard(
            icon: Icons.inventory_2_rounded,
            iconColor: const Color(0xFF4A90E2),
            title: 'Class Materials',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: materials.asMap().entries.map((e) {
                final colors = [
                  const Color(0xFF4A90E2),
                  const Color(0xFF50E3C2),
                  const Color(0xFFB86DFF),
                  const Color(0xFFFFB75E),
                ];
                final c = colors[e.key % colors.length];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.withValues(alpha: 0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 14, color: c),
                      const SizedBox(width: 6),
                      Text(
                        e.value.toString(),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

        const SizedBox(height: 14),

        // Homework
        _sectionCard(
          icon: Icons.assignment_rounded,
          iconColor: const Color(0xFFFFB75E),
          title: 'Homework Assignment',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF95738).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _dueLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFF95738),
              ),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  homework,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0D3B66),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Submissions',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _latestHomework == null ? '—' : '${_latestHomework!.submissionCount} / ${students.length}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _latestHomework == null || students.isEmpty
                      ? 0
                      : (_latestHomework!.submissionCount / students.length).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Session Info
        _sectionCard(
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFF6C5CE7),
          title: 'Session Info',
          child: Column(
            children: [
              _infoRow(
                Icons.access_time_filled_rounded,
                'Start Time',
                time,
                const Color(0xFF6C5CE7),
              ),
              _dividerLine(),
              _infoRow(
                Icons.timer_rounded,
                'Duration',
                '60 minutes',
                const Color(0xFF4A90E2),
              ),
              _dividerLine(),
              _infoRow(
                Icons.meeting_room_rounded,
                'Room',
                'Room $room',
                const Color(0xFF50E3C2),
              ),
              _dividerLine(),
              _infoRow(
                Icons.people_rounded,
                'Enrolled',
                '$studentCount students',
                const Color(0xFFFFB75E),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
              ),
              if (trailing != null) ...[trailing],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D3B66),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine() =>
      Divider(height: 1, thickness: 1, color: Colors.grey.shade100);

  Widget _buildStudentsTab() {
    if (_loadingStudents) return const Center(child: CircularProgressIndicator());
    if (students.isEmpty) {
      return Center(
        child: Text(
          'No students are enrolled in this class.',
          style: GoogleFonts.inter(color: Colors.grey.shade500),
        ),
      );
    }
    return Column(
      children: [
        // Summary strip
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _statPill('Present', presentCount, const Color(0xFF50E3C2)),
              _statPill('Late', lateCount, const Color(0xFFFFB75E)),
              _statPill('Absent', absentCount, const Color(0xFFFF6B6B)),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_rounded, size: 15, color: accent),
                    const SizedBox(width: 5),
                    Text(
                      '${students.length} Total',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F6F8)),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: students.length,
            itemBuilder: (context, i) {
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (i * 60)),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (ctx, v, child) => Transform.translate(
                  offset: Offset(0, 18 * (1 - v)),
                  child: Opacity(opacity: v, child: child),
                ),
                child: _studentCard(students[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statPill(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> student) {
    Color statusColor;
    IconData statusIcon;
    switch (student['status']) {
      case 'Present':
        statusColor = const Color(0xFF50E3C2);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Late':
        statusColor = const Color(0xFFFFB75E);
        statusIcon = Icons.schedule_rounded;
        break;
      case 'Not marked':
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
        break;
      default:
        statusColor = const Color(0xFFFF6B6B);
        statusIcon = Icons.cancel_rounded;
    }
    return Bounceable(
      onTap: () => _showStudentSheet(student),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  student['avatar'],
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Name + ID + grade
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student['name'],
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          student['id'],
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (student['grade'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          'Grade ${student['grade']}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4A90E2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Status + score
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        student['status'],
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  student['score'] == null ? 'No grade yet' : 'Score: ${student['score']}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentSheet(Map<String, dynamic> student) {
    final statusColor = student['status'] == 'Present'
        ? const Color(0xFF50E3C2)
        : student['status'] == 'Late'
        ? const Color(0xFFFFB75E)
        : student['status'] == 'Not marked'
        ? Colors.grey
        : const Color(0xFFFF6B6B);
    final hasScore = student['score'] != null;
    final score = student['score'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.6)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  student['avatar'],
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              student['name'],
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              student['id'],
              style: GoogleFonts.inter(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _sheetStat('Grade', student['grade'] ?? '—', accent),
                const SizedBox(width: 10),
                _sheetStat(
                  'Score',
                  hasScore ? '$score%' : '—',
                  score >= 90
                      ? const Color(0xFF50E3C2)
                      : score >= 75
                      ? const Color(0xFF4A90E2)
                      : const Color(0xFFFF6B6B),
                ),
                const SizedBox(width: 10),
                _sheetStat('Status', student['status'], statusColor),
              ],
            ),
            const SizedBox(height: 20),
            // Score bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Performance Score',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      hasScore ? '$score / 100' : 'No grade yet',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      score >= 90
                          ? const Color(0xFF50E3C2)
                          : score >= 75
                          ? const Color(0xFF4A90E2)
                          : const Color(0xFFFF6B6B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Bounceable(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6F8),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.message_rounded,
                            color: Color(0xFF0D3B66),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Message',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0D3B66),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Bounceable(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent, accent.withValues(alpha: 0.8)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Profile',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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

  Widget _sheetStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Opens the action's screen; actions without a backend feature say so instead of doing nothing.
  void _openAction(Map<String, dynamic> action, String name) {
    final open = action['open'] as Widget Function()?;
    if (open != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => open()));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name is not available yet.'), behavior: SnackBarBehavior.floating),
    );
  }

  Widget _buildActionsTab() {
    final actions = [
      {
        'label': 'Take Attendance',
        'open': () => const AttendanceScreen(),
        'icon': Icons.fact_check_rounded,
        'color': const Color(0xFF50E3C2),
        'sub': 'Mark today\'s roll call',
      },
      {
        'label': 'Input Scores',
        'open': () => const ScoreInputScreen(),
        'icon': Icons.assessment_rounded,
        'color': const Color(0xFFB86DFF),
        'sub': 'Enter exam & quiz grades',
      },
      {
        'label': 'Lesson Plan',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF4A90E2),
        'sub': 'View full lesson details',
      },
      {
        'label': 'Add Materials',
        'icon': Icons.post_add_rounded,
        'color': const Color(0xFFFFB75E),
        'sub': 'Upload class resources',
      },
      {
        'label': 'Class Notes',
        'icon': Icons.sticky_note_2_rounded,
        'color': const Color(0xFFF95738),
        'sub': 'Share with students',
      },
      {
        'label': 'Announce',
        'open': () => const AnnounceToParentsScreen(),
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFF6C5CE7),
        'sub': 'Notify parents & students',
      },
    ];

    final settings = [
      {
        'icon': Icons.edit_rounded,
        'title': 'Edit Class Info',
        'sub': 'Update room, schedule or topic',
        'color': const Color(0xFF4A90E2),
        'divider': true,
      },
      {
        'icon': Icons.person_add_rounded,
        'title': 'Add Students',
        'open': () => const AddStudentScreen(),
        'sub': 'Enroll new students',
        'color': const Color(0xFF50E3C2),
        'divider': true,
      },
      {
        'icon': Icons.file_download_rounded,
        'title': 'Export Report',
        'sub': 'Download class as PDF',
        'color': const Color(0xFFFFB75E),
        'divider': true,
      },
      {
        'icon': Icons.notifications_rounded,
        'title': 'Send Notification',
        'open': () => const AnnounceToParentsScreen(),
        'sub': 'Push alert to all',
        'color': const Color(0xFFB86DFF),
        'divider': false,
      },
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D3B66),
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.25,
          ),
          itemCount: actions.length,
          itemBuilder: (context, i) {
            final a = actions[i];
            final c = a['color'] as Color;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (i * 80)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (ctx, v, child) => Transform.scale(
                scale: 0.8 + 0.2 * v,
                child: Opacity(opacity: v, child: child),
              ),
              child: Bounceable(
                onTap: () => _openAction(a, a['label'] as String),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: c.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(a['icon'] as IconData, color: c, size: 22),
                      ),
                      const Spacer(),
                      Text(
                        a['label'] as String,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a['sub'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          'Class Settings',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D3B66),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: settings.map((s) {
              final c = s['color'] as Color;
              return Column(
                children: [
                  Bounceable(
                    onTap: () => _openAction(s, s['title'] as String),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: c.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              s['icon'] as IconData,
                              color: c,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['title'] as String,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: const Color(0xFF0D3B66),
                                  ),
                                ),
                                Text(
                                  s['sub'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: Colors.grey.shade300,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (s['divider'] as bool)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 56,
                      color: Colors.grey.shade100,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Bounceable(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.share_rounded,
                color: Color(0xFF0D3B66),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Bounceable(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isCurrent
                          ? 'Session is live!'
                          : isDone
                          ? 'Session completed.'
                          : 'Starting session...',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    isCurrent
                        ? '📖  View Details'
                        : isDone
                        ? '📋  View Summary'
                        : '🚀  Start Session',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
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

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Class Options',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 20),
            _optionTile(
              Icons.edit_rounded,
              'Edit Class',
              'Update info or schedule',
              const Color(0xFF4A90E2),
              ctx,
            ),
            _optionTile(
              Icons.person_add_rounded,
              'Add Student',
              'Enroll new student',
              const Color(0xFF50E3C2),
              ctx,
            ),
            _optionTile(
              Icons.notifications_active_rounded,
              'Send Notification',
              'Alert students & parents',
              const Color(0xFFFFB75E),
              ctx,
            ),
            _optionTile(
              Icons.file_download_rounded,
              'Export Report',
              'Download class PDF',
              const Color(0xFFB86DFF),
              ctx,
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    BuildContext ctx,
  ) {
    return Bounceable(
      onTap: () => Navigator.pop(ctx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6F8),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 15,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
