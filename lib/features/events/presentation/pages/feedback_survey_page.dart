import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/events/data/datasources/feedback_survey_datasource.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';

/// The organisers' survey after an event, answered here: stars, a 0-10
/// "would you recommend", and words. The same survey as the website's
/// `/feedback/{eventId}/{registrationId}?k=…`, from the same link.
class FeedbackSurveyPage extends ConsumerStatefulWidget {
  final int eventId;
  final String registrationId;

  /// The link's key (`?k=`): the proof that this is the guest's own survey.
  final String surveyKey;

  const FeedbackSurveyPage({
    super.key,
    required this.eventId,
    required this.registrationId,
    required this.surveyKey,
  });

  @override
  ConsumerState<FeedbackSurveyPage> createState() => _FeedbackSurveyPageState();
}

class _FeedbackSurveyPageState extends ConsumerState<FeedbackSurveyPage> {
  FeedbackSurvey? _survey;
  String? _error;
  bool _loading = true;
  bool _sending = false;
  bool _done = false;
  final Map<String, Object> _answers = {};
  final Map<String, TextEditingController> _texts = {};

  FeedbackSurveyDataSource get _source =>
      ref.read(feedbackSurveyDataSourceProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _texts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.surveyKey.isEmpty || widget.eventId <= 0) {
      setState(() {
        _loading = false;
        _error = "This link doesn't work. Open the one from your email.";
      });
      return;
    }
    try {
      final survey = await _source.fetch(
          widget.eventId, widget.registrationId, widget.surveyKey);
      if (!mounted) return;
      setState(() {
        _survey = survey;
        _done = survey.submitted;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = statusCodeOf(e) == 404
            ? "This link doesn't work. Open the one from your email."
            : readableError(e,
                fallback: "We couldn't load the survey. Try again.");
      });
    }
  }

  Future<void> _send() async {
    final answers = <String, Object>{
      ..._answers,
      for (final e in _texts.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    if (answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer at least one question.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await _source.submit(
          widget.eventId, widget.registrationId, widget.surveyKey, answers);
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(readableError(e, fallback: "That didn't send. Try again.")),
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('Feedback',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final survey = _survey;
    if (survey == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 56, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 16),
              Text(_error ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_done) {
      final name = survey.firstName.isEmpty ? '' : ', ${survey.firstName}';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_outline,
                  size: 56, color: Color(0xFF1F8F6B)),
              const SizedBox(height: 16),
              Text('Thank you$name.',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '${survey.clubName.isEmpty ? 'The organisers' : survey.clubName} read every reply.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF4B5563)),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('How was ${survey.eventName}?',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Two minutes, ${survey.firstName.isEmpty ? 'friend' : survey.firstName}. '
          'It shapes the next one.',
          style: const TextStyle(color: Color(0xFF4B5563)),
        ),
        const SizedBox(height: 20),
        for (final q in survey.questions) ...[
          Text(q.label,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _answer(q),
          const SizedBox(height: 22),
        ],
        FilledButton(
          onPressed: _sending ? null : _send,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1F8F6B),
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(_sending ? 'Sending…' : 'Send'),
        ),
      ],
    );
  }

  Widget _answer(SurveyQuestion q) {
    switch (q.kind) {
      case SurveyKind.rating:
        final picked = _answers[q.key] as int? ?? 0;
        return Row(
          children: [
            for (var n = 1; n <= 5; n++)
              IconButton(
                key: ValueKey('survey-${q.key}-$n'),
                tooltip: '$n of 5',
                onPressed: () => setState(() => _answers[q.key] = n),
                icon: Icon(
                  n <= picked ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 34,
                  color: n <= picked
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF9CA3AF),
                ),
              ),
          ],
        );
      case SurveyKind.nps:
        final picked = _answers[q.key] as int?;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var n = 0; n <= 10; n++)
                  ChoiceChip(
                    key: ValueKey('survey-${q.key}-$n'),
                    label: Text('$n'),
                    selected: picked == n,
                    onSelected: (_) => setState(() => _answers[q.key] = n),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Not likely',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                Text('Very likely',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        );
      case SurveyKind.text:
        return TextField(
          key: ValueKey('survey-${q.key}'),
          controller: _texts.putIfAbsent(q.key, TextEditingController.new),
          maxLines: 4,
          minLines: 2,
          maxLength: 1000,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
    }
  }
}
