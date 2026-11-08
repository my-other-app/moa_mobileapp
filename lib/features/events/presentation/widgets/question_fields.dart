import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/features/events/domain/question_visibility.dart';
import 'package:finnet/features/events/presentation/utils/question_answers.dart';

// An event's own questions on a form: the registration form, the "missing
// answers" screen a club's ask links to, and the door's "add the missing
// details". One set of fields, so a question looks, validates and sends the
// same wherever it is answered.

/// What has been typed, picked and chosen for an event's questions, with
/// what the server said is wrong with each. Its listeners hear every change
/// a field makes, so the form around them can rebuild: an answer can show
/// or hide later questions (conditional-questions-contract.md §3).
class QuestionAnswers extends ChangeNotifier {
  List<AdditionalDetail> _questions = const [];

  /// The form's questions, in order.
  List<AdditionalDetail> get questions => _questions;

  /// Answers the form shows nothing of but which decide what it shows: a
  /// person's earlier answer to a parent question, say, when only its
  /// follow-up is asked. Read for visibility only; never sent.
  Map<String, Object?> given = const {};

  /// What is typed, and what a picked date or time shows.
  final Map<String, TextEditingController> texts = {};

  /// What is chosen (a dropdown, radio buttons, tick boxes).
  final Map<String, String?> choices = {};

  /// Date and time answers, as sent ("2026-10-18", "09:05",
  /// "2026-10-18T09:05"); their [texts] hold what is shown.
  final Map<String, String> picked = {};
  final Map<String, DateTime> moments = {};

  /// What the server said is wrong with each answer, by question key,
  /// shown under its question until that answer changes.
  final Map<String, String> errors = {};

  /// [questions] become the form's, with a text box for every question that
  /// is typed into or picked -- only for the keys in [only], when given.
  void setQuestions(List<AdditionalDetail> questions, {Set<String>? only}) {
    _questions = questions;
    for (final detail in questions) {
      if (only != null && !only.contains(detail.key)) continue;
      final control = questionControlOf(detail.fieldType);
      if (control == QuestionControl.text || isPickerControl(control)) {
        texts.putIfAbsent(detail.key, TextEditingController.new);
      }
    }
  }

  /// Every answer so far, by question key, as it would be sent -- a picked
  /// date or time as picked, a choice as chosen, typed text as typed -- over
  /// [given].
  Map<String, Object?> get values => {
        ...given,
        for (final entry in texts.entries)
          if (!moments.containsKey(entry.key)) entry.key: entry.value.text,
        ...picked,
        ...choices,
      };

  /// The keys of the questions shown for the answers so far.
  Set<String> get shownKeys => visibleQuestionKeys(_questions, values);

  /// The questions shown for the answers so far, in order.
  List<AdditionalDetail> get shown => visibleQuestions(_questions, values);

  /// The answers given, blanks left out and none to a question the answers
  /// hide: what is sent. Never [given].
  Map<String, String> collect() {
    final answers = <String, String>{};
    // A picked date or time is sent as picked, not as the words shown in
    // its field.
    texts.forEach((key, controller) {
      if (moments.containsKey(key)) return;
      if (controller.text.isNotEmpty) answers[key] = controller.text;
    });
    picked.forEach((key, value) {
      if (value.isNotEmpty) answers[key] = value;
    });
    choices.forEach((key, value) {
      if (value != null && value.isNotEmpty) answers[key] = value;
    });
    // Never an answer to a question that doesn't apply: they are cleared as
    // they hide, and this makes sure of it.
    final shown = shownKeys;
    final known = {for (final q in _questions) q.key};
    return {
      for (final entry in answers.entries)
        if (shown.contains(entry.key) || !known.contains(entry.key))
          entry.key: entry.value,
    };
  }

  /// [value] chosen for [detail] (a dropdown, radio buttons or tick boxes).
  /// A choice can show or hide later questions: one that no longer applies
  /// loses its answer at once, so what is on screen is what is sent. What a
  /// screen reader should hear of what came and went, or null.
  String? choose(AdditionalDetail detail, String? value) {
    final before = shown;
    choices[detail.key] = value;
    errors.remove(detail.key);
    forgetHidden();
    notifyListeners();
    return visibilityChangeAnnouncement(before, shown);
  }

  /// Clears the answer to every question the answers now hide -- and so to
  /// its own follow-ups, which are hidden with it.
  void forgetHidden() {
    final shown = shownKeys;
    for (final detail in _questions) {
      if (shown.contains(detail.key)) continue;
      texts[detail.key]?.clear();
      picked.remove(detail.key);
      moments.remove(detail.key);
      choices.remove(detail.key);
      errors.remove(detail.key);
    }
  }

