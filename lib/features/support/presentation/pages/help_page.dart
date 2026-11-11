import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/support/domain/support.dart';
import 'package:finnet/features/support/presentation/providers/support_providers.dart';
import 'package:finnet/features/support/presentation/support_routes.dart';
import 'package:finnet/features/support/presentation/widgets/support_widgets.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// Settings > Help and support (`/profile/help`): short answers to common
/// questions, then Contact us and My requests (feature-register
/// `support-leads-contract.md`, App).
///
/// On a server without the help desk yet (`GET /support/help` answers
/// 404), the page is what Settings offered before it: the support email
/// and the website's Help Centre.
class HelpPage extends ConsumerWidget {
  const HelpPage({super.key});

  static const contactKey = ValueKey('help-contact');
  static const requestsKey = ValueKey('help-requests');
  static const footerEmailKey = ValueKey('help-footer-email');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers = ref.watch(helpAnswersProvider);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: supportAppBar('HELP AND SUPPORT'),
      body: answers.when(
        data: (list) => list == null
            ? const EmailSupportView()
            : _HelpBody(answers: list),
        loading: () => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
        ),
        error: (e, _) => ErrorView(
          message:
              extractErrorMessage(e, defaultMessage: "Couldn't load help."),
          onRetry: () => ref.invalidate(helpAnswersProvider),
          actionLabel: 'Email us',
          onAction: () => emailSupport(context, ref),
        ),
      ),
    );
  }
}

class _HelpBody extends ConsumerWidget {
  const _HelpBody({required this.answers});

  final List<HelpAnswer> answers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: AppColors.ink,
      onRefresh: () => ref.refresh(helpAnswersProvider.future),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _ActionCard(
            key: HelpPage.contactKey,
            emoji: '💬',
            title: 'Contact us',
            subtitle: 'Ask a question or tell us what went wrong',
            onTap: () => context.push(SupportLocations.contact),
          ),
          const SizedBox(height: 10),
          _ActionCard(
            key: HelpPage.requestsKey,
            emoji: '📨',
            title: 'My requests',
            subtitle: 'What you asked, and our replies',
            onTap: () => context.push(SupportLocations.requests),
          ),
          if (answers.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'COMMON QUESTIONS',
              style: TextStyle(fontFamily: 'BebasNeue', fontSize: 22),
            ),
            const SizedBox(height: 4),
            for (final answer in answers) _AnswerTile(answer: answer),
          ],
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              key: HelpPage.footerEmailKey,
              style: TextButton.styleFrom(foregroundColor: AppColors.ink),
              onPressed: () => emailSupport(context, ref),
              child: const Text('Prefer email? Write to $supportEmail'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softGrey,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[700])),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.answer});

  final HelpAnswer answer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      // No lines above and below an open answer.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('help-answer-${answer.id}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: AppColors.ink,
        collapsedIconColor: AppColors.ink,
        title: Text(
          answer.question,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        children: [
          SelectableText(
            answer.answer,
            style: const TextStyle(
                fontSize: 14, height: 1.45, color: Color(0xFF374151)),
          ),
        ],
      ),
    );
  }
}
