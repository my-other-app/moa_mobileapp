import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/time_ago.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/providers/support_providers.dart';
import 'package:finnet/features/support/presentation/support_routes.dart';
import 'package:finnet/features/support/presentation/widgets/support_widgets.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// My requests (`/profile/help/requests`): what the person asked the
/// support desk, newest first, with where each stands and a dot for a
/// reply they have not seen.
class MyRequestsPage extends ConsumerWidget {
  const MyRequestsPage({super.key});

  static const newKey = ValueKey('requests-new');
  static const emptyKey = ValueKey('requests-empty');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(myRequestsProvider);
    final topics = ref.watch(supportTopicsProvider).valueOrNull ?? const [];
    final hasDesk = requests.valueOrNull != null || requests.hasError;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: supportAppBar('MY REQUESTS', actions: [
        if (hasDesk)
          TextButton(
            key: newKey,
            style: TextButton.styleFrom(foregroundColor: AppColors.ink),
            onPressed: () => context.push(SupportLocations.contact),
            child: const Text('New'),
          ),
      ]),
      body: requests.when(
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
        ),
        error: (e, _) => ErrorView(
          message: extractErrorMessage(e,
              defaultMessage: "Couldn't load your requests."),
          onRetry: () => ref.invalidate(myRequestsProvider),
        ),
        data: (list) {
          if (list == null) return const EmailSupportView();
          if (list.isEmpty) return const _Empty();
          return RefreshIndicator(
            color: AppColors.ink,
            onRefresh: () => ref.refresh(myRequestsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 0, indent: 16, endIndent: 16),
              itemBuilder: (context, i) =>
                  _RequestRow(request: list[i], topics: topics),
            ),
          );
        },
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.topics});

  final SupportRequestSummary request;
  final List<SupportTopic> topics;

  @override
  Widget build(BuildContext context) {
    final title =
        request.subject ?? SupportTopic.labelFor(request.topic, topics);
    final number = supportNumber(request.number);
    final when = request.updatedAt;
    final line = [
      if (number.isNotEmpty) number,
      if (when != null) 'Updated ${timeAgo(when)}',
    ].join(' · ');

    return InkWell(
      key: ValueKey('request-${request.id}'),
      onTap: () => context.push(SupportLocations.request(request.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: request.unread
                  ? Container(
                      key: ValueKey('request-unread-${request.id}'),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          request.unread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  if (line.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(line,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600])),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SupportStatusChip(request.status),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Center(
      key: MyRequestsPage.emptyKey,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📭', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text(
              'No requests yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              "When you contact us, your request and our replies show here.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.push(SupportLocations.contact),
              child: const Text('CONTACT US'),
            ),
          ],
        ),
      ),
    );
  }
}
