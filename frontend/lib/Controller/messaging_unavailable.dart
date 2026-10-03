import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// The Messages tab until real messaging exists (PLAN F9). The tab used to show sample
// conversations and "sent" messages that reached no one, so it now says so and points
// to the channels that do work.
class MessagingUnavailable extends StatelessWidget {
  final String explanation;
  final List<(IconData, String, WidgetBuilder)> actions;

  const MessagingUnavailable({super.key, required this.explanation, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0D3B66);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Messages', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: ink)),
            const SizedBox(height: 32),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.forum_outlined, size: 40, color: ink),
                  const SizedBox(height: 16),
                  Text(
                    "Messaging isn't available yet",
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: ink),
                  ),
                  const SizedBox(height: 8),
                  Text(explanation, style: GoogleFonts.inter(color: Colors.grey.shade700, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final (icon, label, builder) in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    leading: Icon(icon, color: ink),
                    title: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ink)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: builder)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
