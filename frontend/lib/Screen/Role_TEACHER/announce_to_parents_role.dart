import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

// Posts a class announcement: it is published at once, so the class's students
// and their parents get a notification (school-service D11).
class AnnounceToParentsScreen extends StatefulWidget {
  // The calls can be replaced in tests; by default they go to the API.
  // post returns null on success, otherwise the reason.
  const AnnounceToParentsScreen({
    super.key,
    this.loadClasses,
    this.loadLessons,
    this.post,
  });

  final Future<List<ClassroomDto>> Function()? loadClasses;
  final Future<List<String>> Function(String classroomId)? loadLessons;
  final Future<String?> Function(String classroomId, String title, String body)? post;

  @override
  State<AnnounceToParentsScreen> createState() =>
      _AnnounceToParentsScreenState();
}

class _AnnounceToParentsScreenState extends State<AnnounceToParentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  String? _selectedClass; // classroom id
  String? _selectedLesson;
  final List<File> _attachedFiles = [];
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  List<ClassroomDto> _classes = [];
  List<String> _lessons = []; // the selected class's materials

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  // The teacher's own classes; every class when none is assigned to them yet.
  Future<void> _loadClasses() async {
    final classes = await (widget.loadClasses ?? () async {
      final api = ApiService();
      final all = await api.getClassrooms();
      final me = await api.getEntityId();
      final mine = all.where((c) => c.teacherId != null && c.teacherId == me).toList();
      return mine.isNotEmpty ? mine : all;
    })();
    if (mounted) setState(() => _classes = classes);
  }

  Future<void> _selectClass(String? classroomId) async {
    setState(() {
      _selectedClass = classroomId;
      _selectedLesson = null;
      _lessons = [];
    });
    if (classroomId == null) return;
    final lessons = await (widget.loadLessons ?? ApiService().getMaterialTitles)(classroomId);
    if (mounted && _selectedClass == classroomId) setState(() => _lessons = lessons);
  }

  Future<String?> _postToApi(String classroomId, String title, String body) async {
    final api = ApiService();
    final teacherId = await api.getEntityId();
    if (teacherId == null || teacherId.isEmpty) {
      return 'Your teacher profile could not be found. Please sign in again.';
    }
    return api.createAnnouncement(
      authorTeacherId: teacherId,
      classroomId: classroomId,
      title: title,
      body: body,
    );
  }

  void _showMessage(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _isLoading = true);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _attachedFiles.add(File(image.path));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image attached successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _takePhoto() async {
    try {
      setState(() => _isLoading = true);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _attachedFiles.add(File(image.path));
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo taken successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking photo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Image Source',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D3B66),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blue),
                title: Text('Gallery', style: GoogleFonts.inter()),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.green),
                title: Text('Camera', style: GoogleFonts.inter()),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFile() async {
    // You can implement file picking here using file_picker package
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File picker is being integrated.'),
        backgroundColor: Color(0xFF0D3B66),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _removeFile(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  Future<void> _sendAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;
    final classroomId = _selectedClass;
    if (classroomId == null) {
      _showMessage('Select a class first.', Colors.red);
      return;
    }

    setState(() => _isLoading = true);
    final message = _messageController.text.trim();
    final body = _selectedLesson == null ? message : '$message\n\nLesson: $_selectedLesson';
    final error = await (widget.post ?? _postToApi)(classroomId, _titleController.text.trim(), body);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error != null) {
      _showMessage(error, Colors.red);
      return;
    }
    // Announcements carry text only; files picked here stay on the device.
    _showMessage(
      _attachedFiles.isEmpty
          ? 'Announcement sent to the class and its parents.'
          : 'Announcement sent. Attachments are not supported yet and were not sent.',
      Colors.green,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
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
          'Announcements',
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0D3B66),
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        actions: [
          Bounceable(
            key: const ValueKey('send-announcement'),
            onTap: _isLoading ? null : _sendAnnouncement,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: _isLoading
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF0D3B66), Color(0xFF1E5B94)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                color: _isLoading ? Colors.grey.shade300 : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    )
                  : Text(
                      'Send Announcement',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0D3B66), Color(0xFF1E5B94)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
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
                              Icons.campaign_rounded,
                              size: 100,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Send Update',
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Reach out to parents instantly with important school updates and announcements.',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 20),
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Professional Portal',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
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

                    const SizedBox(height: 24),

                    // Class Selection Section
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Target Audience Dropdown
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF4A90E2,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.group_rounded,
                                        color: Color(0xFF4A90E2),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Recipient Group',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0D3B66),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F6F8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedClass,
                                      hint: Text(
                                        'Select Target Class',
                                        style: GoogleFonts.inter(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      isExpanded: true,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF0D3B66),
                                      ),
                                      items: _classes.map((ClassroomDto classItem) {
                                        return DropdownMenuItem<String>(
                                          value: classItem.id,
                                          child: Text(
                                            classItem.name,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF0D3B66),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _selectClass,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Divider(color: Colors.grey.shade200, height: 1),

                          // Title Input
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.title_rounded,
                                        color: Colors.purple,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Announcement Title',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0D3B66),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _titleController,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: const Color(0xFF0D3B66),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., Parent-Teacher Meeting',
                                    hintStyle: GoogleFonts.inter(
                                      color: Colors.grey.shade400,
                                      fontSize: 14,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFFF3F6F8),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0D3B66),
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter a title';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          Divider(color: Colors.grey.shade200, height: 1),

                          // Lesson Selection
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.menu_book_rounded,
                                        color: Colors.green,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Related Lesson',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0D3B66),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F6F8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedLesson,
                                      hint: Text(
                                        'Choose a lesson (optional)',
                                        style: GoogleFonts.inter(
                                          color: Colors.grey.shade500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      isExpanded: true,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Color(0xFF0D3B66),
                                      ),
                                      items: _lessons.map((String lesson) {
                                        return DropdownMenuItem<String>(
                                          value: lesson,
                                          child: Text(
                                            lesson,
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF0D3B66),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          _selectedLesson = newValue;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Message Body Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.message_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Message Content',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D3B66),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _messageController,
                            maxLines: 6,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: const Color(0xFF0D3B66),
                              height: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Compose your announcement here...',
                              hintStyle: GoogleFonts.inter(
                                color: Colors.grey.shade400,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF3F6F8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0D3B66),
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a message';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Attachments Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.attach_file_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Attachments',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0D3B66),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Attachment buttons
                          Row(
                            children: [
                              Expanded(
                                child: Bounceable(
                                  onTap: _isLoading
                                      ? null
                                      : _showImageSourceDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isLoading
                                          ? Colors.grey.shade200
                                          : Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isLoading
                                            ? Colors.grey.shade300
                                            : Colors.blue.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.image_rounded,
                                          color: _isLoading
                                              ? Colors.grey
                                              : Colors.blue,
                                          size: 24,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Image',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _isLoading
                                                ? Colors.grey
                                                : Colors.blue,
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
                                  onTap: _isLoading ? null : _pickFile,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _isLoading
                                          ? Colors.grey.shade200
                                          : Colors.purple.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _isLoading
                                            ? Colors.grey.shade300
                                            : Colors.purple.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.description_rounded,
                                          color: _isLoading
                                              ? Colors.grey
                                              : Colors.purple,
                                          size: 24,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Document',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: _isLoading
                                                ? Colors.grey
                                                : Colors.purple,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Display attached files
                          if (_attachedFiles.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Attached Files',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._attachedFiles.asMap().entries.map((entry) {
                              int index = entry.key;
                              File file = entry.value;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.image_rounded,
                                      color: Colors.blue.shade300,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        file.path.split('/').last,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Bounceable(
                                      onTap: () => _removeFile(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.red,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF0D3B66),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Processing...',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0D3B66),
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
}
