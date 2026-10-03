import 'package:carousel_slider/carousel_slider.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:tamdansers/Controller/activity_list_widget.dart';
import 'package:tamdansers/Controller/course_card_widget.dart';
import 'package:tamdansers/Controller/messaging_unavailable.dart';
import 'package:tamdansers/Screen/Edit-Profile/student_edit_profile.dart';
import 'package:tamdansers/Screen/Role_STUDENT/attendance_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/course_student.role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/homework_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/notification_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/permision_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/schedule_student_role.dart';
import 'package:tamdansers/Screen/Role_STUDENT/score_student_role.dart';
import 'package:tamdansers/Screen/setting/setting_role_student.dart';
import 'package:tamdansers/constants/app_image.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

// MAIN DASHBOARD
class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _pageIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      const StudentHomeContent(),
      const StudentCoursesTab(),
      const StudentMessagesTab(),
      const StudentSettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      body: IndexedStack(index: _pageIndex, children: _screens),
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        index: _pageIndex,
        height: 65.0,
        items: const <Widget>[
          Icon(Icons.dashboard_rounded, size: 28, color: Colors.white),
          Icon(Icons.auto_stories_rounded, size: 28, color: Colors.white),
          Icon(Icons.forum_rounded, size: 28, color: Colors.white),
          Icon(Icons.person_outline_rounded, size: 28, color: Colors.white),
        ],
        color: const Color(0xFF0D3B66), // Deep professional blue
        buttonBackgroundColor: const Color(0xFFF95738), // Vibrant Accent
        backgroundColor: const Color(0xFFF3F6F8),
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) => setState(() => _pageIndex = index),
      ),
    );
  }
}

// STUDENT HOME CONTENT

class StudentHomeContent extends StatefulWidget {
  // The calls can be replaced in tests; by default they go to the API.
  const StudentHomeContent({super.key, this.loadAnnouncements, this.loadGrades});

  final Future<List<AnnouncementDto>> Function()? loadAnnouncements;
  final Future<List<GradeDto>> Function()? loadGrades;

  @override
  State<StudentHomeContent> createState() => _StudentHomeContentState();
}

class _StudentHomeContentState extends State<StudentHomeContent> {
  String _userName = '';
  int _currentCarouselIndex = 0;
  final ApiService _api = ApiService();

