import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/app/router/tracking_ref.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/common/models/events/store_model.dart';
import 'package:finnet/core/utils/whatsapp_number.dart';
import 'package:finnet/features/clubs/domain/club_updates.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/utils/question_answers.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/events/presentation/widgets/merch_picker.dart';
import 'package:finnet/features/events/presentation/widgets/registration_feedback.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/presentation/utils/event_sign_in.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:finnet/features/payments/checkout.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';

class EventFormPage extends ConsumerStatefulWidget {
  /// The event's id; null when the form was opened by the event's slug (a
  /// link to `/events/{slug}/register`), and then read from `/events/info`.
  final int? eventId;

  /// The event's slug or id, as the address has it.
  final String? eventRef;

  /// The event's own questions, from the event page; null to read them
  /// from `/events/info` (a link straight to the form).
  final List<AdditionalDetail>? additionalDetails;

  /// Whether the event is paid, and online: an iPhone doesn't sell a paid
  /// online event (canSellInApp). Null when not known -- read from
  /// `/events/info` on an iPhone, where it matters.
  final bool? hasFee;
  final bool? isOnline;

  /// The hosting club's name, and whether it offers "Get updates from
  /// `<club>` on WhatsApp" (its `whatsapp_updates`), from the event page.
  /// When the form reads `/events/info` itself, what that says wins. Null or
  /// false: no box, and nothing extra is sent.
  final String? clubName;
  final bool? offersClubUpdates;

  const EventFormPage({
    super.key,
    this.eventId,
    this.eventRef,
    this.additionalDetails,
    this.hasFee,
    this.isOnline,
    this.clubName,
    this.offersClubUpdates,
  }) : assert(eventId != null || eventRef != null,
            'A registration form needs an event');

  @override
  ConsumerState<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends ConsumerState<EventFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Store additional field controllers and values
  final Map<String, TextEditingController> _additionalTextControllers = {};
  final Map<String, String?> _additionalSelectValues = {};

  /// Date and time answers, as sent ("2026-10-18", "09:05",
  /// "2026-10-18T09:05"); their controllers hold what is shown.
  final Map<String, String> _pickedAnswers = {};
  final Map<String, DateTime> _pickedMoments = {};

  // Organization selection
  Organization? _selectedOrganization;
  bool _isOtherOrganization = false;
  final _otherOrgController = TextEditingController();

  bool _isSubmitting = false;
  bool _hasPrefilledData = false;

  /// What the event sells with its ticket, and what this guest picked.
  StoreCatalog _catalog = StoreCatalog.empty;
  Map<String, StorePick> _picks = {};

  /// What the server said is wrong with each answer (INVALID_ANSWERS), by
  /// question key, shown under its question until that answer changes.
  final Map<String, String> _answerErrors = {};

  /// Each question's place in the scroll, in order, to bring the first
  /// refused answer into view.
  List<GlobalKey> _questionKeys = const [];

  /// The event's questions: given, or read from `/events/info`.
  List<AdditionalDetail> _questions = const [];

  int? _eventId;
  bool? _hasFee;
  bool? _isOnline;

  /// `/events/info` is being read (opened from a link), or failed.
  bool _loadingEvent = false;
  String? _loadError;

  /// "Get updates from `<club>` on WhatsApp": offered only for a club that
  /// can send them, unticked until the person ticks it.
  bool _offersClubUpdates = false;
  String _clubName = '';
  bool _clubUpdates = false;

  /// What the server said of the phone number (WHATSAPP_NUMBER), shown
  /// under it until it, or the box, changes.
  String? _phoneProblem;
  final _phoneKey = GlobalKey();

  /// "Send my ticket and event reminders on WhatsApp": unticked until the
  /// person ticks it, as on the website.
  bool _whatsapp = false;

  /// Whether `whatsapp_opt_in: true` goes with the registration.
  bool get _wantsWhatsapp =>
      _whatsapp && _phoneController.text.trim().isNotEmpty;

  /// Whether `club_updates_whatsapp: true` goes with the registration.
  bool get _wantsClubUpdates =>
      _offersClubUpdates &&
      _clubUpdates &&
      _phoneController.text.trim().isNotEmpty;

  bool get _onIos => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether this phone sells a place at the event (canSellInApp).
  bool get _sellable =>
      canSellInApp(hasFee: _hasFee ?? false, isOnline: _isOnline ?? false);