  /// The answer to [key] was typed into: what the server said about the old
  /// one no longer applies.
  void typed(String key) {
    if (errors.remove(key) != null) notifyListeners();
  }

  /// [moment] picked for [detail], answered as [control] asks.
  void pick(AdditionalDetail detail, QuestionControl control, DateTime moment) {
    final (answer, label) = switch (control) {
      QuestionControl.date => (dateAnswer(moment), dateLabel(moment)),
      QuestionControl.time => (
          timeAnswer(moment.hour, moment.minute),
          timeLabel(moment.hour, moment.minute),
        ),
      _ => (dateTimeAnswer(moment), dateTimeLabel(moment)),
    };
    moments[detail.key] = moment;
    picked[detail.key] = answer;
    texts[detail.key]?.text = label;
    errors.remove(detail.key);
    notifyListeners();
  }

  /// Each refused answer's reason, under its question; any earlier ones go.
  void showErrors(Map<String, String> refused) {
    errors
      ..clear()
      ..addAll(refused);
    notifyListeners();
  }

  /// [stored] answers put in the fields, for the questions in [only] (all,
  /// when not given): typed text as it was, a date or time picked again from
  /// what was sent, a choice only when it is still one of the options -- a
  /// choice the club has since removed is left for the person to choose
  /// again, as an answer that no longer counts.
  void prefill(Map<String, Object?> stored, {Set<String>? only}) {
    for (final detail in _questions) {
      if (only != null && !only.contains(detail.key)) continue;
      final value = stored[detail.key];
      if (value == null) continue;
      final control = questionControlOf(detail.fieldType);
      switch (control) {
        case QuestionControl.text:
          final text = value is List ? value.join(', ') : '$value';
          if (text.trim().isNotEmpty) texts[detail.key]?.text = text;
        case QuestionControl.date:
        case QuestionControl.time:
        case QuestionControl.dateTime:
          final moment = _momentOf(control, '$value');
          if (moment != null) {
            final (answer, label) = switch (control) {
              QuestionControl.date => (dateAnswer(moment), dateLabel(moment)),
              QuestionControl.time => (
                  timeAnswer(moment.hour, moment.minute),
                  timeLabel(moment.hour, moment.minute),
                ),
              _ => (dateTimeAnswer(moment), dateTimeLabel(moment)),
            };
            moments[detail.key] = moment;
            picked[detail.key] = answer;
            texts[detail.key]?.text = label;
          }
        case QuestionControl.select:
        case QuestionControl.radio:
        case QuestionControl.checkbox:
          final allowed = control == QuestionControl.checkbox
              ? checkboxValues(detail.options)
              : detail.options;
          final picks = value is List ? value : [value];
          for (final pick in picks) {
            if (pick != null && allowed.contains('$pick')) {
              choices[detail.key] = '$pick';
              break;
            }
          }
      }
    }
  }

