import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:tamdansers/Screen/Messages/messages_screen.dart';
import 'package:tamdansers/services/api_models.dart';

// F9: the Messages tab talks to /api/school/messages (it used to show sample chats, B42).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late List<ConversationDto> conversations;
  late Map<String, List<ChatMessageDto>> threads;
  late List<String> sent;
  late List<String> read;

  MessagingApi fakeApi({String? sendError}) => MessagingApi(
        conversations: () async => List.of(conversations),
        contacts: () async => [MessageContactDto(kind: 'Teacher', name: 'Anvar Qodirov', teacherId: 't1', studentId: 's1')],
        start: (contact) async {
          final c = ConversationDto(id: 'new', title: contact.name, subtitle: 'Teacher');
          conversations.insert(0, c);
          threads['new'] = [];
          return c;
        },
        messages: (id) async => List.of(threads[id] ?? []),
        send: (id, body) async {
          if (sendError != null) return sendError;
          sent.add('$id|$body');
          threads[id]!.add(ChatMessageDto(id: 'm${sent.length}', senderName: 'Me', body: body, sentAt: DateTime.now(), isMine: true));
          return null;
        },
        markRead: (id) async => read.add(id),
      );

  setUp(() {
    conversations = [ConversationDto(id: 'c1', title: 'Malika Aliyeva', subtitle: 'Parent of Nodira', lastMessage: 'Thank you!', unreadCount: 2)];
    threads = {
      'c1': [ChatMessageDto(id: 'm0', senderName: 'Malika Aliyeva', body: 'Thank you!', sentAt: DateTime(2026, 10, 1, 9), isMine: false)],
    };
    sent = [];
    read = [];
  });

  testWidgets('lists conversations with unread counts', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: fakeApi())));
    await tester.pumpAndSettle();

    expect(find.text('Malika Aliyeva'), findsOneWidget);
    expect(find.text('2 unread'), findsOneWidget);
    expect(find.text('John Doe (Parent)'), findsNothing);
  });

  testWidgets('opening a conversation marks it read and a reply is sent', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: fakeApi())));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Malika Aliyeva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('message-input')), 'See you on Friday.');
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await tester.pumpAndSettle();

    expect(read, contains('c1'));
    expect(sent, ['c1|See you on Friday.']);
    expect(find.text('See you on Friday.'), findsOneWidget);
  });

  testWidgets('a refused message shows why and stays in the box', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: fakeApi(sendError: 'Too many messages in a minute.'))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Malika Aliyeva'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('message-input')), 'Hello again');
    await tester.tap(find.byKey(const ValueKey('send-message')));
    await tester.pumpAndSettle();

    expect(find.text('Too many messages in a minute.'), findsOneWidget);
    expect(find.text('Hello again'), findsOneWidget); // still in the input
  });

  testWidgets('a new message starts a conversation with a contact', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MessagesScreen(api: fakeApi())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-message')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anvar Qodirov'));
    await tester.pumpAndSettle();

    expect(find.text('Say hello 👋'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Anvar Qodirov'), findsOneWidget);
  });
}
