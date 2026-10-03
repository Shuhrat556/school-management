import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

// A directory of students' parents, so a teacher can reach the family. Linking parent
// accounts is an administrator task in the web portal (school-service D10); this screen
// used to show a "link parent" form whose button did nothing.
class ParentManagementScreen extends StatefulWidget {
  // The calls can be replaced in tests; by default they go to the API.
  const ParentManagementScreen({super.key, this.loadStudents, this.loadParents});

  final Future<List<StudentDto>> Function()? loadStudents;
  final Future<List<StudentParentDto>> Function(String studentId)? loadParents;

  @override
  State<ParentManagementScreen> createState() => _ParentManagementScreenState();
}

class _ParentManagementScreenState extends State<ParentManagementScreen> {
  static const _ink = Color(0xFF0D3B66);

  List<StudentDto> _students = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final students = await (widget.loadStudents ?? () => ApiService().getStudents(page: 1, pageSize: 500))();
    if (!mounted) return;
    setState(() {
      _students = students..sort((a, b) => a.fullName.compareTo(b.fullName));
      _loading = false;
    });
  }

  Future<void> _showParents(StudentDto student) async {
    final parentsFuture = (widget.loadParents ?? ApiService().getStudentParents)(student.id);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: FutureBuilder<List<StudentParentDto>>(
            future: parentsFuture,
            builder: (context, snapshot) {
              final parents = snapshot.data;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${student.fullName}'s parents",
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: _ink),
                  ),
                  const SizedBox(height: 16),
                  if (parents == null)
                    const Center(child: CircularProgressIndicator())
                  else if (parents.isEmpty)
                    Text(
                      'No parent account is linked yet. The school administrator links parents in the web portal.',
                      style: GoogleFonts.inter(color: Colors.grey.shade600, height: 1.4),
                    )
                  else
                    for (final p in parents)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: _ink.withValues(alpha: 0.1),
                          child: Text(p.fullName.isEmpty ? '?' : p.fullName[0].toUpperCase(),
                              style: const TextStyle(color: _ink, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(p.fullName, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          [if (p.relationship != null) p.relationship!, if (p.email != null) p.email!].join(' · '),
                          style: GoogleFonts.inter(color: Colors.grey.shade600),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final visible = _students.where((s) => s.fullName.toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _ink, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          "Parents",
          style: GoogleFonts.outfit(color: _ink, fontWeight: FontWeight.bold, fontSize: 22),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search a student',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? Center(child: Text('No students found.', style: GoogleFonts.inter(color: Colors.grey.shade500)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = visible[i];
                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text(s.fullName, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: _ink)),
                              subtitle: s.email == null ? null : Text(s.email!, style: GoogleFonts.inter(color: Colors.grey.shade600)),
                              trailing: const Icon(Icons.family_restroom_rounded, color: _ink),
                              onTap: () => _showParents(s),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