  static DateTime? _momentOf(QuestionControl control, String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    if (control == QuestionControl.time) {
      final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
      if (match == null) return null;
      final hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      if (hour > 23 || minute > 59) return null;
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    return DateTime(
        parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute);
  }

  @override
  void dispose() {
    for (final controller in texts.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

/// A question's label -- with a red " *" when it must be answered -- the
/// field under it, and what is wrong with the answer under that.
class QuestionFrame extends StatelessWidget {
  const QuestionFrame({
    super.key,
    required this.label,
    required this.child,
    this.errorText,
    this.isRequired = false,
  });

  final String label;
  final Widget child;
  final String? errorText;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wraps rather than running off the side: a long question at a
          // large text size used to overflow the row.
          Text.rich(
            TextSpan(
              text: label,
              children: [
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: Color(0xFFCC0000)),
                  ),
              ],
            ),
            semanticsLabel: isRequired ? '$label, required' : label,
            style: const TextStyle(
              color: Color(0xFF2C333D),
              fontSize: 12,
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          child,
          if (errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              errorText!,
              style: const TextStyle(
                color: Color(0xFFCC0000),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One of an event's questions, answered as its type asks: typed, picked,
/// or chosen, into [answers]. Validated as the website validates it: a
/// required question shown must be answered, and an email, a web address, a
/// phone number or a number must be one.
class QuestionField extends StatelessWidget {
  const QuestionField({super.key, required this.detail, required this.answers});

  final AdditionalDetail detail;
  final QuestionAnswers answers;

  /// Field types that are entered as free text, and the keyboard each wants.
  ///
  /// The server declares twelve types (app/api/events/schemas.py FieldTypes);
  /// the form once handled two of them and drew nothing for the rest. An
  /// invisible field cannot be filled in, is therefore omitted from the
  /// submission, and the server rejects the registration as missing a
  /// required field -- so an event using any other type could not be
  /// registered for at all, with nothing on screen to explain why.
  ///
  /// Dates and times are picked, not typed (see [questionControlOf]): typed
  /// in, they arrived in whatever shape each person chose.
  static const _textKeyboards = <String, TextInputType>{
    'text': TextInputType.text,
    'textarea': TextInputType.multiline,
    'email': TextInputType.emailAddress,
    'url': TextInputType.url,
    'tel': TextInputType.phone,
    'number': TextInputType.number,
  };

  static const _valueStyle = TextStyle(
    color: Color(0xFF1E1E1E),
    fontSize: 16,
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w500,
  );

  static const _hintStyle = TextStyle(
    color: Color(0xFFB4B4B4),
    fontSize: 16,
    fontFamily: 'DMSans',
    fontWeight: FontWeight.w500,
  );

  static OutlineInputBorder _border(Color color, double width) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final control = questionControlOf(detail.fieldType);
    if (isPickerControl(control)) return _picker(context, control);
    switch (control) {
      case QuestionControl.checkbox:
        return _choice(context, checkbox: true);
      case QuestionControl.radio:
        return _choice(context, checkbox: false);
      case QuestionControl.select:
        return _select(context);
      default:
        return _text();
    }
  }

  /// [value] chosen: hidden follow-ups lose their answers, and a screen
  /// reader hears what came and went. Focus stays where it is.
  void _choose(BuildContext context, String? value) {
    final message = answers.choose(detail, value);
    if (message != null && context.mounted) {
      SemanticsService.sendAnnouncement(
          View.of(context), message, Directionality.of(context));
    }
  }

  /// A date, a time, or both, from the platform pickers.
  Future<void> _pick(BuildContext context, QuestionControl control) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final current = answers.moments[detail.key];

    DateTime? day;
    if (control != QuestionControl.time) {
      day = await showDatePicker(
        context: context,
        initialDate: current ?? now,
        firstDate: DateTime(1900),
        lastDate: DateTime(now.year + 20, 12, 31),
      );
      if (day == null || !context.mounted) return;
    }
    TimeOfDay? time;
    if (control != QuestionControl.date) {
      time = await showTimePicker(
        context: context,
        initialTime: current != null
            ? TimeOfDay.fromDateTime(current)
            : TimeOfDay.fromDateTime(now),
      );
      if (time == null || !context.mounted) return;
    }

    answers.pick(
      detail,
      control,
      DateTime(
        day?.year ?? now.year,
        day?.month ?? now.month,
        day?.day ?? now.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      ),
    );
  }

  Widget _picker(BuildContext context, QuestionControl control) {
    final hint = switch (control) {
      QuestionControl.date => 'Pick a date',
      QuestionControl.time => 'Pick a time',
      _ => 'Pick a date and time',
    };
    return QuestionFrame(
      label: detail.label,
      isRequired: detail.requiredIfShown,
      errorText: answers.errors[detail.key],
      child: TextFormField(
        controller: answers.texts[detail.key],
        readOnly: true,
        onTap: () => _pick(context, control),
        style: _valueStyle,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: _valueStyle.copyWith(color: const Color(0xFFB4B4B4)),
          suffixIcon: Icon(
            control == QuestionControl.time
                ? Icons.access_time
                : Icons.calendar_today_outlined,
            size: 18,
            color: const Color(0xFF2C333D),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: _border(const Color(0xFF2C333D), 0.5),
          enabledBorder: _border(const Color(0xFF2C333D), 0.5),
          focusedBorder: _border(const Color(0xFF2C333D), 1),
          errorBorder: _border(const Color(0xFFCC0000), 0.5),
        ),
        validator: (_) {
          final picked = answers.picked[detail.key];
          if (detail.requiredIfShown && (picked == null || picked.isEmpty)) {
            return 'Please pick ${detail.label.toLowerCase()}';
          }
          return null;
        },
      ),
    );
  }

  /// Radio buttons, or tick boxes for a checkbox question. One answer per
  /// question, one of the options, so ticking a box unticks the others; one
  /// box alone is an "I agree". (The server now takes a list for a checkbox
  /// too; one string is what every server version accepts.)
  Widget _choice(BuildContext context, {required bool checkbox}) {
    final values = checkbox ? checkboxValues(detail.options) : detail.options;
    final single = checkbox && values.length == 1;
    return FormField<String>(
      validator: (_) {
        final picked = answers.choices[detail.key];
        if (detail.requiredIfShown && (picked == null || picked.isEmpty)) {
          return single
              ? 'Please tick this box'
              : 'Please choose ${detail.label.toLowerCase()}';
        }
        return null;
      },
      builder: (field) {
        final selected = answers.choices[detail.key];
        void choose(String? value) {
          _choose(context, value);
          field.didChange(value);
        }

        final Widget options;
        if (checkbox) {
          options = Column(
            children: [
              for (final option in values)
                CheckboxListTile(
                  value: selected == option,
                  onChanged: (ticked) => choose(ticked == true ? option : null),
                  title: Text(option, style: _valueStyle),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: const Color(0xFF2C333D),
                ),
            ],
          );
        } else {
          options = RadioGroup<String>(
            groupValue: selected,
            onChanged: choose,
            child: Column(
              children: [
                for (final option in values)
                  RadioListTile<String>(
                    value: option,
                    title: Text(option, style: _valueStyle),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: const Color(0xFF2C333D),
                  ),
              ],
            ),
          );
        }
        return QuestionFrame(
          label: detail.label,
          isRequired: detail.requiredIfShown,
          errorText: field.errorText ?? answers.errors[detail.key],
          child: options,
        );
      },
    );
  }

  Widget _text() {
    return QuestionFrame(
      label: detail.label,
      isRequired: detail.requiredIfShown,
      errorText: answers.errors[detail.key],
      child: TextFormField(
        controller: answers.texts[detail.key],
        onChanged: (_) => answers.typed(detail.key),
        keyboardType: _textKeyboards[detail.fieldType] ?? TextInputType.text,
        // A textarea is for prose, so it gets room for it; everything else
        // stays a single line.
        maxLines: detail.fieldType == 'textarea' ? 4 : 1,
        minLines: detail.fieldType == 'textarea' ? 3 : 1,
        style: _valueStyle,
        decoration: InputDecoration(
          hintText: 'Enter ${detail.label.toLowerCase()}',
          hintStyle: _hintStyle,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: _border(const Color(0xFF2C333D), 0.5),
          enabledBorder: _border(const Color(0xFF2C333D), 0.5),
          focusedBorder: _border(const Color(0xFF2C333D), 1),
          errorBorder: _border(const Color(0xFFCC0000), 0.5),
        ),
        validator: (value) {
          if (detail.requiredIfShown &&
              (value == null || value.trim().isEmpty)) {
            return 'Please enter ${detail.label.toLowerCase()}';
          }
          // An email, a web address, a phone number or a number that
          // isn't one: said here, as the website does, not after sending.
          return typedAnswerProblem(detail.fieldType, value ?? '');
        },
      ),
    );
  }

  Widget _select(BuildContext context) {
    return QuestionFrame(
      label: detail.label,
      isRequired: detail.requiredIfShown,
      errorText: answers.errors[detail.key],
      child: DropdownButtonFormField2<String>(
        value: answers.choices[detail.key],
        isExpanded: true,
        buttonStyleData: const ButtonStyleData(
          height: 44,
          padding: EdgeInsets.zero,
        ),
        iconStyleData: const IconStyleData(
          icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF2C333D)),
        ),
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2C333D).withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          offset: const Offset(0, -4),
          scrollbarTheme: ScrollbarThemeData(
            radius: const Radius.circular(40),
            thickness: WidgetStateProperty.all(6),
            thumbVisibility: WidgetStateProperty.all(true),
          ),
        ),
        menuItemStyleData: const MenuItemStyleData(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 16),
        ),
        style: _valueStyle,
        decoration: InputDecoration(
          hintText: 'Select ${detail.label.toLowerCase()}',
          hintStyle: _hintStyle,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          border: _border(const Color(0xFF2C333D), 0.5),
          enabledBorder: _border(const Color(0xFF2C333D), 0.5),
          focusedBorder: _border(const Color(0xFF2C333D), 1),
        ),
        items: [
          for (final option in detail.options)
            DropdownMenuItem<String>(
              value: option,
              child: Container(
                constraints: const BoxConstraints(minHeight: 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: _valueStyle,
                ),
              ),
            ),
        ],
        onChanged: (value) => _choose(context, value),
        validator: (value) {
          if (detail.requiredIfShown && value == null) {
            return 'Please select ${detail.label.toLowerCase()}';
          }
          return null;
        },
      ),
    );
  }
}
