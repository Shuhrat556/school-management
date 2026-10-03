import 'package:intl/intl.dart';
import 'package:tamdansers/constants/app_image.dart';
import 'package:tamdansers/services/api_models.dart';

const _eventImages = [AppImages.event1, AppImages.event2, AppImages.event3, AppImages.grade1];

// Published announcements in the shape the dashboards' event cards use (they used to show
// sample events). The badge that showed a made-up attendee count shows the author.
List<Map<String, dynamic>> eventsFromAnnouncements(List<AnnouncementDto> announcements) {
  final published = announcements.where((a) => a.isPublished).toList();
  return [
    for (var i = 0; i < published.length; i++)
      {
        "title": published[i].title,
        "date": DateFormat('dd MMM yyyy').format(published[i].publishedAt),
        "time": DateFormat('h:mm a').format(published[i].publishedAt),
        "location": published[i].classroomName ?? "Whole school",
        "img": _eventImages[i % _eventImages.length],
        "category": "Announcement",
        "attendees": published[i].authorName,
        "description": published[i].body,
      },
  ];
}
