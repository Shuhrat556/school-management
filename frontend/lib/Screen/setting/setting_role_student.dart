import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tamdansers/Screen/Edit-Profile/student_edit_profile.dart';
import 'package:tamdansers/Screen/Role_STUDENT/notification_student_role.dart';
import 'package:tamdansers/Screen/setting/linked_accounts_screen.dart';
import 'package:tamdansers/routes/app_routes.dart';
import 'package:tamdansers/services/api_service.dart';

class StudentSettingsScreen extends StatefulWidget {
  const StudentSettingsScreen({super.key});

  @override
  State<StudentSettingsScreen> createState() => _StudentSettingsScreenState();
}

class _StudentSettingsScreenState extends State<StudentSettingsScreen> {
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
        _userName = name ?? 'Student';
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
                      builder: (_) => const StudentEditProfileScreen(),
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
                      builder: (_) => const NotificationScreen(),
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
          _userName.isNotEmpty ? _userName : "Student",
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
            _userEmail.isNotEmpty ? _userEmail : "student@school.edu",
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
          final idx = entry.key;
          final tile = entry.value;
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
