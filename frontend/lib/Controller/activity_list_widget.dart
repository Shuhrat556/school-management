import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:intl/intl.dart';
import 'package:tamdansers/services/api_models.dart';

const _palette = [Colors.indigo, Colors.teal, Colors.orange, Colors.red, Colors.purple];

// The student's grades, newest first, as activity entries (they used to be sample lab sessions).
List<Map<String, dynamic>> activitiesFromGrades(List<GradeDto> grades) => [
      for (final g in grades)
        {
          "icon": Icons.grade_rounded,
          "title": g.subjectName,
          "status": "Graded",
          "color": _palette[g.subjectName.hashCode.abs() % _palette.length],
          "grade": g.score >= 90 ? "A" : g.score >= 80 ? "B" : g.score >= 70 ? "C" : g.score >= 60 ? "D" : "F",
          "time": g.semester,
          "date": DateTime.tryParse(g.createdAt) == null ? "" : DateFormat('dd MMM yyyy').format(DateTime.parse(g.createdAt).toLocal()),
          "category": g.subjectName,
          "desc": "Score ${g.score.toStringAsFixed(1)} out of 100 for ${g.semester}.",
        },
    ];

class ActivityList extends StatelessWidget {
  final bool isDetailed;
  final int? limit;
  final List<Map<String, dynamic>> activities;

  const ActivityList({super.key, this.isDetailed = false, this.limit, this.activities = const []});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return Text("No recent activity yet.", style: GoogleFonts.inter(color: Colors.grey.shade500));
    }

    List<Map<String, dynamic>> displayList = activities;
    if (limit != null && !isDetailed) {
      displayList = activities.take(limit!).toList();
    }

    if (isDetailed) {
      return Column(
        children: displayList
            .map((activity) => _buildDetailedActivityCard(context, activity))
            .toList(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayList.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 24, thickness: 1, color: Color(0xFFF3F6F8)),
        itemBuilder: (context, index) {
          final activity = displayList[index];
          return _buildActivityTile(context, activity);
        },
      ),
    );
  }

  Widget _buildActivityTile(
    BuildContext context,
    Map<String, dynamic> activity,
  ) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityDetailScreen(activity: activity),
        ),
      ),
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: activity["color"].withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(activity["icon"], color: activity["color"], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity["title"],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  Text(
                    activity["status"],
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (activity["grade"] != null)
              Text(
                activity["grade"],
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF007A7A),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedActivityCard(
    BuildContext context,
    Map<String, dynamic> activity,
  ) {
    final Color themeColor = activity["color"];

    return Bounceable(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityDetailScreen(activity: activity),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: themeColor.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Vertical Accent Line
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 6, color: themeColor),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            activity["icon"],
                            color: themeColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity["title"],
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: const Color(0xFF0D3B66),
                                ),
                              ),
                              Text(
                                activity["category"],
                                style: GoogleFonts.inter(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (activity["grade"] != null)
                          _buildGradeBadge(activity["grade"], themeColor),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildInfoBadge(
                          Icons.access_time_rounded,
                          activity["time"],
                        ),
                        _buildInfoBadge(
                          Icons.calendar_month_rounded,
                          activity["date"],
                        ),
                        _buildInfoBadge(
                          Icons.check_circle_outline_rounded,
                          activity["status"],
                          isActive: true,
                          activeColor: themeColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      activity["desc"],
                      style: GoogleFonts.inter(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeBadge(String grade, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1.5),
      ),
      child: Text(
        grade,
        style: GoogleFonts.outfit(
          fontWeight: FontWeight.w900,
          fontSize: 18,
          color: color,
        ),
      ),
    );
  }

  Widget _buildInfoBadge(
    IconData icon,
    String label, {
    bool isActive = false,
    Color? activeColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor!.withValues(alpha: 0.08)
            : const Color(0xFFF3F6F8),
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: activeColor!.withValues(alpha: 0.1), width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isActive ? activeColor : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: isActive ? activeColor : Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class ActivityDetailScreen extends StatelessWidget {
  final Map<String, dynamic> activity;

  const ActivityDetailScreen({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final Color themeColor = activity["color"];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Activity Details",
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D3B66),
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF0D3B66),
            size: 20,
          ),
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
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          activity["icon"],
                          color: themeColor,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity["title"],
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: const Color(0xFF0D3B66),
                              ),
                            ),
                            Text(
                              activity["category"],
                              style: GoogleFonts.inter(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildDetailRow(
                    Icons.access_time_rounded,
                    "Time",
                    activity["time"],
                  ),
                  const Divider(
                    height: 32,
                    thickness: 1,
                    color: Color(0xFFF3F6F8),
                  ),
                  _buildDetailRow(
                    Icons.calendar_month_rounded,
                    "Date",
                    activity["date"],
                  ),
                  const Divider(
                    height: 32,
                    thickness: 1,
                    color: Color(0xFFF3F6F8),
                  ),
                  _buildDetailRow(
                    Icons.check_circle_outline_rounded,
                    "Status",
                    activity["status"],
                  ),
                  if (activity["grade"] != null) ...[
                    const Divider(
                      height: 32,
                      thickness: 1,
                      color: Color(0xFFF3F6F8),
                    ),
                    _buildDetailRow(
                      Icons.grade_rounded,
                      "Grade Received",
                      activity["grade"],
                      isGrade: true,
                    ),
                  ],
                  const SizedBox(height: 40),
                  Text(
                    "Description",
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0D3B66),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    activity["desc"],
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isGrade = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: isGrade ? 20 : 15,
            color: isGrade ? const Color(0xFF007A7A) : const Color(0xFF0D3B66),
          ),
        ),
      ],
    );
  }
}
