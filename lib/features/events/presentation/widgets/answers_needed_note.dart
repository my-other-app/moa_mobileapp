import 'package:flutter/material.dart';

import 'package:finnet/features/events/domain/missing_answers.dart';
import 'package:finnet/features/events/presentation/utils/site_links.dart';

/// "2 details needed · Add them": the club asked this person for answers
/// its sign-up form didn't have when they signed up (`answers_needed`). On
/// the ticket, a registration's card in My events and a registration under
/// review; tapping it opens their personal link -- in the app, on the
/// missing-answers screen. Amber, as a note that asks for something, not a
/// warning: the ticket is unchanged either way.
class AnswersNeededNote extends StatelessWidget {
  const AnswersNeededNote({
    super.key,
    required this.needed,
    this.dark = false,
    this.onReturn,
  });

  final AnswersNeeded needed;

  /// On the ticket's dark screen.
  final bool dark;

  /// Called once the screen it opened is closed: to read again what this
  /// note was on, which will no longer ask once the details are in.
  final VoidCallback? onReturn;

  static const noteKey = ValueKey('answers-needed-note');

  Future<void> _open(BuildContext context) async {
    await openSiteLink(context, needed.url);
    onReturn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xFF92400E);
    final soft = dark ? Colors.white.withAlpha(190) : const Color(0xFFB45309);
    final accent = dark ? Colors.amber.shade300 : const Color(0xFFD97706);
    final by = needed.byLine;
    return Semantics(
      button: true,
      label: [needed.line, if (by != null) by].join('. '),
      excludeSemantics: true,
      child: Material(
        key: noteKey,
        color: dark ? Colors.white.withAlpha(14) : const Color(0xFFFFFBEB),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: dark
                ? Colors.amber.shade300.withAlpha(140)
                : const Color(0xFFFCD34D),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              children: [
                Icon(Icons.edit_note, size: 24, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        needed.line,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      if (by != null)
                        Text(
                          by,
                          style: TextStyle(fontSize: 12.5, color: soft),
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
