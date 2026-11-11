import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/core/services/push_arrivals.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/support/data/support_api.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/providers/support_providers.dart';
import 'package:finnet/features/support/presentation/support_routes.dart';
import 'package:finnet/features/support/presentation/widgets/support_widgets.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// One request (`/profile/help/requests/{id}`): its thread -- the
/// person's messages and the team's replies, never the team's notes -- and
/// a box to reply while the request takes replies. What a `support_reply`
/// push opens. A push that arrives while it is open reads it again.
class SupportRequestPage extends ConsumerStatefulWidget {
  const SupportRequestPage({super.key, required this.caseId});

  final String caseId;

  static const replyKey = ValueKey('request-reply');
  static const sendKey = ValueKey('request-send');
  static const notFoundKey = ValueKey('request-not-found');
  static const closedKey = ValueKey('request-closed');
  static const surveyKey = ValueKey('request-survey');

  @override
  ConsumerState<SupportRequestPage> createState() =>
      _SupportRequestPageState();
}

class _SupportRequestPageState extends ConsumerState<SupportRequestPage> {
  final _reply = TextEditingController();
  bool _sending = false;
  bool _surveySent = false;

  String get _trayId => 'reply-${widget.caseId}';

  @override
  void initState() {
    super.initState();
    _reply.addListener(() => setState(() {}));
    PushArrivals.count.addListener(_reload);
  }

  @override
  void dispose() {
    PushArrivals.count.removeListener(_reload);
    _reply.dispose();
    super.dispose();
  }

  void _reload() {
    if (mounted) ref.invalidate(supportRequestProvider(widget.caseId));
  }

  bool _ready(SupportAttachments tray) =>
      _reply.text.trim().isNotEmpty &&
      !tray.busy &&
      !tray.hasFailed &&
      !_sending;

  Future<void> _send() async {
    final tray = ref.read(supportAttachmentsProvider(_trayId).notifier);
    if (!_ready(tray)) return;
    setState(() => _sending = true);
    try {
      final sent = await ref.read(supportApiProvider).reply(
            widget.caseId,
            message: _reply.text.trim(),
            attachments: tray.keys,
          );
      if (!mounted) return;
      _reply.clear();
      tray.clear();
      setState(() => _sending = false);
      ref.invalidate(myRequestsProvider);
      if (sent.newCase && sent.caseId != widget.caseId) {
        // The old request was closed: the reply opened a new one, linked
        // to it. That is where the conversation goes on.
        final number = supportNumber(sent.number);
        showToast(context,
            'Sent as a new request${number.isEmpty ? '' : ' $number'}.');
        context.pushReplacement(SupportLocations.request(sent.caseId));
        return;
      }
      ref.invalidate(supportRequestProvider(widget.caseId));
      showToast(context, 'Reply sent.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      showToast(
        context,
        extractErrorMessage(e,
            defaultMessage: "Couldn't send your reply. Try again."),
        icon: Icons.error_outline,
      );
    }
  }

