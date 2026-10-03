import 'package:carousel_slider/carousel_slider.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tamdansers/Screen/Edit-Profile/teacher_edit_profile.dart';
import 'package:tamdansers/Screen/Role_TEACHER/announce_to_parents_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/check_attendance_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/course_learn_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/homework_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/input_score_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/link_parent_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/management_class_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/notifications_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/result_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/schedule_student_role.dart';
import 'package:tamdansers/Screen/Role_TEACHER/student_list_screen.dart';
import 'package:tamdansers/Screen/Role_TEACHER/teacher_list_screen.dart';
import 'package:tamdansers/Screen/setting/linked_accounts_screen.dart';
import 'package:tamdansers/constants/app_image.dart';
import 'package:tamdansers/routes/app_routes.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});
  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  int _pageIndex = 0;
  final GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    // Build once and cache — IndexedStack keeps state alive between tab switches.
    _screens = const [
      TeacherHomeContent(),
      TeacherCoursesTab(),
      TeacherMessagesTab(),
      TeacherSettingsScreen(),
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
          Icon(Icons.tune_rounded, size: 28, color: Colors.white),
        ],
        color: const Color(0xFF0D3B66),
        buttonBackgroundColor: const Color(0xFFF95738),
        backgroundColor: const Color(0xFFF3F6F8),
        animationCurve: Curves.easeInOutCubic,
        animationDuration: const Duration(milliseconds: 400),
        onTap: (index) {
          setState(() {
            _pageIndex = index;
          });
        },
      ),
    );
  }
}

// ----------------------------------------------------------------------
// 2. HOME SCREEN CONTENT (INDEX 0)
// ----------------------------------------------------------------------
class TeacherHomeContent extends StatefulWidget {
  const TeacherHomeContent({super.key});

  @override
  State<TeacherHomeContent> createState() => _TeacherHomeContentState();
}

class _TeacherHomeContentState extends State<TeacherHomeContent> {
  String _userName = '';
  bool _isToolsExpanded = false;
  bool _isLoading = true;
  int _currentCarouselIndex = 0;

  // API data
  List<StudentDto> _students = [];
  List<TeacherDto> _teachers = [];
  List<ClassroomDto> _classrooms = [];

