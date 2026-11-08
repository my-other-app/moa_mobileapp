import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/missing_answers_api.dart';
import 'package:finnet/features/events/domain/missing_answers.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/events/presentation/providers/ticket_details_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/utils/event_sign_in.dart';
import 'package:finnet/features/events/presentation/utils/site_links.dart';
import 'package:finnet/features/events/presentation/widgets/question_fields.dart';
import 'package:finnet/features/events/presentation/widgets/revealed_question.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';

/// `/answers/{eventId}/{ref}?k=…`: the details a club asked this person for
/// after changing its sign-up questions (feature-register
/// `missing-answers-contract.md` §2.3) -- the same page as the website's,
/// from the same personal link (the email, the push, WhatsApp).
///
/// Only the questions asked are shown, with any follow-up an answer to one
/// of them brings (conditional-questions-contract.md §3, decided on the whole
/// form and what the person has answered already), filled in with what they
/// have, and checked as the registration form checks them. No account is
/// needed: the link's key is the proof. Signed in without a key, the
/// person's own token is.
class AnswersPage extends ConsumerStatefulWidget {
  const AnswersPage({
    super.key,
    required this.eventId,
    required this.personRef,
    this.linkKey = '',
  });

  final int eventId;

  /// Who the details are for: a registration, or a request (`q…`). Only
  /// ever passed back.
  final String personRef;

  /// The link's key (`?k=`).
  final String linkKey;

  static const saveKey = ValueKey('answers-save');
  static const viewTicketKey = ValueKey('answers-view-ticket');
  static const viewRequestKey = ValueKey('answers-view-request');
  static const signInKey = ValueKey('answers-sign-in');
  static const retryKey = ValueKey('answers-retry');
  static const moreKey = ValueKey('answers-add-more');

  /// Each state's own key: the form, and the screens instead of it.
  static const formKey = ValueKey('answers-form');
  static const thanksKey = ValueKey('answers-thanks');
  static const doneKey = ValueKey('answers-done');
  static const closedKey = ValueKey('answers-closed');
  static const nothingKey = ValueKey('answers-nothing');
  static const invalidKey = ValueKey('answers-invalid');

  static const thanksTitle = 'Thanks — your ticket is unchanged';
  static const invalidLink =
      "This link doesn't work. Open the one from your email.";

  @override
  ConsumerState<AnswersPage> createState() => _AnswersPageState();
}

enum _View { loading, invalid, failed, form, thanks, done, closed, nothing }

class _AnswersPageState extends ConsumerState<AnswersPage> {
  final _formKey = GlobalKey<FormState>();
  AnswersForm? _form;
  QuestionAnswers? _fields;
  List<GlobalKey> _places = const [];
  _View _view = _View.loading;
  String? _problem;
  bool _saving = false;

  /// Asked without a key while signed out: signing in is the way in.
  bool _needsSignIn = false;

  MissingAnswersApi get _api => ref.read(missingAnswersApiProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dropFields();
    super.dispose();
  }

  void _dropFields() {
    _fields
      ?..removeListener(_answersChanged)
      ..dispose();
    _fields = null;
  }

