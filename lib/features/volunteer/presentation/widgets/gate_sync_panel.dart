import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finnet/features/volunteer/domain/gate_copy.dart';
import 'package:finnet/features/volunteer/presentation/widgets/gate_outcome_card.dart';

String _scans(int n) => n == 1 ? '1 scan' : '$n scans';

/// The saved scans: how many wait, and what the server said of those it
/// has taken. Every guest behind them was let in at the time, so the ones
/// it refused are listed by name, each with why, until "Done".
class GateSyncPanel extends StatelessWidget {
  const GateSyncPanel({
    super.key,
    required this.queued,
    required this.offline,
    required this.syncing,
    this.syncError,
    this.report,
    this.onSendNow,
    this.onDone,
  });

  static const sendNowKey = ValueKey('gate-send-now');
  static const doneKey = ValueKey('gate-report-done');

  final int queued;
  final bool offline;
  final bool syncing;
  final String? syncError;
  final ReplayReport? report;
  final VoidCallback? onSendNow;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (queued > 0 || offline) _waiting(),
        if (syncError != null)
          _strip(
            color: const Color(0xFFFDECEC),
            ink: const Color(0xFF7F1D1D),
            icon: Icons.error_outline,
            text: syncError!,
          ),
        if (report != null) _report(report),
      ],
    );
  }

  Widget _waiting() {
    final String text;
    if (syncing) {
      text = 'Sending ${_scans(queued)} saved on this phone…';
    } else if (queued == 0) {
      text = 'No signal. Scans are saved on this phone and sent when '
          "it's back.";
    } else if (offline) {
      text = 'No signal. ${_scans(queued)} saved on this phone, sent '
          "when it's back.";
    } else {
      text = '${_scans(queued)} saved on this phone, waiting to be sent.';
    }
    return _strip(
      color: const Color(0xFFE8F0FE),
      ink: const Color(0xFF1E3A8A),
      icon: offline ? Icons.cloud_off : Icons.cloud_upload_outlined,
      text: text,
      action: queued > 0 && !syncing && onSendNow != null
          ? TextButton(
              key: sendNowKey,
              onPressed: onSendNow,
              child: const Text('Send now'),
            )
          : null,
    );
  }

  Widget _strip({
    required Color color,
    required Color ink,
    required IconData icon,
    required String text,
    Widget? action,
  }) {
    return Container(
      color: color,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Icon(icon, color: ink, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: TextStyle(color: ink, fontSize: 13))),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _report(ReplayReport report) {
    final problems = report.problems;
    if (problems.isEmpty) {
      return _strip(
        color: const Color(0xFFE8F7EE),
        ink: const Color(0xFF14532D),
        icon: Icons.check,
        text: '${report.synced} saved ${report.synced == 1 ? 'scan' : 'scans'} '
            'sent, all checked in.',
        action: TextButton(
            key: doneKey, onPressed: onDone, child: const Text('OK')),
      );
    }
    final n = problems.length;
    return Container(
      color: const Color(0xFFFDECEC),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Color(0xFFD93025), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$n saved ${n == 1 ? 'scan needs' : 'scans need'} a look',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7F1D1D),
                      fontSize: 15),
                ),
              ),
              TextButton(
                  key: doneKey, onPressed: onDone, child: const Text('Done')),
            ],
          ),
          Text(
            'Checked in: ${report.admitted} of ${report.synced} sent. These '
            'were let in with no signal, and the server did not admit them:',
            style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 13),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView(
              shrinkWrap: true,
              children: [for (final p in problems) _problem(p)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _problem(ReplayProblem p) {
    final style = gateToneStyle(p.tone);
    final at = p.scannedAt == null
        ? null
        : DateFormat('HH:mm').format(p.scannedAt!.toLocal());
    final where = [p.door, at].whereType<String>().join(' · ');
    return Padding(
      key: ValueKey('gate-problem-${p.clientRef}'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: style.background,
              border: Border.all(color: style.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(p.tag,
                style: TextStyle(
                    color: style.ink,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name ?? p.ticket,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (p.name != null)
                  Text(p.ticket,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
                Text(p.reason, style: const TextStyle(fontSize: 13)),
                if (where.isNotEmpty)
                  Text('Scanned $where',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
