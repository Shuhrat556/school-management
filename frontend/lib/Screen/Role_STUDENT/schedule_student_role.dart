import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tamdansers/services/api_service.dart';
import 'package:tamdansers/services/api_models.dart';

class StudentScheduleScreen extends StatefulWidget {
  // Replaceable in tests; by default the timetable of every class the student is in.
  const StudentScheduleScreen({super.key, this.loadSchedule});

  final Future<List<ScheduleDto>> Function()? loadSchedule;

  @override
  State<StudentScheduleScreen> createState() => _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  int _selectedScheduleType = 1; // 0: Day, 1: Week, 2: Month

  // Design Palette
  final Color primaryTeal = const Color(0xFF0D3B66);
  final Color scaffoldBg = const Color(0xFFF3F6F8);
  final Color cardWhite = Colors.white;

  // API data
  List<ScheduleDto> _schedules = [];
  bool _scheduleLoading = true;

  static const List<Color> _accentColors = [
    Color(0xFFFFB75E),
    Color(0xFF4A90E2),
    Color(0xFFFF6B6B),
    Color(0xFFB86DFF),
    Color(0xFF50E3C2),
    Color(0xFF4A4A4A),
  ];
  static const List<IconData> _subjectIcons = [
    Icons.calculate_rounded,
    Icons.science_rounded,
    Icons.language_rounded,
    Icons.menu_book_rounded,
    Icons.biotech_rounded,
    Icons.computer_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _scheduleLoading = true);
    try {
      final schedules = await (widget.loadSchedule ?? _loadFromApi)();
      if (mounted) {
        setState(() {
          _schedules = schedules;
          _scheduleLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _scheduleLoading = false);
    }
  }

  // Sessions of all the student's classes (BUGS B44: it used to take the first class in the
  // school list, which was usually someone else's).
  Future<List<ScheduleDto>> _loadFromApi() async {
    final api = ApiService();
    final classrooms = await api.getStudentClassrooms(await api.getEntityId() ?? '');
    final sessions = <ScheduleDto>[];
    for (final c in classrooms) {
      sessions.addAll(await api.getClassroomSchedule(c.id));
    }
    return sessions;
  }

  List<Map<String, dynamic>> _schedulesToTileData() {
    return _schedules.asMap().entries.map((entry) {
      final i = entry.key;
      final s = entry.value;
      return {
        'icon': _subjectIcons[i % _subjectIcons.length],
        'title': s.subjectName,
        'time': '${s.day}, ${s.time}',
        'room': s.classroomName,
        'accent': _accentColors[i % _accentColors.length],
        'teacher': s.teacherName ?? 'TBD',
        'description': '${s.subjectName} — ${s.day} ${s.time}',
      };
    }).toList();
  }

  // Day filter: today's day name
  String get _todayDayName {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[DateTime.now().weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildModernAppBar(),
      body: _buildScheduleMainContent(),
    );
  }

  Widget _buildScheduleMainContent() {
    String headerText = 'Schedule';
    String trailingText = 'Current';

    if (_selectedScheduleType == 0) {
      headerText = 'Daily Schedule';
      trailingText = 'Today';
    } else if (_selectedScheduleType == 1) {
      headerText = 'Weekly Schedule';
      trailingText = 'Week 12';
    } else {
      headerText = 'Monthly Schedule';
      trailingText = 'Oct 2023';
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildScheduleTypeToggle(),
          const SizedBox(height: 24),
          _buildSectionHeader(headerText, trailingText),
          const SizedBox(height: 20),
          _buildViewForSelectedType(),
          const SizedBox(height: 30),
          _buildSectionHeader('Year-end Review', 'Upcoming'),
          const SizedBox(height: 16),
          _buildModernReviewBanner(),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildScheduleTypeToggle() {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _toggleButton('Day', 0),
          _toggleButton('Week', 1),
          _toggleButton('Month', 2),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, int val) {
    bool isSelected = _selectedScheduleType == val;
    return Expanded(
      child: Bounceable(
        onTap: () => setState(() => _selectedScheduleType = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected ? primaryTeal : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryTeal.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : Colors.grey.shade500,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewForSelectedType() {
    switch (_selectedScheduleType) {
      case 0:
        return _buildDailySchedule();
      case 1:
        return _buildWeeklySchedule();
      case 2:
        return _buildMonthlySchedule();
      default:
        return const SizedBox();
    }
  }

  Widget _buildDailySchedule() {
    if (_scheduleLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final todaySchedules = _schedulesToTileData()
        .where((t) => (t['time'] as String).toLowerCase().startsWith(_todayDayName.toLowerCase()))
        .toList();
    if (todaySchedules.isEmpty) {
      return Column(
        children: [
          _modernScheduleTile({
            'icon': Icons.calendar_today_rounded,
            'title': 'No classes today',
            'time': 'N/A',
            'room': '-',
            'accent': const Color(0xFF50E3C2),
            'teacher': '-',
            'description': 'Enjoy your free day!',
          }, true, isLast: true),
        ],
      );
    }
    return Column(
      children: todaySchedules.asMap().entries.map((e) {
        return _modernScheduleTile(e.value, e.key == 0,
            isLast: e.key == todaySchedules.length - 1);
      }).toList(),
    );
  }

  Widget _buildWeeklySchedule() {
    if (_scheduleLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final tiles = _schedulesToTileData();
    if (tiles.isEmpty) {
      return Column(
        children: [
          _modernScheduleTile({
            'icon': Icons.schedule_rounded,
            'title': 'No schedule available',
            'time': '-',
            'room': '-',
            'accent': const Color(0xFF4A90E2),
            'teacher': '-',
            'description': 'Schedule will appear once classes are set up.',
          }, true, isLast: true),
        ],
      );
    }
    return Column(
      children: tiles.asMap().entries.map((e) {
        return _modernScheduleTile(e.value, e.key == 0,
            isLast: e.key == tiles.length - 1);
      }).toList(),
    );
  }

  Widget _buildMonthlySchedule() {
    return Column(
      children: [
        _buildMonthSummaryCard(
          'Oct 15',
          'Mid-term Exams',
          'All Subjects',
          const Color(0xFFB86DFF),
        ),
        const SizedBox(height: 12),
        _buildMonthSummaryCard(
          'Oct 22',
          'Science Fair',
          'Main Hall',
          const Color(0xFF50E3C2),
        ),
        const SizedBox(height: 12),
        _buildMonthSummaryCard(
          'Oct 30',
          'Parent-Teacher Meeting',
          'Online',
          const Color(0xFF4A90E2),
        ),
      ],
    );
  }

  Widget _buildMonthSummaryCard(
    String date,
    String title,
    String subtitle,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              date,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF0D3B66),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernScheduleTile(
    Map<String, dynamic> data,
    bool isActive, {
    bool isLast = false,
  }) {
    final IconData icon = data['icon'];
    final String title = data['title'];
    final String time = data['time'];
    final String room = data['room'];
    final Color accent = data['accent'];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Indicator
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isActive ? accent : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent, width: 2),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content Card
          Expanded(
            child: Bounceable(
              onTap: () => _showScheduleDetail(data),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isActive
                      ? Border.all(color: accent.withValues(alpha: 0.3), width: 1)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: const Color(0xFF0D3B66),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  time,
                                  style: GoogleFonts.inter(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F6F8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        room,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF0D3B66),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleDetail(Map<String, dynamic> schedule) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                physics: const BouncingScrollPhysics(),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: schedule['accent'].withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          schedule['icon'],
                          color: schedule['accent'],
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              schedule['title'],
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D3B66),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              schedule['room'],
                              style: GoogleFonts.inter(
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailInfoRow(
                    Icons.person_rounded,
                    'Teacher',
                    schedule['teacher'],
                  ),
                  const SizedBox(height: 16),
                  _buildDetailInfoRow(
                    Icons.access_time_rounded,
                    'Schedule',
                    schedule['time'],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Lesson Overview',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    schedule['description'],
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailAction(
                          'Join Class',
                          Icons.videocam_rounded,
                          schedule['accent'],
                          true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDetailAction(
                          'View Notes',
                          Icons.description_rounded,
                          Colors.grey.shade100,
                          false,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF0D3B66), size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.grey.shade400,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D3B66),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailAction(
    String label,
    IconData icon,
    Color color,
    bool isPrimary,
  ) {
    return Bounceable(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? color : color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : const Color(0xFF0D3B66),
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: isPrimary ? Colors.white : const Color(0xFF0D3B66),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernReviewBanner() {
    return Bounceable(
      onTap: () {},
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryTeal, primaryTeal.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryTeal.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Exam Prep Mode',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Review notes and practice mock tests for upcoming exams.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Start Review',
                      style: GoogleFonts.inter(
                        color: primaryTeal,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
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

  Widget _buildSectionHeader(String title, String trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D3B66).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              trailing,
              style: GoogleFonts.inter(
                color: const Color(0xFF0D3B66),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildModernAppBar() {
    return AppBar(
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
            size: 16,
          ),
        ),
      ),
      title: Text(
        'Schedule',
        style: GoogleFonts.outfit(
          color: const Color(0xFF0D3B66),
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      centerTitle: true,
      actions: [
        Bounceable(
          onTap: () {},
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.file_download_outlined,
              color: Color(0xFF0D3B66),
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}