  // Real data for the home page; it used to show sample events and a fixed "75%" course.
  List<Map<String, dynamic>> _events = [];
  List<GradeDto> _grades = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadDashboard();
  }

  Future<void> _loadUserData() async {
    final name = await _api.getUserName();
    if (mounted) setState(() => _userName = name ?? 'Student');
  }

  Future<void> _loadDashboard() async {
    final announcements = await (widget.loadAnnouncements ?? _api.getAnnouncements)();
    final grades = await (widget.loadGrades ??
        () async => _api.getGrades(studentId: await _api.getEntityId() ?? ''))();
    if (!mounted) return;
    setState(() {
      _events = eventsFromAnnouncements(announcements);
      // Latest first
      _grades = grades..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Widget _progressCard(GradeDto g) => Bounceable(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailScreen(
              title: g.subjectName,
              progress: (g.score / 100).clamp(0, 1).toDouble(),
              semester: g.semester,
            ),
          ),
        ),
        child: CourseProgressCard(
          title: g.subjectName,
          subtitle: '${g.semester} • score ${g.score.toStringAsFixed(1)}',
          progress: (g.score / 100).clamp(0, 1).toDouble(),
          percentage: '${g.score.round()}%',
          imagePath: AppImages.subjectMath,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 25),
            _buildModernHeader(context),
            const SizedBox(height: 35),

            _buildModernSectionTitle("Academic Options"),
            const SizedBox(height: 20),
            _buildModernGridMenu(context),
            const SizedBox(height: 35),

            // PROGRESS SECTION
            _buildModernSectionTitle(
              "Current Progress",
              actionText: "View All",
              onActionTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AllProgressScreen(grades: _grades),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_grades.isEmpty)
              Text(
                "No grades yet.",
                style: GoogleFonts.inter(color: Colors.grey.shade500),
              )
            else
              _progressCard(_grades.first),

            const SizedBox(height: 40),
            // EVENTS SECTION
            _buildModernSectionTitle(
              "School Events",
              actionText: "See All",
              onActionTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SchoolEventsListScreen(events: _events),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildEnhancedActivitySlider(),

            const SizedBox(height: 40),
            _buildModernSectionTitle(
              "Recent Activity",
              actionText: "View All",
              onActionTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AllActivityScreen(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const ActivityList(limit: 2),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildModernHeader(BuildContext context) {
    return Row(
      children: [
        Bounceable(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StudentEditProfileScreen(),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage(
                  'https://img.freepik.com/free-vector/mans-face-flat-style_90220-2877.jpg?semt=ais_hybrid&w=740&q=80',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome back,",
              style: GoogleFonts.inter(
                color: Colors.grey.shade500,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              _userName,
              style: GoogleFonts.outfit(
                color: const Color(0xFF0D3B66),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        const Spacer(),
        Bounceable(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NotificationScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Stack(
              children: [
                Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF0D3B66),
                  size: 26,
                ),
                Positioned(
                  right: 2,
                  top: 2,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: Color(0xFFF95738),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernSectionTitle(
    String title, {
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: const Color(0xFF0D3B66),
          ),
        ),
        if (actionText != null)
          Bounceable(
            onTap: onActionTap ?? () {},
            child: Text(
              actionText,
              style: GoogleFonts.inter(
                color: const Color(0xFF4A90E2),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildModernGridMenu(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: [
        _buildModernMenuIcon(
          context,
          Icons.calendar_month_rounded,
          "Attendance",
          const Color(0xFFFFB75E),
          const AttendanceDashboard(),
        ),
        _buildModernMenuIcon(
          context,
          Icons.analytics_rounded,
          "Scores",
          const Color(0xFF50E3C2),
          const StudentScoreScreen(),
        ),
        _buildModernMenuIcon(
          context,
          Icons.assignment_ind_rounded,
          "Permission",
          const Color(0xFF4A90E2),
          const StudentPermissionScreen(),
        ),
        _buildModernMenuIcon(
          context,
          Icons.history_edu_rounded,
          "Homework",
          const Color(0xFFB86DFF),
          const StudentHomeworkScreen(),
        ),
        _buildModernMenuIcon(
          context,
          Icons.timer_rounded,
          "Schedule",
          const Color(0xFFF95738),
          const StudentScheduleScreen(),
        ),
        _buildModernMenuIcon(
          context,
          Icons.menu_book_rounded,
          "Course",
          const Color(0xFF4A90E2),
          const ClassCourseStudentScreen(),
        ),
      ],
    );
  }

  Widget _buildModernMenuIcon(
    BuildContext context,
    IconData icon,
    String label,
    Color color,
    Widget screen,
  ) {
    return Bounceable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => screen),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ENHANCED CAROUSEL SLIDER
  Widget _buildEnhancedActivitySlider() {
    final events = _events;
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          "No announcements yet.",
          style: GoogleFonts.inter(color: Colors.grey.shade500),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Upcoming Events",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  Text(
                    "${events.length} events this season",
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              // Live pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF95738).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF95738).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF95738),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "LIVE",
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF95738),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        CarouselSlider.builder(
          itemCount: events.length,
          itemBuilder: (context, index, realIndex) {
            final event = events[index];
            final Color accentColor = _getCategoryColor(event["category"]);
            return Bounceable(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EventDetailScreen(event: event),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(event["img"], fit: BoxFit.cover),

                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),

                      Positioned(
                        top: -30,
                        left: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.18),
                          ),
                        ),
                      ),

                      Positioned(
                        top: 18,
                        left: 18,
                        right: 18,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Category
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getCategoryIcon(event["category"]),
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    event["category"],
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Attendees pill (glassmorphism)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                color: Colors.white.withValues(alpha: 0.18),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.people_alt_rounded,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${event["attendees"]}",
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      Positioned(
                        bottom: 12,
                        left: 16,
                        right: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.13),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Title
                                Text(
                                  event["title"],
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                // Date & location chips
                                Row(
                                  children: [
                                    _infoChip(
                                      Icons.calendar_today_rounded,
                                      event["date"],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _infoChip(
                                        Icons.location_on_rounded,
                                        event["location"],
                                        expand: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Time + arrow CTA
                                Row(
                                  children: [
                                    Expanded(
                                      child: _infoChip(
                                        Icons.access_time_rounded,
                                        event["time"],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentColor,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            "Details",
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height * 0.38,
            enlargeCenterPage: true,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 700),
            autoPlayCurve: Curves.easeInOutCubic,
            pauseAutoPlayOnTouch: true,
            viewportFraction: 0.88,
            enlargeFactor: 0.22,
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
          ),
        ),

        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: events.asMap().entries.map((entry) {
            final bool isActive = entry.key == _currentCarouselIndex;
            final Color dotColor = _getCategoryColor(
              events[entry.key]["category"],
            );
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              width: isActive ? 28 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isActive
                    ? dotColor
                    : const Color(0xFF0D3B66).withValues(alpha: 0.18),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// Small frosted-glass info chip used inside carousel card
  Widget _infoChip(IconData icon, String label, {bool expand = false}) {
    Widget content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 12),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: Colors.white.withValues(alpha: 0.15),
        child: content,
      ),
    );
  }

  // Helper method for category colors
  Color _getCategoryColor(String category) {
    switch (category) {
      case "Sports":
        return const Color(0xFFFFB75E);
      case "Technology":
        return const Color(0xFF4A90E2);
      case "Science":
        return const Color(0xFF50E3C2);
      case "Arts":
        return const Color(0xFFB86DFF);
      default:
        return const Color(0xFFF95738);
    }
  }

  // Helper method for category icons
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "Sports":
        return Icons.sports_soccer_rounded;
      case "Technology":
        return Icons.computer_rounded;
      case "Science":
        return Icons.science_rounded;
      case "Arts":
        return Icons.music_note_rounded;
      default:
        return Icons.event_rounded;
    }
  }
}

class AllProgressScreen extends StatelessWidget {
  final List<GradeDto> grades;

  const AllProgressScreen({super.key, this.grades = const []});

  @override
  Widget build(BuildContext context) {
    final courses = [
      for (final g in grades)
        {
          "title": g.subjectName,
          "sub": "${g.semester} • score ${g.score.toStringAsFixed(1)}",
          "prog": (g.score / 100).clamp(0, 1).toDouble(),
          "semester": g.semester,
        },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        title: Text(
          "All Course Progress",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D3B66),
          ),
        ),
        foregroundColor: const Color(0xFF0D3B66),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final course = courses[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Bounceable(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CourseDetailScreen(
                    title: course["title"] as String,
                    progress: course["prog"] as double,
                    semester: course["semester"] as String?,
                  ),
                ),
              ),
              child: CourseProgressCard(
                title: course["title"] as String,
                subtitle: course["sub"] as String,
                progress: course["prog"] as double,
                percentage: "${((course["prog"] as double) * 100).toInt()}%",
                imagePath: AppImages.subjectMath,
              ),
            ),
          );
        },
      ),
    );
  }
}

class CourseDetailScreen extends StatelessWidget {
  final String title;
  final double progress; // the score as 0..1
  final String? semester;

  const CourseDetailScreen({
    super.key,
    required this.title,
    required this.progress,
    this.semester,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0D3B66),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                image: const DecorationImage(
                  image: AssetImage(AppImages.subjectMath),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Score",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      Text(
                        "${(progress * 100).toInt()}%",
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF50E3C2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      color: const Color(0xFF50E3C2),
                      backgroundColor: Colors.grey.shade100,
                    ),
                  ),
                ],
              ),
            ),
            if (semester != null) ...[
              const SizedBox(height: 30),
              Text(
                "Semester: $semester",
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0D3B66),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// EVENT SCREENS
// =============================================================================
class SchoolEventsListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const SchoolEventsListScreen({super.key, this.events = const []});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        title: Text(
          "Upcoming Events",
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D3B66),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0D3B66),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemCount: events.length,
        itemBuilder: (context, index) => Bounceable(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EventDetailScreen(event: events[index]),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: Image.asset(
                        events[index]["img"],
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(events[index]["category"]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          events[index]["category"],
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              events[index]["title"],
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: const Color(0xFF0D3B66),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 14,
                                  color: Color(0xFFF95738),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  events[index]["date"],
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFF95738),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Color(0xFF4A90E2),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  events[index]["time"].split(" - ")[0],
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF4A90E2),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F6F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF0D3B66),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Sports":
        return const Color(0xFFFFB75E);
      case "Technology":
        return const Color(0xFF4A90E2);
      case "Science":
        return const Color(0xFF50E3C2);
      case "Arts":
        return const Color(0xFFB86DFF);
      default:
        return const Color(0xFFF95738);
    }
  }
}

class EventDetailScreen extends StatelessWidget {
  final Map<String, dynamic> event;
  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        title: Text(
          event["title"],
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        foregroundColor: const Color(0xFF0D3B66),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                Image.asset(
                  event["img"],
                  height: 280,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(event["category"]),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: _getCategoryColor(
                            event["category"],
                          ).withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      event["category"],
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              transform: Matrix4.translationValues(0.0, -30.0, 0.0),
              padding: const EdgeInsets.all(30),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F6F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildInfoChip(
                        Icons.calendar_month_rounded,
                        event["date"],
                        const Color(0xFFF95738),
                      ),
                      _buildInfoChip(
                        Icons.access_time_rounded,
                        event["time"],
                        const Color(0xFF4A90E2),
                      ),
                      _buildInfoChip(
                        Icons.location_on_rounded,
                        event["location"],
                        const Color(0xFF50E3C2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Attendees count
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF0D3B66,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.people_rounded,
                                color: Color(0xFF0D3B66),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Attendees",
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  "${event["attendees"]} people",
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF0D3B66),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF50E3C2,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "${((event["attendees"] / 500) * 100).toInt()}% capacity",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF50E3C2),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // About Event
                  Text(
                    "About Event",
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event["description"] ?? "No description available.",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Register button
                  Bounceable(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Registered for ${event["title"]}"),
                          backgroundColor: const Color(0xFF0D3B66),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D3B66), Color(0xFF1E5B94)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0D3B66,
                            ).withValues(alpha: 0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          "Register for Event",
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label.length > 10 ? "${label.substring(0, 8)}..." : label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case "Sports":
        return const Color(0xFFFFB75E);
      case "Technology":
        return const Color(0xFF4A90E2);
      case "Science":
        return const Color(0xFF50E3C2);
      case "Arts":
        return const Color(0xFFB86DFF);
      default:
        return const Color(0xFFF95738);
    }
  }
}

class AllActivityScreen extends StatefulWidget {
  const AllActivityScreen({super.key});

  @override
  State<AllActivityScreen> createState() => _AllActivityScreenState();
}

class _AllActivityScreenState extends State<AllActivityScreen> {
  String selectedFilter = "All";
  final List<String> filters = [
    "All",
    "Science",
    "Biology",
    "Math",
    "Literature",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120.0,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: const Color(0xFF0D3B66),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                "Recent Activities",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0D3B66), Color(0xFF1E5B94)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    "Track your progress",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filters.length,
                    itemBuilder: (context, index) {
                      final filter = filters[index];
                      final bool isSelected = selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Bounceable(
                          onTap: () => setState(() => selectedFilter = filter),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0D3B66)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF0D3B66,
                                        ).withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                filter,
                                style: GoogleFonts.inter(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: ActivityList(isDetailed: true),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STUDENT COURSES TAB (Embedded – No AppBar Back Button)
// =============================================================================
class StudentCoursesTab extends StatefulWidget {
  const StudentCoursesTab({super.key});

  @override
  State<StudentCoursesTab> createState() => _StudentCoursesTabState();
}

class _StudentCoursesTabState extends State<StudentCoursesTab> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  bool _isLoading = true;

  final List<String> _categories = ['All', 'Active', 'Inactive'];

  List<Map<String, dynamic>> _allCourses = [];

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    try {
      final classrooms = await ApiService().getClassrooms();
      final List<Color> colors = [
        const Color(0xFF4A90E2),
        const Color(0xFFFFB75E),
        const Color(0xFF50E3C2),
        const Color(0xFFB86DFF),
        const Color(0xFFF95738),
        const Color(0xFF4A4A4A),
        const Color(0xFF0D3B66),
        const Color(0xFF6C5CE7),
      ];
      final List<IconData> icons = [
        Icons.calculate_rounded,
        Icons.bolt_rounded,
        Icons.science_rounded,
        Icons.palette_rounded,
        Icons.biotech_rounded,
        Icons.museum_rounded,
        Icons.computer_rounded,
        Icons.auto_stories_rounded,
      ];
      if (mounted) {
        setState(() {
          _allCourses = classrooms.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return {
              'title': c.name,
              'lessons': '${c.studentCount} Students',
              'progress': 0.0,
              'percent': '${c.studentCount}',
              'color': colors[i % colors.length],
              'icon': icons[i % icons.length],
              'category': c.isActive ? 'Active' : 'Inactive',
              'teacher': c.teacherName ?? 'No teacher',
              'rating': 0.0,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredCourses {
    return _allCourses.where((c) {
      final matchCategory =
          _selectedCategory == 'All' || c['category'] == _selectedCategory;
      final matchSearch = c['title'].toString().toLowerCase().contains(
        _searchQuery,
      );
      return matchCategory && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4A90E2), Color(0xFF6FB1FC)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A90E2).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Courses',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                    Text(
                      '${_allCourses.length} courses enrolled',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Color(0xFF0D3B66),
                    size: 22,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D3B66), Color(0xFF1E5B94)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D3B66).withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    height: 70,
                    width: 70,
                    child: Stack(
                      children: [
                        SizedBox(
                          height: 70,
                          width: 70,
                          child: CircularProgressIndicator(
                            value: _allCourses.isEmpty
                                ? 0.0
                                : _allCourses
                                          .where(
                                            (c) => c['category'] == 'Active',
                                          )
                                          .length /
                                      _allCourses.length,
                            strokeWidth: 7,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF50E3C2),
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Center(
                          child: Text(
                            _isLoading ? '...' : '${_allCourses.length}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Classrooms',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_allCourses.where((c) => c['category'] == 'Active').length} active classrooms',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF50E3C2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_allCourses.length}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF0D3B66),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                style: GoogleFonts.inter(
                  color: const Color(0xFF0D3B66),
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search courses...',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey.shade400,
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Bounceable(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF0D3B66)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFF0D3B66,
                                  ).withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade600,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          _filteredCourses.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 40, bottom: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No courses found',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                  itemCount: _filteredCourses.length,
                  itemBuilder: (context, index) {
                    final course = _filteredCourses[index];
                    return _buildCourseCard(course);
                  },
                ),
          const SizedBox(height: 16),
        ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final Color accent = course['color'] as Color;
    return Bounceable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LessonDetailScreen(course: course),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                height: 62,
                width: 62,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  course['icon'] as IconData,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'] as String,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course['teacher'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFB75E),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${course['rating']}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: course['progress'] as double,
                              minHeight: 6,
                              backgroundColor: const Color(0xFFF3F6F8),
                              color: accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          course['percent'] as String,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF0D3B66),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// STUDENT MESSAGES TAB (no messaging backend yet — PLAN F9)
// =============================================================================
class StudentMessagesTab extends StatelessWidget {
  const StudentMessagesTab({super.key});

  @override
  Widget build(BuildContext context) => MessagingUnavailable(
        explanation: "Your teachers' announcements, new grades and absences arrive in Notifications. "
            'To ask to be excused from classes, send a leave request.',
        actions: [
          (Icons.notifications_active_rounded, 'Notifications', (_) => const NotificationScreen()),
          (Icons.event_busy_rounded, 'Ask for leave', (_) => const StudentPermissionScreen()),
        ],
      );
}

const _eventImages = [AppImages.event1, AppImages.event2, AppImages.event3, AppImages.grade1];

// Published announcements in the shape the event cards use. The badge that used to show
// a made-up attendee count shows the author.
List<Map<String, dynamic>> eventsFromAnnouncements(List<AnnouncementDto> announcements) => [
      for (var i = 0; i < announcements.length; i++)
        {
          "title": announcements[i].title,
          "date": DateFormat('dd MMM yyyy').format(announcements[i].publishedAt),
          "time": DateFormat('h:mm a').format(announcements[i].publishedAt),
          "location": announcements[i].classroomName ?? "Whole school",
          "img": _eventImages[i % _eventImages.length],
          "category": "Announcement",
          "attendees": announcements[i].authorName,
          "description": announcements[i].body,
        },
    ];
