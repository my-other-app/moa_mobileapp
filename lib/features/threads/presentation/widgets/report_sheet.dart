import 'package:flutter/material.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/themes/color_resources.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/presentation/providers/moderation_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';

/// How the reasons sheet ended, when it ended with more than a dismissal.
enum ReportSheetResult {
  /// The report went through.
  sent,

  /// The session has expired; the caller offers sign-in.
  needsSignIn,
}

/// The words a person picks from, in the order they are offered.
const reportReasonLabels = <ReportReason, String>{
  ReportReason.spam: 'Spam or scam',
  ReportReason.harassment: 'Harassment or bullying',
  ReportReason.hate: 'Hate speech or symbols',
  ReportReason.sexual: 'Sexual content',
  ReportReason.violence: 'Violence or threats',
  ReportReason.misinformation: 'False information',
  ReportReason.other: 'Something else',
};

/// Ask why [what] ("post", "comment") is being reported, with an optional
/// note, and send it through [onSubmit].
///
/// The sheet stays open while the report is sent, so a failure can be said
/// beside the choice and tried again without picking it all over.
Future<ReportSheetResult?> showReportSheet(
  BuildContext context, {
  required String what,
  required Future<Failure?> Function(ReportReason reason, String? note)
      onSubmit,
}) {
  return showModalBottomSheet<ReportSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => ReportSheet(what: what, onSubmit: onSubmit),
  );
}

/// The reasons sheet itself. Public for tests; open it with
/// [showReportSheet].
class ReportSheet extends StatefulWidget {
  final String what;
  final Future<Failure?> Function(ReportReason reason, String? note) onSubmit;

  const ReportSheet({super.key, required this.what, required this.onSubmit});

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _note = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final failure = await widget.onSubmit(reason, _note.text);
    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(ReportSheetResult.sent);
      return;
    }
    // An expired session is not something to retry from here.
    if (failure is AuthFailure && failure.code != '403') {
      Navigator.of(context).pop(ReportSheetResult.needsSignIn);
      return;
    }
    setState(() {
      _sending = false;
      _error = moderationFailureMessage(
        failure,
        fallback: "Couldn't send your report. Please try again.",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'REPORT ${widget.what.toUpperCase()}',
              style: const TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 26,
                color: ThreadCard.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Why are you reporting this ${widget.what}? Our team reviews "
              'every report.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            for (final entry in reportReasonLabels.entries)
              _ReasonTile(
                key: ValueKey('report-reason-${entry.key.name}'),
                label: entry.value,
                selected: _reason == entry.key,
                onTap: _sending
                    ? null
                    : () => setState(() {
                          _reason = entry.key;
                          _error = null;
                        }),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('report-note'),
              controller: _note,
              readOnly: _sending,
              minLines: 2,
              maxLines: 4,
              maxLength: maxReportNoteLength,
              textCapitalization: TextCapitalization.sentences,
              buildCounter: (context,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  currentLength > maxReportNoteLength - 50
                      ? Text('$currentLength/$maxReportNoteLength')
                      : null,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const ValueKey('report-error'),
                style: const TextStyle(fontSize: 13, color: Color(0xFFD32F2F)),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                key: const ValueKey('report-send'),
                onPressed: _reason == null || _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorResources.buttonColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'SEND REPORT',
                        style: TextStyle(fontFamily: 'BebasNeue', fontSize: 22),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One reason: a row with a radio mark. Drawn by hand rather than with
/// RadioListTile, whose group API is deprecated in this Flutter.
class _ReasonTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ReasonTile({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 22,
                color: selected ? ThreadCard.ink : Colors.grey[600],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: ThreadCard.ink,
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
