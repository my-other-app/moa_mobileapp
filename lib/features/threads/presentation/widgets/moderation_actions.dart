import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/presentation/providers/moderation_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/report_sheet.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_feedback.dart';
import 'package:finnet/shared/widgets/confirmation_dialog.dart';

/// What a person sees once a report has gone through.
const reportThanksMessage = 'Thanks — our team will review this.';

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Say what went wrong with a report, block or unblock.
///
/// An expired session gets the sign-in prompt, as everywhere in Threads;
/// the rest gets [moderationFailureMessage]'s plain words.
void showModerationFailure(
  BuildContext context,
  WidgetRef ref,
  Failure failure, {
  required String fallback,
}) {
  if (!context.mounted) return;
  if (failure is AuthFailure && failure.code != '403') {
    showSignInPrompt(
      context,
      ref,
      'Your session has expired. Sign in again to continue.',
    );
    return;
  }
  _snack(context, moderationFailureMessage(failure, fallback: fallback));
}

/// Report a post or comment: sign in if need be, pick a reason, send, and
/// thank them.
Future<void> reportContent(
  BuildContext context,
  WidgetRef ref, {
  required ReportTarget target,
  required String what,
}) async {
  if (!ensureSignedIn(context, ref, 'Sign in to report a $what.')) return;

  final notifier = ref.read(moderationProvider.notifier);
  final result = await showReportSheet(
    context,
    what: what,
    onSubmit: (reason, note) => notifier.report(target, reason, note: note),
  );
  if (!context.mounted) return;

  switch (result) {
    case ReportSheetResult.sent:
      _snack(context, reportThanksMessage);
    case ReportSheetResult.needsSignIn:
      showSignInPrompt(
        context,
        ref,
        'Your session has expired. Sign in again to continue.',
      );
    case null:
      break;
  }
}

/// Block the author of a comment, once they confirm.
///
/// Answers true when the block went through -- the caller then refetches,
/// so the server's view (which hides blocked people's comments) takes over
/// from the local one.
Future<bool> confirmAndBlock(
  BuildContext context,
  WidgetRef ref, {
  required int userId,
  required String name,
  String? avatarUrl,
}) async {
  if (!ensureSignedIn(context, ref, 'Sign in to block someone.')) {
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ConfirmationDialog(
      title: 'BLOCK ${name.toUpperCase()}?',
      message: "You won't see their comments any more, and they won't be "
          'told. You can unblock them in Settings.',
      confirmText: 'BLOCK',
      onConfirm: () => Navigator.of(dialogContext).pop(true),
      onCancel: () => Navigator.of(dialogContext).pop(false),
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final failure = await ref
      .read(moderationProvider.notifier)
      .block(userId, name: name, avatarUrl: avatarUrl);
  if (!context.mounted) return failure == null;

  if (failure != null) {
    showModerationFailure(
      context,
      ref,
      failure,
      fallback: "Couldn't block $name. Please try again.",
    );
    return false;
  }
  _snack(context, '$name is blocked.');
  return true;
}
