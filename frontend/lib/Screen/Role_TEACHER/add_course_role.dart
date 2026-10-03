import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

// Adds a subject to the school catalogue (POST /api/school/Subjects). It used to build a
// "course" with a price and start date that only lived on the screen (BUGS B37).
// Pops with the new subject's name when it was created.
class AddCourse extends StatefulWidget {
  // The calls can be replaced in tests; by default they go to the API.
  // create returns null on success, otherwise the reason.
  const AddCourse({super.key, this.loadDepartments, this.create});

  final Future<List<DepartmentDto>> Function()? loadDepartments;
  final Future<String?> Function(String name, String departmentId, String? description)? create;

  @override
  State<AddCourse> createState() => _AddCourseState();
}

class _AddCourseState extends State<AddCourse> {
  static const _ink = Color(0xFF0F172A);
  static const _accent = Color(0xFF6366F1);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<DepartmentDto> _departments = [];
  String? _departmentId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    final departments = await (widget.loadDepartments ?? ApiService().getDepartments)();
    if (!mounted) return;
    setState(() {
      _departments = departments;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final departmentId = _departmentId;
    if (departmentId == null) {
      _show('Choose the department this subject belongs to.', Colors.red);
      return;
    }

    setState(() => _saving = true);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final error = await (widget.create ??
        (n, d, desc) => ApiService().createSubject(subjectName: n, departmentId: d, description: desc))(
      name,
      departmentId,
      description.isEmpty ? null : description,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      _show(error, Colors.red);
      return;
    }
    Navigator.pop(context, name);
  }

  void _show(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.plusJakartaSans()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  InputDecoration _decoration(String label, String hint) => InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        labelStyle: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _ink,
        title: Text(
          'New Subject',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: _ink),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                children: [
                  TextFormField(
                    key: const ValueKey('subject-name'),
                    controller: _nameController,
                    decoration: _decoration('Subject name', 'e.g. Algebra II'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter the subject name' : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Department',
                    style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  const SizedBox(height: 12),
                  if (_departments.isEmpty)
                    Text(
                      'No departments yet — an administrator adds them first.',
                      style: GoogleFonts.plusJakartaSans(color: Colors.grey.shade600),
                    )
                  else
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final d in _departments)
                          ChoiceChip(
                            label: Text(d.name),
                            selected: _departmentId == d.id,
                            selectedColor: _accent.withValues(alpha: 0.15),
                            onSelected: (_) => setState(() => _departmentId = d.id),
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: _decoration('Description (optional)', 'What does this subject cover?'),
                  ),
                  const SizedBox(height: 32),
                  Bounceable(
                    key: const ValueKey('create-subject'),
                    onTap: _saving ? null : _save,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _saving ? Colors.grey.shade300 : _accent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Create Subject',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
