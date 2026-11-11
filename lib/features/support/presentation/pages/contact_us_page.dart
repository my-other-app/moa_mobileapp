import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/support/data/support_api.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/providers/support_providers.dart';
import 'package:finnet/features/support/presentation/support_routes.dart';
import 'package:finnet/features/support/presentation/widgets/support_widgets.dart';

/// Contact us (`/profile/help/contact`): a topic, the message, up to three
/// screenshots and, if they like, which of their events it is about. Sent
/// as a request to the support desk, which answers here and by email.
class ContactUsPage extends ConsumerStatefulWidget {
  const ContactUsPage({super.key, this.initialTopic, this.initialEventId});

  final String? initialTopic;
  final int? initialEventId;

  /// The new request's screenshots.
  static const trayId = 'new';

  static const messageKey = ValueKey('contact-message');
  static const sendKey = ValueKey('contact-send');
  static const eventKey = ValueKey('contact-event');
  static const sentKey = ValueKey('contact-sent');
  static const viewRequestKey = ValueKey('contact-view-request');
  static const doneKey = ValueKey('contact-done');

  @override
  ConsumerState<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends ConsumerState<ContactUsPage> {
  final _message = TextEditingController();
  String? _topic;
  int? _eventId;
  bool _sending = false;
  String? _error;
  bool _deskMissing = false;
  SupportRequestSent? _sent;

  @override
  void initState() {
    super.initState();
    _topic = widget.initialTopic;
    _eventId = widget.initialEventId;
    _message.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool _ready(SupportAttachments tray) =>
      _topic != null &&
      _message.text.trim().isNotEmpty &&
      !tray.busy &&
      !tray.hasFailed &&
      !_sending;

  Future<void> _send() async {
    final tray = ref.read(supportAttachmentsProvider(ContactUsPage.trayId).notifier);
    if (!_ready(tray)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final version = await ref.read(supportAppVersionProvider)();
      final sent = await ref.read(supportApiProvider).send(
            topic: _topic!,
            message: _message.text.trim(),
            attachments: tray.keys,
            context: SupportContext(appVersion: version, eventId: _eventId),
          );
      if (!mounted) return;
      ref.invalidate(myRequestsProvider);
      tray.clear();
      setState(() {
        _sending = false;
        _sent = sent;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        if (isDeskMissing(e)) {
          _deskMissing = true;
        } else if (statusCodeOf(e) == 429) {
          _error = "You've sent a few requests just now. Please wait a "
              'little and try again.';
        } else {
          _error = extractErrorMessage(e,
              defaultMessage: "Couldn't send your request. Try again.");
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: supportAppBar('CONTACT US'),
      body: _deskMissing
          ? const EmailSupportView()
          : _sent != null
              ? _Sent(sent: _sent!)
              : _form(context),
    );
  }

  Widget _form(BuildContext context) {
    final topics =
        ref.watch(supportTopicsProvider).valueOrNull ?? SupportTopic.defaults;
    final events = ref.watch(supportEventChoicesProvider);
    ref.watch(supportAttachmentsProvider(ContactUsPage.trayId));
    final tray =
        ref.read(supportAttachmentsProvider(ContactUsPage.trayId).notifier);
    final eventChosen =
        _eventId != null && events.any((e) => e.eventId == _eventId);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const _Label('What is it about?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final topic in topics)
                ChoiceChip(
                  key: ValueKey('contact-topic-${topic.key}'),
                  label: Text(topic.label),
                  selected: _topic == topic.key,
                  showCheckmark: false,
                  selectedColor: AppColors.paleYellow,
                  backgroundColor: AppColors.softGrey,
                  side: BorderSide(
                    color: _topic == topic.key
                        ? AppColors.ink
                        : Colors.transparent,
                  ),
                  onSelected: (_) => setState(() => _topic = topic.key),
                ),
            ],
          ),
          if (events.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _Label('Is it about one of your events? (optional)'),
            DropdownButtonFormField<int?>(
              key: ContactUsPage.eventKey,
              initialValue: eventChosen ? _eventId : null,
              isExpanded: true,
              decoration: _boxDecoration(),
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('No, something else')),
                for (final event in events)
                  DropdownMenuItem<int?>(
                    value: event.eventId,
                    child: Text(
                      event.when == null
                          ? event.name
                          : '${event.name} · '
                              '${DateFormat('d MMM').format(event.when!)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) => setState(() => _eventId = id),
            ),
          ],
          const SizedBox(height: 20),
          const _Label('Your message'),
          const NeverShareNote(),
          const SizedBox(height: 10),
          TextField(
            key: ContactUsPage.messageKey,
            controller: _message,
            minLines: 5,
            maxLines: 10,
            maxLength: maxSupportMessageLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: _boxDecoration(
              hint: 'What happened? The more you tell us, the faster we '
                  'can help.',
            ),
          ),
          const SizedBox(height: 4),
          const _Label('Screenshots (optional)'),
          const AttachmentTray(trayId: ContactUsPage.trayId),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const ValueKey('contact-error'),
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 14),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: ContactUsPage.sendKey,
              onPressed: _ready(tray) ? _send : null,
              child: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('SEND'),
            ),
          ),
          if (_topic == null || _message.text.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _topic == null
                    ? 'Choose what it is about, then write your message.'
                    : 'Write your message to send it.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration _boxDecoration({String? hint}) => InputDecoration(
      hintText: hint,
      hintMaxLines: 3,
      filled: true,
      fillColor: AppColors.softGrey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.ink),
      ),
    );

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      );
}

/// "Request #1042 sent": what happens next, and the request.
class _Sent extends StatelessWidget {
  const _Sent({required this.sent});

  final SupportRequestSent sent;

  @override
  Widget build(BuildContext context) {
    final number = supportNumber(sent.number);
    return Center(
      key: ContactUsPage.sentKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            Text(
              number.isEmpty ? 'Request sent' : 'Request $number sent',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll reply here and by email, and you'll get a notification "
              'when we do.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            if (sent.id.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: ContactUsPage.viewRequestKey,
                  onPressed: () => context
                      .pushReplacement(SupportLocations.request(sent.id)),
                  child: const Text('VIEW REQUEST'),
                ),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: ContactUsPage.doneKey,
                onPressed: () => context.pop(),
                child: const Text('DONE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