  void _answersChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final signedIn = ref.read(isAuthenticatedProvider);
    if (widget.eventId <= 0 || widget.personRef.trim().isEmpty) {
      setState(() => _view = _View.invalid);
      return;
    }
    if (widget.linkKey.isEmpty && !signedIn) {
      setState(() {
        _view = _View.invalid;
        _needsSignIn = true;
      });
      return;
    }
    setState(() {
      _view = _View.loading;
      _needsSignIn = false;
      _problem = null;
    });
    try {
      final form = await _api.fetch(widget.eventId, widget.personRef,
          key: widget.linkKey);
      if (!mounted) return;
      _show(form);
    } catch (e) {
      if (!mounted) return;
      final status = statusCodeOf(e);
      setState(() {
        if (status == 404 || status == 403) {
          _view = _View.invalid;
        } else if (status == 401 && widget.linkKey.isEmpty) {
          // The session ended: sign in again.
          _view = _View.invalid;
          _needsSignIn = true;
        } else {
          _view = _View.failed;
          _problem = readableError(e,
              fallback: "We couldn't load your details. Try again.");
        }
      });
    }
  }

  /// [form] on screen: the questions asked, filled in, or what stands
  /// instead of them.
  void _show(AnswersForm form) {
    _dropFields();
    final view = switch (form.status) {
      AnswersStatus.closed => _View.closed,
      AnswersStatus.nothing => _View.nothing,
      AnswersStatus.done => _View.done,
      AnswersStatus.open ||
      AnswersStatus.unknown =>
        form.asked.isEmpty ? _View.done : _View.form,
    };
    if (view == _View.form) {
      final editable = form.editable;
      final fields = QuestionAnswers()
        ..setQuestions(form.questions, only: editable)
        // What they answered to the questions not asked decides what the
        // asked ones show; only the asked ones, and what follows from them,
        // can be changed here.
        ..given = {
          for (final entry in form.answers.entries)
            if (!editable.contains(entry.key)) entry.key: entry.value,
        }
        ..prefill(form.answers, only: editable);
      fields.addListener(_answersChanged);
      _fields = fields;
      _places = [for (final _ in form.questions) GlobalKey()];
    }
    setState(() {
      _form = form;
      // Asked for, but none of it shown for their answers: nothing to add.
      _view = view == _View.form && _shown.isEmpty ? _View.done : view;
    });
  }

  /// The questions on screen, in the form's order: those asked, and the
  /// follow-ups their answers bring.
  List<AdditionalDetail> get _shown {
    final form = _form;
    final fields = _fields;
    if (form == null || fields == null) return const [];
    final editable = form.editable;
    final shown = fields.shownKeys;
    return [
      for (final q in form.questions)
        if (editable.contains(q.key) && shown.contains(q.key)) q,
    ];
  }

  Future<void> _save() async {
    final form = _form;
    final fields = _fields;
    if (form == null || fields == null || _saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final onScreen = {for (final q in _shown) q.key};
    final answers = {
      for (final entry in fields.collect().entries)
        if (onScreen.contains(entry.key)) entry.key: entry.value,
    };
    if (answers.isEmpty) {
      _say('Add at least one of the details.');
      return;
    }
    setState(() {
      _saving = true;
      fields.errors.clear();
    });
    try {
      final saved = await _api.submit(widget.eventId, widget.personRef, answers,
          key: widget.linkKey);
      if (!mounted) return;
      _answered();
      setState(() {
        _form = saved;
        _view = _View.thanks;
      });
    } catch (e) {
      if (!mounted) return;
      _refused(e, onScreen);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The details are in: what showed "details needed" reads itself again.
  void _answered() {
    ref.invalidate(ticketDetailsProvider);
    if (ref.read(isAuthenticatedProvider) &&
        ref.read(myRegistrationRequestsProvider).loaded) {
      unawaited(ref.read(myRegistrationRequestsProvider.notifier).refresh());
    }
  }

  void _refused(Object error, Set<String> onScreen) {
    final status = statusCodeOf(error);
    if (status == 409 &&
        (errorCodeOf(error) == null ||
            errorCodeOf(error) == AnswersErrorCodes.closed)) {
      setState(() => _view = _View.closed);
      return;
    }
    if (status == 404) {
      setState(() => _view = _View.invalid);
      return;
    }
    final refused = _fieldErrors(error, onScreen);
    if (refused != null) {
      _fields?.showErrors(refused);
      final form = _form;
      final first =
          form?.questions.indexWhere((q) => refused.containsKey(q.key)) ?? -1;
      if (first >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final place = _places[first].currentContext;
          if (place == null || !place.mounted) return;
          Scrollable.ensureVisible(place,
              alignment: 0.1, duration: const Duration(milliseconds: 250));
        });
      }
      _say(serverMessageOf(error) ?? 'Check your answers.');
      return;
    }
    _say(readableError(error, fallback: "That didn't save. Try again."));
  }

  /// What the server said is wrong with each answer on screen (422
  /// `errors`, as registration says it), or null.
  Map<String, String>? _fieldErrors(Object error, Set<String> onScreen) {
    final status = statusCodeOf(error);
    if (status != 422 && status != 400) return null;
    final api = apiExceptionOf(error);
    final errors = api?.fieldErrors ?? api?.errors;
    if (errors == null) return null;
    final found = <String, String>{
      for (final entry in errors.entries)
        if (onScreen.contains(entry.key))
          if (jsonString(entry.value)?.trim() case final said?
              when said.isNotEmpty)
            entry.key: said,
    };
    return found.isEmpty ? null : found;
  }

  void _say(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    // Signed in from here (a link without its key): read it again.
    ref.listen<bool>(isAuthenticatedProvider, (was, now) {
      if (now && was != true && _needsSignIn) _load();
    });
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Your details',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
      ),
      body: SafeArea(top: false, child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final form = _form;
    switch (_view) {
      case _View.loading:
        return const Center(child: CircularProgressIndicator());
      case _View.invalid:
        return _Message(
          key: AnswersPage.invalidKey,
          icon: Icons.link_off,
          title: _needsSignIn ? 'Sign in to add your details' : null,
          text: _needsSignIn
              ? 'Open the link from your email, or sign in with the account '
                  'you registered with.'
              : AnswersPage.invalidLink,
          action: _needsSignIn
              ? FilledButton(
                  key: AnswersPage.signInKey,
                  onPressed: () => ensureSignedInFor(context, ref,
                      reason: 'Sign in to add your details.'),
                  style: _filled,
                  child: const Text('Sign in'),
                )
              : null,
        );
      case _View.failed:
        return _Message(
          icon: Icons.cloud_off,
          text: _problem ?? "We couldn't load your details. Try again.",
          action: OutlinedButton(
            key: AnswersPage.retryKey,
            onPressed: _load,
            child: const Text('Try again'),
          ),
        );
      case _View.form:
        return _formView(context, form!);
      case _View.thanks:
        return _thanks(context, form!);
      case _View.done:
        return _ending(
          context,
          form,
          key: AnswersPage.doneKey,
          icon: Icons.check_circle,
          color: const Color(0xFF15803D),
          title: "You're all set",
          text: '${form?.clubName ?? 'The club'} has everything it needs '
              'from you.',
        );
      case _View.closed:
        return _ending(
          context,
          form,
          key: AnswersPage.closedKey,
          icon: Icons.event_busy,
          color: const Color(0xFF6B7280),
          title: 'This has closed',
          text: "These details can't be added any more: the time to add "
              'them has passed, or the event has ended.',
        );
      case _View.nothing:
        return _ending(
          context,
          form,
          key: AnswersPage.nothingKey,
          icon: Icons.info_outline,
          color: const Color(0xFF6B7280),
          title: 'Nothing to add',
          text: 'This registration is no longer active, so there is nothing '
              'to add to it.',
          ticket: false,
        );
    }
  }

  static final _filled = FilledButton.styleFrom(
    backgroundColor: const Color(0xFF2C333D),
    minimumSize: const Size.fromHeight(48),
  );

  /// "View ticket" for a ticket holder, "View request" for a registration
  /// under review -- each on the app's own screen -- else the event.
  Widget? _onward(BuildContext context, AnswersForm? form,
      {bool ticket = true}) {
    if (form == null) return null;
    final url = ticket ? form.ticketUrl : null;
    if (url != null) {
      return FilledButton(
        key: AnswersPage.viewTicketKey,
        onPressed: () => openSiteLink(context, url),
        style: _filled,
        child: const Text('View ticket'),
      );
    }
    final request = ticket ? form.requestUrl : null;
    if (request != null) {
      return FilledButton(
        key: AnswersPage.viewRequestKey,
        onPressed: () => openSiteLink(context, request),
        style: _filled,
        child: const Text('View request'),
      );
    }
    if (form.event.id <= 0 && form.event.slug.isEmpty) return null;
    return OutlinedButton(
      onPressed: () => context.push(form.event.route),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: const Text('View event'),
    );
  }

  Widget _ending(
    BuildContext context,
    AnswersForm? form, {
    required Key key,
    required IconData icon,
    required Color color,
    required String title,
    required String text,
    bool ticket = true,
  }) {
    return ListView(
      key: key,
      padding: const EdgeInsets.all(16),
      children: [
        if (form != null) _EventHeader(event: form.event),
        const SizedBox(height: 32),
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 12),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563))),
        const SizedBox(height: 24),
        if (_onward(context, form, ticket: ticket) case final onward?) onward,
      ],
    );
  }

  Widget _thanks(BuildContext context, AnswersForm form) {
    // Still something asked: the server took these, and wants more.
    final more = form.status == AnswersStatus.open ? form.asked.length : 0;
    return ListView(
      key: AnswersPage.thanksKey,
      padding: const EdgeInsets.all(16),
      children: [
        _EventHeader(event: form.event),
        const SizedBox(height: 32),
        const Icon(Icons.check_circle, size: 56, color: Color(0xFF15803D)),
        const SizedBox(height: 12),
        const Text(AnswersPage.thanksTitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('${form.clubName} has your details.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563))),
        if (more > 0) ...[
          const SizedBox(height: 16),
          Text(
            more == 1
                ? 'There is 1 more detail to add.'
                : 'There are $more more details to add.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: AnswersPage.moreKey,
            onPressed: () => _show(form),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            child: const Text('Add the rest'),
          ),
        ],
        const SizedBox(height: 24),
        if (_onward(context, form) case final onward?) onward,
      ],
    );
  }

  Widget _formView(BuildContext context, AnswersForm form) {
    final fields = _fields!;
    final shown = _shown.map((q) => q.key).toSet();
    final asked = form.asked.toSet();
    final count = form.asked.length;
    final needs = count == 1 ? '1 more detail' : '$count more details';
    final name = form.firstName;
    final deadline = form.deadline;
    // Every field built, as the registration form's are: a form validates
    // only the fields it has built, and a list builds only what is on screen.
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        key: AnswersPage.formKey,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventHeader(event: form.event),
            const SizedBox(height: 20),
            Text(
              name == null
                  ? '${form.clubName} needs $needs'
                  : 'Hi $name, ${form.clubMidSentence} needs $needs',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (form.message case final message?) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(message,
                    style: const TextStyle(
                        fontSize: 14, height: 1.4, color: Color(0xFF374151))),
              ),
            ],
            if (deadline != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 16, color: Color(0xFFB45309)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Add ${count == 1 ? 'it' : 'them'} by '
                      '${answersMoment(deadline)}',
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFB45309)),
                    ),
                  ),
                ],
              ),
            ],
            for (final (i, detail) in form.questions.indexed)
              if (shown.contains(detail.key))
                Padding(
                  key: _places[i],
                  padding: const EdgeInsets.only(top: 24),
                  // A follow-up an answer here brought grows open; the
                  // questions asked are simply there.
                  child: asked.contains(detail.key)
                      ? QuestionField(detail: detail, answers: fields)
                      : RevealedQuestion(
                          child:
                              QuestionField(detail: detail, answers: fields)),
                ),
            const SizedBox(height: 28),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                key: AnswersPage.saveKey,
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C333D),
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Save my details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontFamily: 'BebasNeue',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The event the details are for: its poster, name, when, and who runs it.
class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.event});

  final AnswersEvent event;

  @override
  Widget build(BuildContext context) {
    final starts = event.startsAt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EventPosterImage(
          poster: event.poster,
          eventId: event.id,
          startsAt: starts,
          slot: PosterSlot.thumb,
          width: 64,
          height: 80,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.name.isEmpty ? 'Your event' : event.name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (starts != null)
                Text(answersMoment(starts),
                    style: const TextStyle(
                        fontSize: 13.5, color: Color(0xFF4B5563))),
              if (event.orgName.isNotEmpty)
                Text(event.orgName,
                    style: const TextStyle(
                        fontSize: 13.5, color: Color(0xFF4B5563))),
            ],
          ),
        ),
      ],
    );
  }
}

/// A screen of one message, with what to do about it.
class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.icon,
    required this.text,
    this.title,
    this.action,
  });

  final IconData icon;
  final String? title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(icon, size: 56, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            if (title != null) ...[
              Text(title!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
            ],
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