  // Define your tools with their corresponding destination screens
  static final List<ManagementTool> managementTools = [
    ManagementTool(
      name: 'Classes',
      icon: Icons.door_front_door,
      color: Colors.blue,
      screen: const TeacherManagementClassScreen(),
    ),
    ManagementTool(
      name: 'Attendance',
      icon: Icons.person,
      color: Colors.green,
      screen: const AttendanceScreen(),
    ),
    ManagementTool(
      name: 'Courses',
      icon: Icons.book,
      color: Colors.purple,
      screen: const TeacherCourseScreen(),
    ),
    ManagementTool(
      name: 'Students',
      icon: Icons.group_add,
      color: Colors.orange,
      screen: const StudentListScreen(),
    ),
    ManagementTool(
      name: 'Grades',
      icon: Icons.assessment,
      color: Colors.red,
      screen: const ScoreInputScreen(),
    ),
    ManagementTool(
      name: 'Results',
      icon: Icons.leaderboard_rounded,
      color: Colors.deepPurple,
      screen: const StudentResultScreen(),
    ),
    ManagementTool(
      name: 'Schedule',
      icon: Icons.calendar_month,
      color: Colors.teal,
      screen: const TeacherScheduleScreen(),
    ),
    ManagementTool(
      name: 'Parents',
      icon: Icons.family_restroom_rounded,
      color: const Color(0xFF8E44AD),
      screen: const ParentManagementScreen(),
    ),

    ManagementTool(
      name: 'Homework',
      icon: Icons.assignment_turned_in_rounded,
      color: const Color(0xFF2ECC71),
      screen: const TeacherHomeworkScreen(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSchoolData();
  }

  Future<void> _loadUserData() async {
    final name = await ApiService().getUserName();
    if (mounted) {
      setState(() {
        _userName = name ?? 'Alexander Smith';
      });
    }
  }

  Future<void> _loadSchoolData() async {
    try {
      final api = ApiService();
      final results = await Future.wait([
        api.getStudents(),
        api.getTeachers(),
        api.getClassrooms(),
      ]);
      if (mounted) {
        setState(() {
          _students = results[0] as List<StudentDto>;
          _teachers = results[1] as List<TeacherDto>;
          _classrooms = results[2] as List<ClassroomDto>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildTeacherHeader(context),
            ),
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildGlassOverviewCard(),
            ),
            const SizedBox(height: 35),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSectionTitle(
                "Management Tools",
                actionText: _isToolsExpanded ? "Show Less" : "View All",
                onActionTap: () {
                  setState(() {
                    _isToolsExpanded = !_isToolsExpanded;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildToolsGrid(),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildModernAnnouncementTile(),
            ),
            const SizedBox(height: 35),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSectionTitle("Quick Actions"),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildQuickActions(),
            ),
            const SizedBox(height: 30),
            _buildEventCarousel(),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSectionTitle(
                "Today's Classes",
                actionText: "Full Schedule",
                onActionTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TeacherAllClassesScreen(classes: _buildClassData()),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildModernTimelineSchedule(),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // Clean Management Tools Grid with click functionality
  Widget _buildToolsGrid() {
    // Show only first 6 items when collapsed, all 9 when expanded
    final displayedTools = _isToolsExpanded
        ? managementTools
        : managementTools.take(6).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.9,
        ),
        itemCount: displayedTools.length,
        itemBuilder: (context, index) {
          final tool = displayedTools[index];
          return _buildClickableToolCard(tool);
        },
      ),
    );
  }

  // Clickable Tool Card
  Widget _buildClickableToolCard(ManagementTool tool) {
    return Bounceable(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => tool.screen));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tool.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(tool.icon, color: tool.color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              tool.name,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Event Carousel ───────────────────────────────────────────────────────
  Widget _buildEventCarousel() {
    final List<Map<String, dynamic>> events = [
      {
        "title": "Annual Sports Day",
        "date": "14 Oct 2026",
        "time": "10:00 AM - 4:00 PM",
        "location": "School Grounds",
        "img": AppImages.event1,
        "category": "Sports",
        "attendees": 245,
        "description":
            "Join us for a day of athletic excellence and teamwork! Featuring track & field events, team sports, and fun activities for everyone.",
      },
      {
        "title": "Tech Exhibition",
        "date": "20 Oct 2026",
        "time": "9:00 AM - 3:00 PM",
        "location": "Innovation Lab",
        "img": AppImages.event2,
        "category": "Technology",
        "attendees": 189,
        "description":
            "Showcasing the latest student innovations in robotics, software development, and engineering projects.",
      },
      {
        "title": "Science Fair 2026",
        "date": "12 Nov 2026",
        "time": "11:00 AM - 5:00 PM",
        "location": "Science Hall",
        "img": AppImages.event3,
        "category": "Science",
        "attendees": 312,
        "description":
            "Explore groundbreaking experiments and discoveries presented by our talented young scientists.",
      },
      {
        "title": "Music Festival",
        "date": "05 Dec 2026",
        "time": "2:00 PM - 8:00 PM",
        "location": "Auditorium",
        "img": AppImages.event2,
        "category": "Arts",
        "attendees": 450,
        "description":
            "A celebration of student musical talent featuring bands, choirs, and solo performances.",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
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
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TeacherEventsListScreen(),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D3B66).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF0D3B66).withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "View All",
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0D3B66),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: Color(0xFF0D3B66),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Carousel
        CarouselSlider.builder(
          itemCount: events.length,
          itemBuilder: (context, index, realIndex) {
            final event = events[index];
            final Color accent = _evtColor(event["category"]);
            return Bounceable(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherEventDetailScreen(event: event),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image
                      Image.asset(event["img"], fit: BoxFit.cover),
                      // Scrim
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withValues(alpha: 0.15),
                              Colors.black.withValues(alpha: 0.55),
                              Colors.black.withValues(alpha: 0.85),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Decorative glow orb
                      Positioned(
                        top: -30,
                        left: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                      // Top row: category chip + attendees
                      Positioned(
                        top: 18,
                        left: 18,
                        right: 18,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withValues(alpha: 0.45),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _evtIcon(event["category"]),
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
                      // Bottom glassmorphism card
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
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
                                Text(
                                  event["title"],
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _evtChip(
                                      Icons.calendar_today_rounded,
                                      event["date"],
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _evtChip(
                                        Icons.location_on_rounded,
                                        event["location"],
                                        expand: true,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _evtChip(
                                      Icons.access_time_rounded,
                                      event["time"],
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 7,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accent,
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
              setState(() => _currentCarouselIndex = index);
            },
          ),
        ),

        // Animated pill indicators
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: events.asMap().entries.map((entry) {
            final bool isActive = entry.key == _currentCarouselIndex;
            final Color dotColor = _evtColor(events[entry.key]["category"]);
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

  Widget _evtChip(IconData icon, String label, {bool expand = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        color: Colors.white.withValues(alpha: 0.15),
        child: Row(
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
        ),
      ),
    );
  }

  Color _evtColor(String category) {
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

  IconData _evtIcon(String category) {
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

  Widget _buildSectionTitle(
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
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D3B66),
          ),
        ),
        if (actionText != null)
          GestureDetector(
            onTap: onActionTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF95738).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionText,
                style: GoogleFonts.inter(
                  color: const Color(0xFFF95738),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTeacherHeader(BuildContext context) {
    return Row(
      children: [
        Bounceable(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TeacherEditProfileScreen(),
              ),
            );
          },
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Good Morning,",
                style: GoogleFonts.inter(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Bounceable(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TeacherNotificationScreen(),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF0D3B66),
                  size: 24,
                ),
                Positioned(
                  right: -2,
                  top: -2,
                  child: CircleAvatar(
                    radius: 5,
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

  Widget _buildGlassOverviewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D3B66), Color(0xFF1E5B94)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D3B66).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.school,
              size: 120,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Academic Overview",
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Semester 2 • 2023-24",
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      "Active",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildModernStatItem(
                    "Classes",
                    _isLoading
                        ? "..."
                        : _classrooms.length.toString().padLeft(2, '0'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherManagementClassScreen(),
                      ),
                    ),
                  ),
                  _buildModernStatItem(
                    "Students",
                    _isLoading ? "..." : _students.length.toString(),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentListScreen(),
                      ),
                    ),
                  ),
                  _buildModernStatItem(
                    "Teachers",
                    _isLoading ? "..." : _teachers.length.toString(),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherListScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernStatItem(
    String label,
    String value, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: onTap != null ? 0.12 : 0.0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernAnnouncementTile() {
    return Bounceable(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AnnounceToParentsScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.campaign_rounded,
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
                    "Announce to Parents",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Send an important update",
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
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
                color: Color(0xFF0D3B66),
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildModernActionCard(
          Icons.qr_code_scanner_rounded,
          "Scan ID",
          const Color(0xFF00C4FF),
          onTap: () => _showFeatureComingSoon("Scan ID"),
        ),
        _buildModernActionCard(
          Icons.family_restroom_rounded,
          "Link Parent",
          const Color(0xFF50E3C2),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ParentManagementScreen(),
              ),
            );
          },
        ),
        _buildModernActionCard(
          Icons.assignment_turned_in_rounded,
          "Approve",
          const Color(0xFFB86DFF),
          onTap: () => _showFeatureComingSoon("Approval System"),
        ),
      ],
    );
  }

  Widget _buildModernActionCard(
    IconData icon,
    String label,
    Color accent, {
    required VoidCallback onTap,
  }) {
    return Bounceable(
      onTap: onTap,
      child: Container(
        width: 105,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: accent, size: 32),
            const SizedBox(height: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4A4A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeatureComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: const Color(0xFF0D3B66),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Coming Soon",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "The $feature module is currently under maintenance and will be available in the next update.",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B66),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  "Got it",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Shared data builder – used by both the preview grid and full schedule screen
  List<Map<String, dynamic>> _buildClassData() {
    const List<Color> cardColors = [
      Color(0xFF4A90E2),
      Color(0xFFE67E22),
      Color(0xFF27AE60),
      Color(0xFFF95738),
      Color(0xFFB86DFF),
      Color(0xFF50E3C2),
    ];
    const List<IconData> cardIcons = [
      Icons.functions_rounded,
      Icons.menu_book_rounded,
      Icons.biotech_rounded,
      Icons.science_rounded,
      Icons.calculate_rounded,
      Icons.computer_rounded,
    ];
    const List<String> timeSlots = [
      '07:00 - 08:00',
      '08:10 - 09:10',
      '09:20 - 10:20',
      '10:30 - 11:30',
      '13:00 - 14:00',
      '14:10 - 15:10',
      '15:20 - 16:20',
    ];
    final now = TimeOfDay.now();
    return _classrooms.asMap().entries.map((entry) {
      final i = entry.key;
      final c = entry.value;
      final color = cardColors[i % cardColors.length];
      final timeSlot = timeSlots[i % timeSlots.length];
      final startParts = timeSlot.split(' - ')[0].split(':');
      final endParts = timeSlot.split(' - ')[1].split(':');
      final startMins =
          (int.tryParse(startParts[0]) ?? 0) * 60 +
          (int.tryParse(startParts[1]) ?? 0);
      final endMins =
          (int.tryParse(endParts[0]) ?? 0) * 60 +
          (int.tryParse(endParts[1]) ?? 0);
      final nowMins = now.hour * 60 + now.minute;
      return {
        'title': c.name,
        'subtitle': '${c.grade ?? "No grade"} • ${c.studentCount} students',
        'subject': c.name,
        'subjectIcon': cardIcons[i % cardIcons.length],
        'subjectColor': color,
        'time': timeSlot,
        'timeRange': timeSlot,
        'accent': color,
        'isDone': nowMins >= endMins,
        'isCurrent': nowMins >= startMins && nowMins < endMins,
        'topic': c.teacherName != null
            ? 'Teacher: ${c.teacherName}'
            : 'No teacher assigned',
        'students': c.studentCount,
        'room': c.grade ?? 'Room ${i + 1}',
        'description': 'Academic Year: ${c.academicYear ?? "N/A"}',
        'homework': 'Review chapter ${i + 1} exercises',
        'materials': <String>['Textbook', 'Worksheet ${i + 1}', 'Whiteboard'],
        'academicYear': c.academicYear ?? 'N/A',
        'teacherName': c.teacherName ?? 'N/A',
        'classroomId': c.id,
        'isActive': c.isActive,
        'classColor': color,
      };
    }).toList();
  }

  Widget _buildModernTimelineSchedule() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_classrooms.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.class_rounded, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text(
                "No classrooms yet",
                style: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show only the first 2 classes as a preview
    final previewClasses = _buildClassData().take(2).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.95,
      ),
      itemCount: previewClasses.length,
      itemBuilder: (context, index) {
        return _buildClassCard(previewClasses[index]);
      },
    );
  }

  Widget _buildClassCard(Map<String, dynamic> classData) {
    final String title = classData['title'];
    final String subject = classData['subject'] ?? '';
    final IconData subjectIcon =
        classData['subjectIcon'] ?? Icons.class_rounded;
    final Color subjectColor =
        classData['subjectColor'] ?? const Color(0xFF4A90E2);
    final String timeRange = classData['timeRange'] ?? classData['time'] ?? '';
    final bool isDone = classData['isDone'] ?? false;
    final bool isCurrent = classData['isCurrent'] ?? false;

    // Extract class name from title (e.g., "Grade 10 - Biology" → "Grade 10 A")
    final parts = title.split(' - ');
    final className = parts.isNotEmpty ? parts[0] : title;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                TeacherScheduleDetailScreen(classData: classData),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(1.0, 0.0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  );
                },
            transitionDuration: const Duration(milliseconds: 350),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isCurrent
              ? Border.all(
                  color: subjectColor.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: isCurrent
                  ? subjectColor.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: subjectColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(subjectIcon, color: subjectColor, size: 26),
            ),
            const Spacer(),

            // Subject label
            Text(
              subject,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Class name (bold)
            Text(
              className,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Time range row
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14,
                  color: isCurrent ? subjectColor : Colors.grey.shade400,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    timeRange,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? subjectColor : Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDone)
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF27AE60),
                      size: 12,
                    ),
                  ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: subjectColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: subjectColor,
                        letterSpacing: 0.5,
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
}

// Model class for Management Tools
class ManagementTool {
  final String name;
  final IconData icon;
  final Color color;
  final Widget screen;

  ManagementTool({
    required this.name,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

// ----------------------------------------------------------------------
// 3. SETTINGS SCREEN (INDEX 2)
// ----------------------------------------------------------------------
class TeacherSettingsScreen extends StatefulWidget {
  const TeacherSettingsScreen({super.key});

  @override
  State<TeacherSettingsScreen> createState() => _TeacherSettingsScreenState();
}

class _TeacherSettingsScreenState extends State<TeacherSettingsScreen> {
  String _userName = '';
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final api = ApiService();
    final name = await api.getUserName();
    final email = await api.getUserEmail();
    if (mounted) {
      setState(() {
        _userName = name ?? 'Teacher';
        _userEmail = email ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "Settings",
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D3B66),
                ),
              ),
              const SizedBox(height: 30),
              _buildModernProfileHeader(),
              const SizedBox(height: 40),
              _buildModernSettingsGroup([
                _modernSubTile(
                  icon: Icons.person_rounded,
                  title: "Personal Information",
                  color: const Color(0xFF4A90E2),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeacherEditProfileScreen(),
                    ),
                  ),
                ),
                _modernSubTile(
                  icon: Icons.security_rounded,
                  title: "Security & Login",
                  color: const Color(0xFF50E3C2),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LinkedAccountsScreen(),
                    ),
                  ),
                ),
                _modernSubTile(
                  icon: Icons.notifications_active_rounded,
                  title: "Notifications",
                  color: const Color(0xFFF5A623),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TeacherNotificationScreen(),
                    ),
                  ),
                ),
                _modernSubTile(
                  icon: Icons.translate_rounded,
                  title: "Language",
                  color: const Color(0xFFB86DFF),
                  trailing: "Khmer",
                ),
              ]),
              const SizedBox(height: 24),
              _buildModernSettingsGroup([
                _modernSubTile(
                  icon: Icons.support_agent_rounded,
                  title: "Help & Support",
                  color: Colors.grey.shade600,
                ),
                _modernSubTile(
                  icon: Icons.info_rounded,
                  title: "About Application",
                  color: Colors.grey.shade600,
                ),
              ]),
              const SizedBox(height: 40),
              _buildModernLogoutButton(context),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernProfileHeader() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D3B66).withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: const CircleAvatar(
                radius: 54,
                backgroundImage: NetworkImage(
                  'https://img.freepik.com/free-vector/mans-face-flat-style_90220-2877.jpg?semt=ais_hybrid&w=740&q=80',
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Bounceable(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF95738),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          _userName.isNotEmpty ? _userName : "Teacher",
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D3B66),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D3B66).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _userEmail.isNotEmpty ? _userEmail : "Teacher",
            style: GoogleFonts.inter(
              color: const Color(0xFF0D3B66),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget tile = entry.value;
          return Column(
            children: [
              tile,
              if (idx != children.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.grey.shade100,
                  indent: 64,
                  endIndent: 24,
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _modernSubTile({
    required IconData icon,
    required String title,
    required Color color,
    String? trailing,
    VoidCallback? onTap,
  }) {
    return Bounceable(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF333333),
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Text(
                  trailing,
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey.shade400,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Bounceable(
        onTap: () async {
          await ApiService().logout();
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.roleSelection,
              (route) => false,
            );
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFD6D6)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFE94A59),
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                "Secure Log Out",
                style: GoogleFonts.outfit(
                  color: const Color(0xFFE94A59),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
// TEACHER COURSES TAB (Embedded – No AppBar Back Button)
// =============================================================================
class TeacherCoursesTab extends StatefulWidget {
  const TeacherCoursesTab({super.key});

  @override
  State<TeacherCoursesTab> createState() => _TeacherCoursesTabState();
}

class _TeacherCoursesTabState extends State<TeacherCoursesTab> {
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filters = ['All', 'Active', 'Inactive'];

  List<Map<String, dynamic>> _teacherCourses = [];

  @override
  void initState() {
    super.initState();
    _loadClassrooms();
  }

  Future<void> _loadClassrooms() async {
    try {
      final classrooms = await ApiService().getClassrooms();
      final List<Color> colors = [
        const Color(0xFF4A90E2),
        const Color(0xFFFFB75E),
        const Color(0xFF50E3C2),
        const Color(0xFFF95738),
        const Color(0xFFB86DFF),
        const Color(0xFF0D3B66),
      ];
      final List<IconData> icons = [
        Icons.calculate_rounded,
        Icons.bolt_rounded,
        Icons.science_rounded,
        Icons.biotech_rounded,
        Icons.bar_chart_rounded,
        Icons.computer_rounded,
      ];
      if (mounted) {
        setState(() {
          _teacherCourses = classrooms.asMap().entries.map((entry) {
            final i = entry.key;
            final c = entry.value;
            return {
              'title': c.name,
              'grade': c.grade ?? 'No grade',
              'students': c.studentCount,
              'lessons': 0,
              'progress': 0.0,
              'status': c.isActive ? 'Active' : 'Inactive',
              'color': colors[i % colors.length],
              'icon': icons[i % icons.length],
              'rating': 0.0,
              'nextClass': c.teacherName ?? 'No teacher',
            };
          }).toList();
        });
      }
    } catch (_) {}
  }

  List<Map<String, dynamic>> get _filteredCourses {
    return _teacherCourses.where((c) {
      final matchFilter =
          _selectedFilter == 'All' || c['status'] == _selectedFilter;
      final matchSearch = c['title'].toString().toLowerCase().contains(
        _searchQuery,
      );
      return matchFilter && matchSearch;
    }).toList();
  }

  int get _totalStudents =>
      _teacherCourses.fold(0, (sum, c) => sum + (c['students'] as int));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF95738), Color(0xFFFF8A65)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF95738).withValues(alpha: 0.3),
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
                        '${_teacherCourses.length} courses · $_totalStudents students',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Bounceable(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeacherCourseScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D3B66),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0D3B66,
                            ).withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Stats Overview Card ──
          SliverToBoxAdapter(
            child: Padding(
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
                    _buildStatItem(
                      '${_teacherCourses.where((c) => c['status'] == 'Active').length}',
                      'Active',
                      Icons.play_circle_outline_rounded,
                      const Color(0xFF50E3C2),
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      '$_totalStudents',
                      'Students',
                      Icons.people_outline_rounded,
                      const Color(0xFF4A90E2),
                    ),
                    _buildStatDivider(),
                    _buildStatItem(
                      '${_teacherCourses.fold(0, (int sum, c) => sum + (c['lessons'] as int))}',
                      'Lessons',
                      Icons.menu_book_rounded,
                      const Color(0xFFFFB75E),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Search Bar ──
          SliverToBoxAdapter(
            child: Padding(
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
                    hintText: 'Search your courses...',
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
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Filter Chips ──
          SliverToBoxAdapter(
            child: SizedBox(
              height: 42,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  final isSelected = filter == _selectedFilter;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Bounceable(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
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
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── Course List ──
          if (_filteredCourses.isEmpty)
            SliverFillRemaining(
              child: Center(
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
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 50),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final course = _filteredCourses[index];
                  return _buildTeacherCourseCard(course);
                }, childCount: _filteredCourses.length),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _buildTeacherCourseCard(Map<String, dynamic> course) {
    final Color accent = course['color'] as Color;
    final String status = course['status'] as String;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Active':
        statusColor = const Color(0xFF50E3C2);
        statusIcon = Icons.play_circle_rounded;
        break;
      case 'Completed':
        statusColor = const Color(0xFF4A90E2);
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = Colors.grey.shade400;
        statusIcon = Icons.edit_note_rounded;
    }

    return Bounceable(
      onTap: () => _showCourseDetail(context, course),
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
          child: Column(
            children: [
              Row(
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
                              Icons.class_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              course['grade'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.people_outline_rounded,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${course['students']}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Progress + info row
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
                              'Progress',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${((course['progress'] as double) * 100).toInt()}%',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: course['progress'] as double,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF3F6F8),
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Color(0xFF0D3B66),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course['nextClass'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0D3B66),
                          ),
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
    );
  }

  void _showCourseDetail(BuildContext context, Map<String, dynamic> course) {
    final Color accent = course['color'] as Color;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
            const SizedBox(height: 20),
            // ── Course header ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    course['icon'] as IconData,
                    size: 42,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course['title'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${course['grade']} · ${course['students']} students',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Quick Actions ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildQuickAction(
                    'Lessons',
                    Icons.menu_book_rounded,
                    const Color(0xFF4A90E2),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    'Students',
                    Icons.people_rounded,
                    const Color(0xFF50E3C2),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickAction(
                    'Grades',
                    Icons.assessment_rounded,
                    const Color(0xFFFFB75E),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Lesson list ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Lessons',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: (course['lessons'] as int).clamp(0, 5),
                itemBuilder: (context, i) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6F8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              '${i + 1}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lesson ${i + 1}: Chapter ${i + 1}',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: const Color(0xFF0D3B66),
                                ),
                              ),
                              Text(
                                i < 3 ? 'Completed' : 'Upcoming',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: i < 3
                                      ? const Color(0xFF50E3C2)
                                      : Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          i < 3
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: i < 3
                              ? const Color(0xFF50E3C2)
                              : Colors.grey.shade300,
                          size: 22,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String label, IconData icon, Color color) {
    return Expanded(
      child: Bounceable(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
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
// TEACHER MESSAGES TAB
// =============================================================================
class TeacherMessagesTab extends StatefulWidget {
  const TeacherMessagesTab({super.key});

  @override
  State<TeacherMessagesTab> createState() => _TeacherMessagesTabState();
}

class _TeacherMessagesTabState extends State<TeacherMessagesTab>
    with SingleTickerProviderStateMixin {
  late TabController _msgTabController;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _conversations = [
    {
      'name': 'John Doe (Parent)',
      'subject': 'Grade 12-A',
      'message': 'Thank you for the update on my son\'s progress.',
      'time': '3m ago',
      'unread': 2,
      'online': true,
      'avatar': Icons.person,
      'color': const Color(0xFF4A90E2),
      'type': 'parent',
    },
    {
      'name': 'Sarah Kim (Student)',
      'subject': 'Mathematics',
      'message': 'Can I schedule office hours this Friday?',
      'time': '10m ago',
      'unread': 1,
      'online': true,
      'avatar': Icons.person,
      'color': const Color(0xFF50E3C2),
      'type': 'student',
    },
    {
      'name': 'Grade 12-A Group',
      'subject': '32 members',
      'message': 'You: Homework is due on Monday.',
      'time': '30m ago',
      'unread': 0,
      'online': false,
      'avatar': Icons.groups_rounded,
      'color': const Color(0xFFB86DFF),
      'type': 'group',
    },
    {
      'name': 'Ms. Taylor',
      'subject': 'Co-teacher · English',
      'message': 'Should we combine the next exam?',
      'time': '1h ago',
      'unread': 3,
      'online': true,
      'avatar': Icons.person,
      'color': const Color(0xFFF95738),
      'type': 'colleague',
    },
    {
      'name': 'Alex Rivera (Student)',
      'subject': 'Physics',
      'message': 'Submitted the lab report. Please review.',
      'time': '2h ago',
      'unread': 0,
      'online': false,
      'avatar': Icons.person,
      'color': const Color(0xFFFFB75E),
      'type': 'student',
    },
    {
      'name': 'Faculty Room',
      'subject': '12 members',
      'message': 'Principal: Staff meeting at 3 PM today.',
      'time': '3h ago',
      'unread': 4,
      'online': false,
      'avatar': Icons.groups_rounded,
      'color': const Color(0xFF0D3B66),
      'type': 'group',
    },
    {
      'name': 'Admin Office',
      'subject': 'School Administration',
      'message': 'Your leave request has been approved.',
      'time': 'Yesterday',
      'unread': 0,
      'online': false,
      'avatar': Icons.admin_panel_settings_rounded,
      'color': const Color(0xFF4A4A4A),
      'type': 'admin',
    },
    {
      'name': 'Emily Park (Parent)',
      'subject': 'Grade 11-B',
      'message': 'Regarding the upcoming parent-teacher meeting.',
      'time': 'Yesterday',
      'unread': 1,
      'online': false,
      'avatar': Icons.person,
      'color': const Color(0xFF6C5CE7),
      'type': 'parent',
    },
  ];

  List<Map<String, dynamic>> _filterByTab(int tabIndex) {
    List<Map<String, dynamic>> list;
    if (tabIndex == 0) {
      list = _conversations;
    } else if (tabIndex == 1) {
      list = _conversations
          .where(
            (c) =>
                c['type'] == 'student' ||
                c['type'] == 'parent' ||
                c['type'] == 'colleague' ||
                c['type'] == 'admin',
          )
          .toList();
    } else {
      list = _conversations.where((c) => c['type'] == 'group').toList();
    }
    if (_searchQuery.isEmpty) return list;
    return list
        .where(
          (c) =>
              c['name'].toString().toLowerCase().contains(_searchQuery) ||
              c['message'].toString().toLowerCase().contains(_searchQuery),
        )
        .toList();
  }

  int get _totalUnread =>
      _conversations.fold(0, (sum, c) => sum + (c['unread'] as int));

  @override
  void initState() {
    super.initState();
    _msgTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _msgTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double listHeight = MediaQuery.of(context).size.height * 0.55;
    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFFA29BFE)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.forum_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                    Text(
                      '$_totalUnread unread messages',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Bounceable(
                  onTap: () => _showComposeSheet(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D3B66),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0D3B66,
                          ).withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Tab Bar ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TabBar(
                controller: _msgTabController,
                onTap: (_) => setState(() {}),
                indicator: BoxDecoration(
                  color: const Color(0xFF0D3B66),
                  borderRadius: BorderRadius.circular(14),
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
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('All'),
                        if (_totalUnread > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _msgTabController.index == 0
                                  ? const Color(0xFFF95738)
                                  : const Color(
                                      0xFFF95738,
                                    ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_totalUnread',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _msgTabController.index == 0
                                    ? Colors.white
                                    : const Color(0xFFF95738),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'People'),
                  const Tab(text: 'Groups'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Search Bar ──
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
                  hintText: 'Search messages...',
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

          const SizedBox(height: 8),

          // ── Online Now ──
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _conversations
                  .where((c) => c['online'] == true)
                  .length,
              itemBuilder: (context, index) {
                final onlineUsers = _conversations
                    .where((c) => c['online'] == true)
                    .toList();
                final user = onlineUsers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  user['color'] as Color,
                                  (user['color'] as Color).withValues(
                                    alpha: 0.6,
                                  ),
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (user['color'] as Color).withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(
                              user['avatar'] as IconData,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF50E3C2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFF3F6F8),
                                  width: 2.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 60,
                        child: Text(
                          (user['name'] as String).split(' ').first,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0D3B66),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ── Conversations List ──
          SizedBox(
            height: listHeight,
            child: TabBarView(
              controller: _msgTabController,
              children: [
                _buildConversationList(_filterByTab(0)),
                _buildConversationList(_filterByTab(1)),
                _buildConversationList(_filterByTab(2)),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildConversationList(List<Map<String, dynamic>> conversations) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No conversations yet',
              style: GoogleFonts.outfit(
                fontSize: 18,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conv = conversations[index];
        return _buildConversationTile(conv);
      },
    );
  }

  Widget _buildConversationTile(Map<String, dynamic> conv) {
    final int unread = conv['unread'] as int;
    final bool isOnline = conv['online'] as bool;
    final Color accent = conv['color'] as Color;
    final bool isGroup = conv['type'] == 'group';

    return Bounceable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeacherChatDetailScreen(conversation: conv),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: unread > 0
              ? const Color(0xFF0D3B66).withValues(alpha: 0.03)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: unread > 0
              ? Border.all(
                  color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
                  width: 1.5,
                )
              : null,
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
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withValues(alpha: 0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    isGroup ? Icons.groups_rounded : Icons.person_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF50E3C2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv['name'] as String,
                          style: GoogleFonts.outfit(
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 15,
                            color: const Color(0xFF0D3B66),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        conv['time'] as String,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: unread > 0
                              ? const Color(0xFF4A90E2)
                              : Colors.grey.shade400,
                          fontWeight: unread > 0
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    conv['subject'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv['message'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: unread > 0
                                ? const Color(0xFF0D3B66)
                                : Colors.grey.shade500,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF95738),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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

  void _showComposeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
            const SizedBox(height: 20),
            Text(
              'New Message',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D3B66),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  style: GoogleFonts.inter(color: const Color(0xFF0D3B66)),
                  decoration: InputDecoration(
                    hintText: 'Search student, parent, or group...',
                    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400),
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _conversations.length,
                itemBuilder: (context, i) {
                  final c = _conversations[i];
                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (c['color'] as Color).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        c['avatar'] as IconData,
                        color: c['color'] as Color,
                      ),
                    ),
                    title: Text(
                      c['name'] as String,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0D3B66),
                      ),
                    ),
                    subtitle: Text(
                      c['subject'] as String,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TeacherChatDetailScreen(conversation: c),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TEACHER CHAT DETAIL SCREEN
// =============================================================================
class TeacherChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> conversation;
  const TeacherChatDetailScreen({super.key, required this.conversation});

  @override
  State<TeacherChatDetailScreen> createState() =>
      _TeacherChatDetailScreenState();
}

class _TeacherChatDetailScreenState extends State<TeacherChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Good morning! I wanted to discuss something with you.',
      'isMe': false,
      'time': '9:00 AM',
    },
    {
      'text': 'Of course! What would you like to talk about?',
      'isMe': true,
      'time': '9:02 AM',
    },
    {
      'text': 'It\'s about the upcoming test schedule and materials.',
      'isMe': false,
      'time': '9:03 AM',
    },
    {
      'text': 'I\'ll share the review guide with the class today.',
      'isMe': true,
      'time': '9:05 AM',
    },
    {
      'text': 'That would be very helpful. Thank you so much!',
      'isMe': false,
      'time': '9:06 AM',
    },
    {
      'text':
          'No problem! I\'ll also post extra practice problems on the portal.',
      'isMe': true,
      'time': '9:08 AM',
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.conversation['color'] as Color;
    final bool isGroup = widget.conversation['type'] == 'group';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: Color(0xFF0D3B66),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accent, accent.withValues(alpha: 0.6)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      isGroup ? Icons.groups_rounded : Icons.person_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation['name'] as String,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: const Color(0xFF0D3B66),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.conversation['online'] == true
                              ? 'Online'
                              : widget.conversation['subject'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: widget.conversation['online'] == true
                                ? const Color(0xFF50E3C2)
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.videocam_rounded,
                      color: Color(0xFF0D3B66),
                    ),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: Color(0xFF0D3B66),
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final bool isMe = msg['isMe'] as bool;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: isMe
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? const Color(0xFF0D3B66)
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(20),
                              topRight: const Radius.circular(20),
                              bottomLeft: Radius.circular(isMe ? 20 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                msg['text'] as String,
                                style: GoogleFonts.inter(
                                  color: isMe
                                      ? Colors.white
                                      : const Color(0xFF0D3B66),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['time'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isMe) const SizedBox(width: 40),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.attach_file_rounded,
                    color: Color(0xFF0D3B66),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF0D3B66),
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: GoogleFonts.inter(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Bounceable(
                  onTap: () {
                    final text = _messageController.text.trim();
                    if (text.isNotEmpty) {
                      setState(() {
                        _messages.add({
                          'text': text,
                          'isMe': true,
                          'time': 'Now',
                        });
                        _messageController.clear();
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D3B66), Color(0xFF1E5B94)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D3B66).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TEACHER EVENT DETAIL SCREEN
// =============================================================================
class TeacherEventDetailScreen extends StatelessWidget {
  final Map<String, dynamic> event;
  const TeacherEventDetailScreen({super.key, required this.event});

  Color _color(String category) {
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

  Widget _chip(IconData icon, String label, Color color) {
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
        mainAxisSize: MainAxisSize.min,
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

  @override
  Widget build(BuildContext context) {
    final Color accent = _color(event["category"]);
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
                  height: MediaQuery.of(context).size.height * 0.32,
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
                      color: accent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.5),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _chip(
                        Icons.calendar_month_rounded,
                        event["date"],
                        const Color(0xFFF95738),
                      ),
                      _chip(
                        Icons.access_time_rounded,
                        event["time"],
                        const Color(0xFF4A90E2),
                      ),
                      _chip(
                        Icons.location_on_rounded,
                        event["location"],
                        const Color(0xFF50E3C2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
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
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 30),
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
                        "Got it!",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
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
}

// =============================================================================
// TEACHER SCHEDULE DETAIL SCREEN
// =============================================================================
class TeacherScheduleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> classData;
  const TeacherScheduleDetailScreen({super.key, required this.classData});

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D3B66),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D3B66),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color accent =
        (classData['classColor'] as Color?) ?? const Color(0xFF4A90E2);
    final String title = classData['title'] ?? '';
    final String timeRange = classData['timeRange'] ?? classData['time'] ?? '';
    final String room = classData['room'] ?? '';
    final int students = classData['students'] ?? 0;
    final String teacherName = classData['teacherName'] ?? 'N/A';
    final String academicYear =
        classData['academicYear'] ?? classData['description'] ?? 'N/A';
    final String homework = classData['homework'] ?? '';
    final List<String> materials = List<String>.from(
      classData['materials'] ?? [],
    );
    final bool isActive = classData['isActive'] ?? true;
    final bool isCurrent = classData['isCurrent'] ?? false;
    final bool isDone = classData['isDone'] ?? false;
    final IconData subjectIcon =
        classData['subjectIcon'] ?? Icons.class_rounded;

    final String statusLabel = isDone
        ? 'Completed'
        : (isCurrent ? 'In Progress' : 'Upcoming');
    final Color statusColor = isDone
        ? const Color(0xFF27AE60)
        : (isCurrent ? const Color(0xFF4A90E2) : const Color(0xFFF5A623));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.26,
            pinned: true,
            backgroundColor: accent,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 30,
                      left: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 30,
                      left: 24,
                      right: 24,
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              subjectIcon,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
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

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick-info grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.4,
                    children: [
                      _infoCard(
                        icon: Icons.access_time_rounded,
                        label: "Class Time",
                        value: timeRange.isEmpty ? 'Not set' : timeRange,
                        color: const Color(0xFF4A90E2),
                      ),
                      _infoCard(
                        icon: Icons.people_rounded,
                        label: "Students",
                        value: '$students enrolled',
                        color: const Color(0xFF27AE60),
                      ),
                      _infoCard(
                        icon: Icons.meeting_room_rounded,
                        label: "Grade / Room",
                        value: room.isEmpty ? 'N/A' : room,
                        color: const Color(0xFFFFB75E),
                      ),
                      _infoCard(
                        icon: Icons.calendar_today_rounded,
                        label: "Academic Year",
                        value: academicYear,
                        color: const Color(0xFFB86DFF),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Teacher card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: accent,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Teacher",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                teacherName,
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D3B66),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF27AE60).withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isActive ? "Active" : "Inactive",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? const Color(0xFF27AE60)
                                  : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Capacity bar
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeader(
                          "Class Capacity",
                          Icons.bar_chart_rounded,
                          accent,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Enrolled Students",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              "$students / 40",
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0D3B66),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: students > 0
                                ? (students / 40).clamp(0.0, 1.0)
                                : 0,
                            backgroundColor: Colors.grey.shade100,
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "${((students / 40) * 100).clamp(0, 100).toInt()}% capacity filled",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Homework section
                  if (homework.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            "Homework",
                            Icons.assignment_rounded,
                            const Color(0xFFF95738),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF95738,
                              ).withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFF95738,
                                ).withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              homework,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                height: 1.5,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Materials section
                  if (materials.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                            "Materials",
                            Icons.library_books_rounded,
                            const Color(0xFF50E3C2),
                          ),
                          const SizedBox(height: 14),
                          ...materials.map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF50E3C2),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    m,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Close",
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TEACHER EVENTS LIST SCREEN
// =============================================================================
class TeacherEventsListScreen extends StatelessWidget {
  const TeacherEventsListScreen({super.key});

  static final List<Map<String, dynamic>> _events = [
    {
      "title": "Annual Sports Day",
      "date": "14 Oct 2026",
      "time": "10:00 AM - 4:00 PM",
      "location": "School Grounds",
      "img": AppImages.event1,
      "category": "Sports",
      "attendees": 245,
      "description":
          "Join us for a day of athletic excellence and teamwork! Featuring track & field events, team sports, and fun activities for everyone.",
    },
    {
      "title": "Tech Exhibition",
      "date": "20 Oct 2026",
      "time": "9:00 AM - 3:00 PM",
      "location": "Innovation Lab",
      "img": AppImages.event2,
      "category": "Technology",
      "attendees": 189,
      "description":
          "Showcasing the latest student innovations in robotics, software development, and engineering projects.",
    },
    {
      "title": "Science Fair 2026",
      "date": "12 Nov 2026",
      "time": "11:00 AM - 5:00 PM",
      "location": "Science Hall",
      "img": AppImages.event3,
      "category": "Science",
      "attendees": 312,
      "description":
          "Explore groundbreaking experiments and discoveries presented by our talented young scientists.",
    },
    {
      "title": "Music Festival",
      "date": "05 Dec 2026",
      "time": "2:00 PM - 8:00 PM",
      "location": "Auditorium",
      "img": AppImages.event2,
      "category": "Arts",
      "attendees": 450,
      "description":
          "A celebration of student musical talent featuring bands, choirs, and solo performances.",
    },
    {
      "title": "Charity Auction",
      "date": "15 Dec 2026",
      "time": "6:00 PM - 9:00 PM",
      "location": "Main Hall",
      "img": AppImages.event2,
      "category": "Fundraising",
      "attendees": 150,
      "description":
          "Raising funds for local community projects. Come bid on amazing items donated by local businesses.",
    },
  ];

  Color _categoryColor(String category) {
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
        itemCount: _events.length,
        itemBuilder: (context, index) => Bounceable(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherEventDetailScreen(event: _events[index]),
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
                        _events[index]["img"],
                        height: MediaQuery.of(context).size.height * 0.2,
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
                          color: _categoryColor(_events[index]["category"]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _events[index]["category"],
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
                              _events[index]["title"],
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
                                  _events[index]["date"],
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
                                  (_events[index]["time"] as String).split(
                                    " - ",
                                  )[0],
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF4A90E2),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: Color(0xFF50E3C2),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _events[index]["location"],
                                  style: GoogleFonts.inter(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.people_rounded,
                                  size: 14,
                                  color: Color(0xFFB86DFF),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "${_events[index]["attendees"]} people",
                                  style: GoogleFonts.inter(
                                    color: Colors.grey.shade600,
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
}

// =============================================================================
// TEACHER ALL CLASSES SCREEN (Full Schedule)
// =============================================================================
class TeacherAllClassesScreen extends StatelessWidget {
  final List<Map<String, dynamic>> classes;
  const TeacherAllClassesScreen({super.key, required this.classes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        title: Text(
          "Today's Schedule",
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
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D3B66).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${classes.length} Classes',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0D3B66),
                ),
              ),
            ),
          ),
        ],
      ),
      body: classes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.class_rounded,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No classes scheduled today',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              itemCount: classes.length,
              itemBuilder: (context, index) {
                final c = classes[index];
                final Color color =
                    (c['classColor'] as Color?) ?? const Color(0xFF4A90E2);
                final bool isCurrent = c['isCurrent'] ?? false;
                final bool isDone = c['isDone'] ?? false;
                final String timeRange = c['timeRange'] ?? '';
                final String statusLabel = isDone
                    ? 'Done'
                    : (isCurrent ? 'In Progress' : 'Upcoming');
                final Color statusColor = isDone
                    ? const Color(0xFF27AE60)
                    : (isCurrent
                          ? const Color(0xFF4A90E2)
                          : const Color(0xFFF5A623));

                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (_, a, _) =>
                          TeacherScheduleDetailScreen(classData: c),
                      transitionsBuilder: (_, animation, _, child) =>
                          SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                            child: child,
                          ),
                      transitionDuration: const Duration(milliseconds: 300),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: isCurrent
                          ? Border.all(
                              color: color.withValues(alpha: 0.4),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: isCurrent
                              ? color.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Time column
                        SizedBox(
                          width: 72,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timeRange.split(' - ').first,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isCurrent
                                      ? color
                                      : const Color(0xFF0D3B66),
                                ),
                              ),
                              Text(
                                timeRange.contains(' - ')
                                    ? timeRange.split(' - ').last
                                    : '',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Divider line
                        Container(
                          width: 2,
                          height: 48,
                          margin: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isCurrent ? color : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),

                        // Icon
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            c['subjectIcon'] as IconData? ??
                                Icons.class_rounded,
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c['title'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF0D3B66),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${c['students']} students  •  ${c['room']}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