  Future<void> _answerSurvey(bool solved) async {
    try {
      await ref.read(supportApiProvider).survey(widget.caseId, solved: solved);
      if (!mounted) return;
      setState(() => _surveySent = true);
      showToast(context, 'Thanks for telling us.');
    } catch (e) {
      if (!mounted) return;
      showToast(context, "Couldn't send that. Try again.",
          icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(supportRequestProvider(widget.caseId));
    // Opening a request reads its replies: the list's dot goes.
    ref.listen(supportRequestProvider(widget.caseId), (_, next) {
      if (next.valueOrNull != null) ref.invalidate(myRequestsProvider);
    });
    final number = supportNumber(request.valueOrNull?.number);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: supportAppBar(number.isEmpty ? 'REQUEST' : 'REQUEST $number'),
      body: request.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
        ),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e,
              defaultMessage: "Couldn't load this request."),
          onRetry: _reload,
        ),
        data: (detail) =>
            detail == null ? const _NotFound() : _thread(context, detail),
      ),
    );
  }

  Widget _thread(BuildContext context, SupportRequestDetail detail) {
    final topics = ref.watch(supportTopicsProvider).valueOrNull ?? const [];
    final askSurvey = detail.canSurvey && !_surveySent;
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.ink,
            onRefresh: () =>
                ref.refresh(supportRequestProvider(widget.caseId).future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        detail.subject ??
                            SupportTopic.labelFor(detail.topic, topics),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SupportStatusChip(detail.status),
                  ],
                ),
                const SizedBox(height: 16),
                for (final message in detail.messages)
                  _Bubble(message: message),
                if (askSurvey)
                  _Survey(onAnswer: _answerSurvey),
              ],
            ),
          ),
        ),
        if (detail.canReply)
          _ReplyBox(
            controller: _reply,
            trayId: _trayId,
            sending: _sending,
            ready: _ready,
            onSend: _send,
          )
        else
          const _Closed(),
      ],
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = !message.fromUs;
    final when = message.createdAt;
    final who = mine ? 'You' : (message.authorName ?? 'MyOtherApp Support');
    final meta = [
      who,
      if (when != null) DateFormat('d MMM, h:mm a').format(when),
    ].join(' · ');

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Container(
          key: ValueKey('message-${message.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: mine ? AppColors.ink : AppColors.softGrey,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mine ? Colors.white70 : const Color(0xFF6B7280),
                ),
              ),
              if (message.body.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectableText(
                  message.body,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: mine ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
              for (final file in message.attachments)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InkWell(
                    key: ValueKey('attachment-${file.id ?? file.name}'),
                    onTap: !file.canOpen
                        ? null
                        : () async {
                            var opened = false;
                            try {
                              opened = await ref.read(
                                  supportAttachmentOpenerProvider)(file);
                            } catch (_) {
                              opened = false;
                            }
                            if (!opened && context.mounted) {
                              showToast(context, "Couldn't open ${file.name}.",
                                  icon: Icons.error_outline);
                            }
                          },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.attach_file,
                            size: 16,
                            color: mine ? Colors.white70 : AppColors.ink),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            file.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              decoration: file.canOpen
                                  ? TextDecoration.underline
                                  : null,
                              color: mine ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplyBox extends ConsumerWidget {
  const _ReplyBox({
    required this.controller,
    required this.trayId,
    required this.sending,
    required this.ready,
    required this.onSend,
  });

  final TextEditingController controller;
  final String trayId;
  final bool sending;
  final bool Function(SupportAttachments tray) ready;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(supportAttachmentsProvider(trayId));
    final tray = ref.read(supportAttachmentsProvider(trayId).notifier);
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NeverShareNote(),
              const SizedBox(height: 6),
              AttachmentTray(trayId: trayId, compact: true),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: SupportRequestPage.replyKey,
                      controller: controller,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: maxSupportMessageLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Write a reply',
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.softGrey,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    key: SupportRequestPage.sendKey,
                    style: IconButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        disabledBackgroundColor: const Color(0xFFD1D5DB)),
                    tooltip: 'Send',
                    onPressed: ready(tray) ? onSend : null,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Survey extends StatelessWidget {
  const _Survey({required this.onAnswer});

  final void Function(bool solved) onAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: SupportRequestPage.surveyKey,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Did we solve it?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('request-survey-yes'),
                  onPressed: () => onAnswer(true),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 15)),
                  child: const Text('Yes'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('request-survey-no'),
                  onPressed: () => onAnswer(false),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 15)),
                  child: const Text('No'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Closed extends StatelessWidget {
  const _Closed();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: SupportRequestPage.closedKey,
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: AppColors.softGrey,
        child: Row(
          children: [
            const Expanded(
              child: Text('This request is closed. Need more help?',
                  style: TextStyle(fontSize: 14)),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.ink),
              onPressed: () => context.push(SupportLocations.contact),
              child: const Text('New request'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: SupportRequestPage.notFoundKey,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text("We couldn't find this request",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'It may belong to another account. Your requests are in My '
              'requests.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.pushReplacement(SupportLocations.requests),
              child: const Text('MY REQUESTS'),
            ),
          ],
        ),
      ),
    );
  }
}