  @override
  void initState() {
    super.initState();
    // An id of 0 is what an older router made of a slug: not an id.
    final given = widget.eventId;
    _eventId = given != null && given > 0
        ? given
        : eventIdOf(widget.eventRef ?? '');
    _hasFee = widget.hasFee;
    _isOnline = widget.isOnline;
    _offersClubUpdates = widget.offersClubUpdates == true;
    _clubName = widget.clubName ?? '';
    final questions = widget.additionalDetails;
    if (questions != null) _setQuestions(questions);
    final mustRead = questions == null ||
        _eventId == null ||
        (_onIos && (_hasFee == null || _isOnline == null));
    if (mustRead) {
      _loadEvent();
    } else {
      _fetchCatalog();
    }
  }

  /// A controller for every field that is typed into. Previously only
  /// 'text' got one, so a 'tel' or 'textarea' field had nowhere to put a
  /// value even once it rendered.
  void _setQuestions(List<AdditionalDetail> questions) {
    _questions = questions;
    _questionKeys = [for (final _ in questions) GlobalKey()];
    for (final detail in questions) {
      final control = questionControlOf(detail.fieldType);
      if (control == QuestionControl.text || isPickerControl(control)) {
        _additionalTextControllers.putIfAbsent(
            detail.key, TextEditingController.new);
      }
    }
  }

  /// The event from `/events/info/{ref}`: its id, its questions, and
  /// whether it is paid and online.
  Future<void> _loadEvent() async {
    setState(() {
      _loadingEvent = true;
      _loadError = null;
    });
    final ref = widget.eventRef?.trim().isNotEmpty == true
        ? widget.eventRef!.trim()
        : '${widget.eventId}';
    try {
      final res = await APIService.instance.request(
        '/events/info/${Uri.encodeComponent(ref)}',
        DioMethod.get,
        cache: CachePolicy.personal,
      );
      final data = res.data;
      final info =
          EventInfo.fromJson(data is Map<String, dynamic> ? data : const {});
      if (!mounted) return;
      setState(() {
        if (info.id > 0) _eventId = info.id;
        _hasFee ??= info.hasFee;
        _isOnline ??= info.isOnline;
        // The form's own read of the event is the fresher word on the club.
        if (info.club.id > 0) {
          _offersClubUpdates = info.club.whatsappUpdates;
          if (info.club.name.trim().isNotEmpty) _clubName = info.club.name;
        }
        if (widget.additionalDetails == null) {
          _setQuestions(info.additionalDetails);
        }
        _loadingEvent = false;
      });
      _fetchCatalog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingEvent = false;
        _loadError =
            readableError(e, fallback: "We couldn't load this event's form.");
      });
    }
  }

  /// The shelf is public and optional: an event that sells nothing, or a
  /// failed call, simply shows no shelf.
  Future<void> _fetchCatalog() async {
    final id = _eventId;
    if (id == null) return;
    try {
      final res = await APIService.instance.request('/events/$id/store/catalog', DioMethod.get, skipAuth: true);
      final data = res.data;
      if (data is Map<String, dynamic> && mounted) {
        setState(() => _catalog = StoreCatalog.fromJson(data));
      }
    } catch (_) {
      // Nothing to pick; the form itself is unaffected.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otherOrgController.dispose();
    for (final controller in _additionalTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The answer to [key] changed: what the server said about the old one no
  /// longer applies.
  void _answerChanged(String key) {
    if (_answerErrors.containsKey(key)) {
      setState(() => _answerErrors.remove(key));
    }
  }

  /// Pre-fill form data from user profile.
  ///
  /// The profile now arrives asynchronously, which it did not before -- the
  /// provider loads on first read rather than waiting for a screen to ask.
  /// So this can run after the user has already started typing, and must
  /// never overwrite what they put there: each field is filled only if it is
  /// still empty.
  void _prefillFromProfile(UserProfile profile) {
    if (_hasPrefilledData) return;
    _hasPrefilledData = true;

    void fill(TextEditingController controller, String? value) {
      if (value == null || value.isEmpty) return;
      if (controller.text.isNotEmpty) return;
      controller.text = value;
    }

    fill(_nameController, profile.fullName);
    fill(_emailController, profile.email);
    fill(
      _phoneController,
      (profile.phone != null && profile.phone!.isNotEmpty)
          ? profile.phone
          : profile.whatsapp,
    );

    if (profile.organization != null) {
      _selectedOrganization = profile.organization;
    }
  }

  Widget _buildInputField({
    Key? key,
    required String label,
    required Widget child,
    String? errorText,
    bool isRequired = false,
  }) {
    return SizedBox(
      key: key,
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  overflow: TextOverflow.ellipsis,
                  color: Color(0xFF2C333D),
                  fontSize: 12,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: Color(0xFFCC0000),
                    fontSize: 12,
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          child,
          if (errorText != null) ...[
            const SizedBox(height: 4),
            Text(
              errorText,
              style: TextStyle(
                color: Color(0xFFCC0000),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Field types that are entered as free text, and the keyboard each wants.
  ///
  /// The server declares twelve types (app/api/events/schemas.py FieldTypes);
  /// this screen handled two of them and returned SizedBox.shrink() for the
  /// rest. An invisible field cannot be filled in, is therefore omitted from
  /// the submission, and the server rejects the registration as missing a
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

  /// A date, a time, or both, from the platform pickers.
  Future<void> _pick(AdditionalDetail detail, QuestionControl control) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final current = _pickedMoments[detail.key];

    DateTime? day;
    if (control != QuestionControl.time) {
      day = await showDatePicker(
        context: context,
        initialDate: current ?? now,
        firstDate: DateTime(1900),
        lastDate: DateTime(now.year + 20, 12, 31),
      );
      if (day == null || !mounted) return;
    }
    TimeOfDay? time;
    if (control != QuestionControl.date) {
      time = await showTimePicker(
        context: context,
        initialTime: current != null
            ? TimeOfDay.fromDateTime(current)
            : TimeOfDay.fromDateTime(now),
      );
      if (time == null || !mounted) return;
    }

    final moment = DateTime(
      day?.year ?? now.year,
      day?.month ?? now.month,
      day?.day ?? now.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    final (answer, label) = switch (control) {
      QuestionControl.date => (dateAnswer(moment), dateLabel(moment)),
      QuestionControl.time => (
          timeAnswer(moment.hour, moment.minute),
          timeLabel(moment.hour, moment.minute),
        ),
      _ => (dateTimeAnswer(moment), dateTimeLabel(moment)),
    };
    setState(() {
      _pickedMoments[detail.key] = moment;
      _pickedAnswers[detail.key] = answer;
      _additionalTextControllers[detail.key]?.text = label;
      _answerErrors.remove(detail.key);
    });
  }

  Widget _buildPickerField(AdditionalDetail detail, QuestionControl control) {
    final hint = switch (control) {
      QuestionControl.date => 'Pick a date',
      QuestionControl.time => 'Pick a time',
      _ => 'Pick a date and time',
    };
    return _buildInputField(
      label: detail.label,
      isRequired: detail.requiredField,
      errorText: _answerErrors[detail.key],
      child: TextFormField(
        controller: _additionalTextControllers[detail.key],
        readOnly: true,
        onTap: () => _pick(detail, control),
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2C333D), width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2C333D), width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF2C333D), width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCC0000), width: 0.5),
          ),
        ),
        validator: (_) {
          final picked = _pickedAnswers[detail.key];
          if (detail.requiredField && (picked == null || picked.isEmpty)) {
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
  Widget _buildChoiceField(AdditionalDetail detail,
      {required bool checkbox}) {
    final values =
        checkbox ? checkboxValues(detail.options) : detail.options;
    final single = checkbox && values.length == 1;
    return FormField<String>(
      validator: (_) {
        final picked = _additionalSelectValues[detail.key];
        if (detail.requiredField && (picked == null || picked.isEmpty)) {
          return single
              ? 'Please tick this box'
              : 'Please choose ${detail.label.toLowerCase()}';
        }
        return null;
      },
      builder: (field) {
        final selected = _additionalSelectValues[detail.key];
        void choose(String? value) {
          setState(() {
            _additionalSelectValues[detail.key] = value;
            _answerErrors.remove(detail.key);
          });
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
        return _buildInputField(
          label: detail.label,
          isRequired: detail.requiredField,
          errorText: field.errorText ?? _answerErrors[detail.key],
          child: options,
        );
      },
    );
  }

  Widget _buildAdditionalField(AdditionalDetail detail) {
    final control = questionControlOf(detail.fieldType);
    if (isPickerControl(control)) return _buildPickerField(detail, control);
    if (control == QuestionControl.checkbox) {
      return _buildChoiceField(detail, checkbox: true);
    }
    if (control == QuestionControl.radio) {
      return _buildChoiceField(detail, checkbox: false);
    }
    if (control == QuestionControl.text) {
      return _buildInputField(
        label: detail.label,
        isRequired: detail.requiredField,
        errorText: _answerErrors[detail.key],
        child: TextFormField(
          controller: _additionalTextControllers[detail.key],
          onChanged: (_) => _answerChanged(detail.key),
          keyboardType:
              _textKeyboards[detail.fieldType] ?? TextInputType.text,
          // A textarea is for prose, so it gets room for it; everything else
          // stays a single line.
          maxLines: detail.fieldType == 'textarea' ? 4 : 1,
          minLines: detail.fieldType == 'textarea' ? 3 : 1,
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 16,
            fontFamily: 'DMSans',
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Enter ${detail.label.toLowerCase()}',
            hintStyle: TextStyle(
              color: Color(0xFFB4B4B4),
              fontSize: 16,
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w500,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF2C333D), width: 1),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFCC0000), width: 0.5),
            ),
          ),
          validator: (value) {
            if (detail.requiredField &&
                (value == null || value.trim().isEmpty)) {
              return 'Please enter ${detail.label.toLowerCase()}';
            }
            // An email, a web address, a phone number or a number that
            // isn't one: said here, as the website does, not after sending.
            return typedAnswerProblem(detail.fieldType, value ?? '');
          },
        ),
      );
    } else if (control == QuestionControl.select) {
      return _buildInputField(
        label: detail.label,
        isRequired: detail.requiredField,
        errorText: _answerErrors[detail.key],
        child: DropdownButtonFormField2<String>(
          value: _additionalSelectValues[detail.key],
          isExpanded: true,
          buttonStyleData: ButtonStyleData(
            height: 44,
            padding: EdgeInsets.zero,
          ),
          iconStyleData: IconStyleData(
            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF2C333D)),
          ),
          dropdownStyleData: DropdownStyleData(
            maxHeight: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF2C333D).withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, 2),
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
          menuItemStyleData: MenuItemStyleData(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: 16),
          ),
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 16,
            fontFamily: 'DMSans',
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Select ${detail.label.toLowerCase()}',
            hintStyle: TextStyle(
              color: Color(0xFFB4B4B4),
              fontSize: 16,
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w500,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF2C333D), width: 1),
            ),
          ),
          items: detail.options.map((String option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Container(
                constraints: BoxConstraints(minHeight: 40),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  option,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontSize: 16,
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _additionalSelectValues[detail.key] = newValue;
              _answerErrors.remove(detail.key);
            });
          },
          validator: (value) {
            if (detail.requiredField && value == null) {
              return 'Please select ${detail.label.toLowerCase()}';
            }
            return null;
          },
        ),
      );
    }
    return SizedBox.shrink();
  }

  Widget _buildOrganizationField(List<Organization> organizations) {
    // Build list with "Other" option
    final orgOptions = [...organizations];

    return _buildInputField(
      label: 'Organization/College',
      isRequired: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField2<Organization?>(
            value: _isOtherOrganization ? null : _selectedOrganization,
            isExpanded: true,
            buttonStyleData: ButtonStyleData(
              height: 44,
              padding: EdgeInsets.zero,
            ),
            iconStyleData: IconStyleData(
              icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF2C333D)),
            ),
            dropdownStyleData: DropdownStyleData(
              maxHeight: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF2C333D).withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, 2),
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
            menuItemStyleData: MenuItemStyleData(
              height: 40,
              padding: EdgeInsets.symmetric(horizontal: 16),
            ),
            style: TextStyle(
              color: Color(0xFF1E1E1E),
              fontSize: 16,
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Select your organization',
              hintStyle: TextStyle(
                color: Color(0xFFB4B4B4),
                fontSize: 16,
                fontFamily: 'DMSans',
                fontWeight: FontWeight.w500,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF2C333D), width: 1),
              ),
            ),
            items: [
              ...orgOptions.map((org) {
                return DropdownMenuItem<Organization?>(
                  value: org,
                  child: Text(
                    org.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 16,
                      fontFamily: 'DMSans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }),
              // Add "Other" option
              DropdownMenuItem<Organization?>(
                value: null,
                child: Text(
                  'Other (specify below)',
                  style: TextStyle(
                    color: Color(0xFF1E1E1E),
                    fontSize: 16,
                    fontFamily: 'DMSans',
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            onChanged: (Organization? newValue) {
              setState(() {
                if (newValue == null) {
                  _isOtherOrganization = true;
                  _selectedOrganization = null;
                } else {
                  _isOtherOrganization = false;
                  _selectedOrganization = newValue;
                  _otherOrgController.clear();
                }
              });
            },
          ),
          if (_isOtherOrganization) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _otherOrgController,
              style: TextStyle(
                color: Color(0xFF1E1E1E),
                fontSize: 16,
                fontFamily: 'DMSans',
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your organization name',
                hintStyle: TextStyle(
                  color: Color(0xFFB4B4B4),
                  fontSize: 16,
                  fontFamily: 'DMSans',
                  fontWeight: FontWeight.w500,
                ),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF2C333D), width: 1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Says why the registration was refused. When it offers the ticket or
  /// the payment, the form closes with that choice for the event page to
  /// act on.
  Future<void> _showRefusal(Object error) async {
    // The club's updates were asked for with a number WhatsApp can't reach:
    // said under the phone number, as the form's own check says it.
    if (errorCodeOf(error) == whatsappNumberErrorCode) {
      setState(() => _phoneProblem = whatsappNumberProblem);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final place = _phoneKey.currentContext;
        if (place == null || !place.mounted) return;
        Scrollable.ensureVisible(place,
            alignment: 0.1, duration: const Duration(milliseconds: 250));
      });
      return;
    }
    final refused = invalidAnswersOf(
        error, _questions.map((detail) => detail.key));
    if (refused != null) {
      _showAnswerErrors(refused, serverMessageOf(error));
      return;
    }
    final action =
        await showRegistrationRefusal(context, describeRegistrationError(error));
    if (action == null || !mounted) return;
    if (context.canPop()) context.pop(action);
  }

  /// Each refused answer's reason under its question, and the first of
  /// them brought into view: the form can be long, and a dialog naming the
  /// questions sent people hunting for them.
  void _showAnswerErrors(Map<String, String> refused, String? said) {
    setState(() {
      _answerErrors
        ..clear()
        ..addAll(refused);
    });
    final first = _questions
        .indexWhere((detail) => refused.containsKey(detail.key));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final place = _questionKeys[first].currentContext;
      if (place == null || !place.mounted) return;
      Scrollable.ensureVisible(
        place,
        alignment: 0.1,
        duration: const Duration(milliseconds: 250),
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(said ?? 'Check your answers.')),
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
        _answerErrors.clear();
      });

      try {
        // Build additional details map
        Map<String, String> additionalDetailsMap = {};

        // Add text field values. A picked date or time is sent as picked,
        // not as the words shown in its field.
        _additionalTextControllers.forEach((key, controller) {
          if (_pickedMoments.containsKey(key)) return;
          if (controller.text.isNotEmpty) {
            additionalDetailsMap[key] = controller.text;
          }
        });
        _pickedAnswers.forEach((key, value) {
          if (value.isNotEmpty) additionalDetailsMap[key] = value;
        });

        // Add select field values
        _additionalSelectValues.forEach((key, value) {
          if (value != null && value.isNotEmpty) {
            additionalDetailsMap[key] = value;
          }
        });

        // Determine organization name to send
        String? organizationName;
        if (_isOtherOrganization && _otherOrgController.text.isNotEmpty) {
          organizationName = _otherOrgController.text.trim();
        } else if (_selectedOrganization != null) {
          organizationName = _selectedOrganization!.name;
        }

        final requestData = {
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'additional_details': additionalDetailsMap,
          if (organizationName != null) 'organization': organizationName,
          // Whenever the event sells merch, what is picked now -- even
          // nothing: a registration coming back to pay with its picks
          // cleared must drop the earlier order, not keep charging for it.
          if (_catalog.hasAnything) 'store': picksToPayload(_catalog, _picks),
          // Only when ticked: unticked is the server's default.
          if (_wantsClubUpdates) 'club_updates_whatsapp': true,
          // The ticket and the day-before reminder on WhatsApp too.
          if (_wantsWhatsapp) 'whatsapp_opt_in': true,
          // The club's tracking link that opened the app, if one did: the
          // server credits the sign-up to it (tracking_ref.dart).
          if (TrackingRef.instance.current case final ref?) 'ref': ref,
        };

        final response = await APIService.instance.request(
          '/events/registration/$_eventId/register',
          DioMethod.post,
          param: requestData,
        );

        if (response.statusCode == 200 && mounted) {
          // Extract ticket data from response
          final data = response.data as Map<String, dynamic>;
          // The ticket, and whatever was picked from the shelf, are paid in one checkout.
          final due = (data['pay_amount'] as num?)?.toDouble() ?? 0;
          final registrationId = data['event_registration_id'];
          if (due > 0 && registrationId is! String) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "We couldn't start the payment. Try again in a moment."),
              ),
            );
            return;
          }
          if (due > 0) {
            final outcome = await RegistrationCheckout.pay(
              repository: ref.read(paymentRepositoryProvider),
              eventId: _eventId!,
              sellable: _sellable,
              registrationId: registrationId as String,
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim(),
            );
            if (!mounted) return;
            if (outcome.isLeft) {
              showPaymentFailure(context, outcome.left);
              return;
            }
            if (!outcome.right) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment not completed. Your place is held — tap Continue to pay.')),
              );
              return;
            }
          }
          if (!mounted) return;
          context.go('/events/registration-success', extra: {
            'ticketId': data['ticket_id'],
            'eventName': data['event_name'],
            'eventId': data['event_id'],
            'eventDateTime': data['event_datetime'],
            'fullName': data['full_name'],
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registration failed. Please try again.'),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          // The form is usable again while the refusal is read.
          setState(() => _isSubmitting = false);
          await _showRefusal(e);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  /// What shows instead of the form: a way to sign in, the event loading
  /// or failing to, or -- on an iPhone, for a paid online event -- that it
  /// isn't sold here. Null for the form.
  Widget? _notAForm(BuildContext context) {
    if (!ref.watch(isAuthenticatedProvider)) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            const Text(
              'Sign in to register',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your ticket is kept with your account, so you need one to register.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Color(0xFF4B5563)),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => ensureSignedInFor(context, ref,
                  reason: 'Sign in, then fill in the form.'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C333D),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      );
    }
    if (_loadingEvent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return ErrorView(message: _loadError, onRetry: _loadEvent);
    }
    if (!_sellable) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [IosSaleBlockedNotice()],
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Get profile data for pre-filling
    final profileState = ref.watch(profileProvider);
    final organizationsAsync = ref.watch(organizationsProvider);

    // Pre-fill data if profile is available
    if (profileState.profile != null) {
      _prefillFromProfile(profileState.profile!);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF2C333D)),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _notAForm(context) ??
          Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Flexible: on a narrow phone the heading wraps rather
                  // than running off the edge.
                  Flexible(
                    child: Text(
                      'Hop on and fill out this form! 📝✨',
                      style: TextStyle(
                        color: Color(0xFF1E1E1E),
                        fontSize: 24,
                        fontFamily: 'BebasNeue',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Name field
                      _buildInputField(
                        label: 'Name',
                        isRequired: true,
                        child: TextFormField(
                          controller: _nameController,
                          style: TextStyle(
                            color: Color(0xFF1E1E1E),
                            fontSize: 16,
                            fontFamily: 'DMSans',
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your name',
                            hintStyle: TextStyle(
                              color: Color(0xFFB4B4B4),
                              fontSize: 16,
                              fontFamily: 'DMSans',
                              fontWeight: FontWeight.w500,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF2C333D), width: 0.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF2C333D), width: 0.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF2C333D), width: 1),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFFCC0000), width: 0.5),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your name';
                            }
                            if (value.length < 3) {
                              return 'Name must be at least 3 characters long';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Email field (read-only, pre-filled)
                      _buildInputField(
                        label: 'Email',
                        isRequired: true,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          readOnly: true, // Make email non-editable
                          style: TextStyle(
                            color: Color(0xFF6B7280), // Greyed out color
                            fontSize: 16,
                            fontFamily: 'DMSans',
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(
                              color: Color(0xFFB4B4B4),
                              fontSize: 16,
                              fontFamily: 'DMSans',
                              fontWeight: FontWeight.w500,
                            ),
                            filled: true,
                            fillColor:
                                Color(0xFFF3F4F6), // Light grey background
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFFD1D5DB), width: 0.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFFD1D5DB), width: 0.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFFD1D5DB), width: 0.5),
                            ),
                            suffixIcon: Icon(
                              Icons.lock_outline,
                              color: Color(0xFF9CA3AF),
                              size: 18,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Phone field
                      _buildInputField(
                        key: _phoneKey,
                        label: 'Phone Number',
                        isRequired: true,
                        child: TextFormField(
                          key: const ValueKey('register-phone'),
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          onChanged: (_) {
                            if (_phoneProblem != null) {
                              setState(() => _phoneProblem = null);
                            }
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: TextStyle(
                            color: Color(0xFF1E1E1E),
                            fontSize: 16,
                            fontFamily: 'DMSans',
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            errorText: _phoneProblem,
                            hintText: 'Enter your phone number',
                            hintStyle: TextStyle(
                              color: Color(0xFFB4B4B4),
                              fontSize: 16,
                              fontFamily: 'DMSans',
                              fontWeight: FontWeight.w500,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF2C333D), width: 0.5),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF2C333D), width: 0.5),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: Color(0xFF2C333D), width: 1),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your phone number';
                            }
                            if (value.length != 10) {
                              return 'Phone number must be 10 digits';
                            }
                            if ((_wantsClubUpdates || _wantsWhatsapp) &&
                                whatsappNumber(value) == null) {
                              return 'WhatsApp needs a mobile number. Or '
                                  'untick the WhatsApp box.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        key: const ValueKey('register-whatsapp'),
                        value: _whatsapp,
                        onChanged: (on) => setState(() {
                          _whatsapp = on ?? false;
                          _phoneProblem = null;
                        }),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        activeColor: const Color(0xFF2C333D),
                        title: const Text(
                          whatsappTicketsText,
                          style: TextStyle(
                            color: Color(0xFF1E1E1E),
                            fontSize: 15,
                            fontFamily: 'DMSans',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: const Text(
                          'On the phone number above. It needs WhatsApp.',
                          style: TextStyle(fontSize: 13, fontFamily: 'DMSans'),
                        ),
                      ),
                      if (_offersClubUpdates) ...[
                        CheckboxListTile(
                          key: const ValueKey('register-club-updates'),
                          value: _clubUpdates,
                          onChanged: (on) => setState(() {
                            _clubUpdates = on ?? false;
                            _phoneProblem = null;
                          }),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: const Color(0xFF2C333D),
                          title: Text(
                            clubUpdatesText(_clubName),
                            style: const TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 15,
                              fontFamily: 'DMSans',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          subtitle: const Text(
                            'On the phone number above.',
                            style:
                                TextStyle(fontSize: 13, fontFamily: 'DMSans'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Organization field
                      organizationsAsync.when(
                        data: (organizations) =>
                            _buildOrganizationField(organizations),
                        loading: () => _buildInputField(
                          label: 'Organization/College',
                          isRequired: false,
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Color(0xFF2C333D), width: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF2C333D),
                                ),
                              ),
                            ),
                          ),
                        ),
                        error: (_, __) => _buildInputField(
                          label: 'Organization/College',
                          isRequired: false,
                          child: TextFormField(
                            controller: _otherOrgController,
                            style: TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 16,
                              fontFamily: 'DMSans',
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your organization name',
                              hintStyle: TextStyle(
                                color: Color(0xFFB4B4B4),
                                fontSize: 16,
                                fontFamily: 'DMSans',
                                fontWeight: FontWeight.w500,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Color(0xFF2C333D), width: 0.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Color(0xFF2C333D), width: 0.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                    color: Color(0xFF2C333D), width: 1),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Additional dynamic fields
                      for (final (i, detail)
                          in _questions.indexed)
                        Padding(
                          key: _questionKeys[i],
                          padding: const EdgeInsets.only(top: 24),
                          child: _buildAdditionalField(detail),
                        ),

                      // The shelf: what the event sells with its ticket.
                      MerchPicker(catalog: _catalog, picks: _picks, onChanged: (next) => setState(() => _picks = next)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2C333D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isSubmitting
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'Continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontFamily: 'BebasNeue',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                ),
              ),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
