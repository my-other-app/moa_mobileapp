import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/utils/email_address.dart';
import 'package:finnet/app/router/tracking_ref.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/common/models/events/store_model.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/core/utils/whatsapp_number.dart';
import 'package:finnet/features/clubs/domain/club_updates.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:finnet/features/events/presentation/widgets/merch_picker.dart';
import 'package:finnet/features/events/presentation/widgets/question_fields.dart';
import 'package:finnet/features/events/presentation/widgets/revealed_question.dart';
import 'package:finnet/features/events/presentation/widgets/registration_feedback.dart';
import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/discount_code_field.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/ticket_type_picker.dart';
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

  /// A hidden ticket type a link named (`?ticket_type=`): listed, and
  /// chosen, as the website does.
  final int? linkedTicketTypeId;

  /// The event's name, from the event page, for the request's screen.
  final String? eventName;

  /// The club reviews every registration ("Review registrations"), from the
  /// event page: the form registers for review (the API's request), and
  /// says how the club reviews. The form also reads it from the event and
  /// its ticket types, and handles a review's answer whatever this says.
  final bool? requiresApproval;

  const EventFormPage({
    super.key,
    this.eventId,
    this.eventRef,
    this.additionalDetails,
    this.hasFee,
    this.isOnline,
    this.clubName,
    this.offersClubUpdates,
    this.linkedTicketTypeId,
    this.eventName,
    this.requiresApproval,
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

  /// The answers to the event's own questions, and what the server said is
  /// wrong with each (INVALID_ANSWERS), shown under its question until that
  /// answer changes (question_fields.dart, shared with the missing-answers
  /// screen and the door).
  final _fields = QuestionAnswers();

  // Organization selection
  Organization? _selectedOrganization;
  bool _isOtherOrganization = false;
  final _otherOrgController = TextEditingController();

  bool _isSubmitting = false;
  bool _hasPrefilledData = false;

  /// What the event sells with its ticket, and what this guest picked.
  StoreCatalog _catalog = StoreCatalog.empty;
  Map<String, StorePick> _picks = {};

  /// Each question's place in the scroll, in order, to bring the first
  /// refused answer into view.
  List<GlobalKey> _questionKeys = const [];

  /// The event's questions: given, or read from `/events/info`.
  List<AdditionalDetail> get _questions => _fields.questions;

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

  /// The event's name, when known (for the request's screen).
  String? _eventName;

  /// The club reviews every registration: by the event page's word, or the
  /// event's own (`requires_approval`).
  bool _requiresApproval = false;

  /// [_requiresApproval], or the ticket types say so.
  bool get _confirmsEach =>
      _requiresApproval || (_ticketing?.requiresApproval ?? false);

  /// What the server said of the phone number (WHATSAPP_NUMBER), shown
  /// under it until it, or the box, changes.
  String? _phoneProblem;
  final _phoneKey = GlobalKey();

  /// "Send my ticket and event reminders on WhatsApp": unticked until the
  /// person ticks it, as on the website.
  bool _whatsapp = false;

  /// The event's ticket types (docs/TICKETING.md); null from a server
  /// without them, when the form is exactly what it was.
  EventTicketing? _ticketing;

  /// The type chosen; null for the server's own choice (the event's only
  /// one).
  int? _ticketTypeId;
  String? _ticketTypeError;
  final _ticketKey = GlobalKey();

  /// The discount code typed, its price preview, and what the
  /// registration said about it.
  final _codeController = TextEditingController();
  DiscountQuote? _quote;
  String? _codeServerError;

  /// The code [_codeServerError] is about.
  String _codeRefused = '';
  final _codeKey = GlobalKey();

  /// The picker shows when the event sells more than one type, or a link
  /// named a hidden one beside the others.
  bool get _showPicker {
    final ticketing = _ticketing;
    if (ticketing == null) return false;
    return ticketing.requiresChoice ||
        (widget.linkedTicketTypeId != null && ticketing.types.length > 1);
  }

  /// The type the order is for, when known.
  TicketType? get _chosenType {
    final ticketing = _ticketing;
    if (ticketing == null) return null;
    return ticketing.typeById(_ticketTypeId) ??
        (ticketing.types.length == 1 ? ticketing.types.single : null);
  }

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
    _fields.addListener(_answersChanged);
    // An id of 0 is what an older router made of a slug: not an id.
    final given = widget.eventId;
    _eventId = given != null && given > 0
        ? given
        : eventIdOf(widget.eventRef ?? '');
    _hasFee = widget.hasFee;
    _isOnline = widget.isOnline;
    _offersClubUpdates = widget.offersClubUpdates == true;
    _clubName = widget.clubName ?? '';
    _eventName = widget.eventName;
    _requiresApproval = widget.requiresApproval ?? false;
    final questions = widget.additionalDetails;
    if (questions != null) _setQuestions(questions);
    final mustRead = questions == null ||
        _eventId == null ||
        (_onIos && (_hasFee == null || _isOnline == null));
    _codeController.addListener(_codeChanged);
    if (mustRead) {
      _loadEvent();
    } else {
      _fetchCatalog();
      _loadTicketing();
    }
  }

  /// What the registration said about the code goes once the code changes.
  void _codeChanged() {
    if (_codeServerError != null && _codeController.text != _codeRefused) {
      setState(() => _codeServerError = null);
    }
  }

  /// The event's ticket types, fresh: what is left matters most now. A
  /// server without them (404), or no answer, leaves the form as it was.
  Future<void> _loadTicketing({EventTicketing? fallback}) async {
    final id = _eventId;
    if (id == null) return;
    EventTicketing? found;
    try {
      found = await ref
          .read(ticketingApiProvider)
          .ticketTypes(id, linked: widget.linkedTicketTypeId);
    } catch (_) {
      found = null;
    }
    found ??= fallback;
    if (!mounted || found == null) return;
    final ticketing = found;
    setState(() {
      _ticketing = ticketing;
      final still = ticketing.typeById(_ticketTypeId);
      if (still == null || !still.onSale) {
        _ticketTypeId =
            ticketing.initialChoice(linked: widget.linkedTicketTypeId);
      }
    });
  }

  /// A field changed an answer: what is shown may have changed with it.
  void _answersChanged() {
    if (mounted) setState(() {});
  }

  /// A controller for every field that is typed into. Previously only
  /// 'text' got one, so a 'tel' or 'textarea' field had nowhere to put a
  /// value even once it rendered.
  void _setQuestions(List<AdditionalDetail> questions) {
    _fields.setQuestions(questions);
    _questionKeys = [for (final _ in questions) GlobalKey()];
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
        if (info.name.trim().isNotEmpty) _eventName ??= info.name.trim();
        if (data is Map && jsonBool(data['requires_approval']) == true) {
          _requiresApproval = true;
        }
        if (widget.additionalDetails == null) {
          _setQuestions(info.additionalDetails);
        }
        _loadingEvent = false;
      });
      _fetchCatalog();
      _loadTicketing(
          fallback: EventTicketing.fromJson(
              data is Map<String, dynamic> ? data['ticketing'] : null));
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
    // A request carries no add-ons: nothing to show.
    if (id == null || _requiresApproval) return;
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
    _codeController.dispose();
    _fields
      ..removeListener(_answersChanged)
      ..dispose();
    super.dispose();
  }

  /// The questions shown for the answers so far
  /// (conditional-questions-contract.md §3).
  List<AdditionalDetail> get _shownQuestions => _fields.shown;

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
  }) =>
      QuestionFrame(
        key: key,
        label: label,
        errorText: errorText,
        isRequired: isRequired,
        child: child,
      );

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
    // The club turned "Review registrations" on after the form opened: from
    // now on the form registers for review, with no add-ons (one under
    // review carries none), and says so.
    final approvalCode = errorCodeOf(error);
    if (approvalCode == RegistrationErrorCodes.addOnsNotAllowed ||
        approvalCode == RegistrationErrorCodes.approvalRequired) {
      setState(() {
        _requiresApproval = true;
        _picks = {};
      });
    }
    final refused = invalidAnswersOf(
        error, _shownQuestions.map((detail) => detail.key));
    if (refused != null) {
      _showAnswerErrors(refused, serverMessageOf(error));
      return;
    }
    // A discount code refused: said under the code, the rest kept.
    final code = errorCodeOf(error);
    final codeProblem = discountCodeProblem(error);
    if (codeProblem != null && (code?.startsWith('DISCOUNT_CODE_') ?? false)) {
      setState(() {
        _quote = null;
        _codeServerError = codeProblem;
        _codeRefused = _codeController.text;
      });
      _bringIntoView(_codeKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(codeProblem)),
      );
      return;
    }
    // A registration to review is never offered a waiting list, whatever
    // the refusal says.
    final refusal = describeRegistrationError(error,
        approval: _confirmsEach, clubName: _clubName);
    // The ticket type: what is on sale may have changed since the form
    // opened. The types are read again, and the choice is said under them.
    if (code != null && code.startsWith('TICKET_TYPE_')) {
      setState(() => _ticketTypeError = refusal.title);
      unawaited(_loadTicketing());
    }
    // Declined before: My events' list read again, so the event page (from
    // a server that doesn't say it) shows that registration, not the form.
    if (code == RegistrationErrorCodes.requestDeclined) {
      unawaited(ref.read(myRegistrationRequestsProvider.notifier).refresh());
    }
    final action = await showRegistrationRefusal(context, refusal);
    if (!mounted) return;
    // Cancelled meanwhile, or the club declined this person before: back
    // to the event -- asking again won't change it.
    if (isCancelledRefusal(error) ||
        code == RegistrationErrorCodes.requestDeclined) {
      if (context.canPop()) context.pop();
      return;
    }
    if (action == null) return;
    if (context.canPop()) context.pop(action);
  }

  /// Scrolls the field with [key] into view, after this frame.
  void _bringIntoView(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final place = key.currentContext;
      if (place == null || !place.mounted) return;
      Scrollable.ensureVisible(place,
          alignment: 0.1, duration: const Duration(milliseconds: 250));
    });
  }

  /// Each refused answer's reason under its question, and the first of
  /// them brought into view: the form can be long, and a dialog naming the
  /// questions sent people hunting for them.
  void _showAnswerErrors(Map<String, String> refused, String? said) {
    _fields.showErrors(refused);
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
    // Several ticket types: one must be chosen, as the server insists.
    final typeMissing = _showPicker &&
        (_ticketing?.requiresChoice ?? false) &&
        _ticketTypeId == null;
    if (typeMissing) {
      setState(() => _ticketTypeError = 'Choose a ticket.');
      _bringIntoView(_ticketKey);
    }
    final valid = _formKey.currentState!.validate();
    if (valid && !typeMissing) {
      setState(() {
        _isSubmitting = true;
        _fields.errors.clear();
      });

      try {
        // The event's own questions: blanks left out, and never an answer
        // to a question that doesn't apply -- a picked date or time as
        // picked, not as the words shown in its field.
        final additionalDetailsMap = _fields.collect();

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
          // A request carries no add-ons (the club confirms the place
          // first), so none go with one.
          if (_catalog.hasAnything && !_confirmsEach)
            'store': picksToPayload(_catalog, _picks),
          // Only when ticked: unticked is the server's default.
          if (_wantsClubUpdates) 'club_updates_whatsapp': true,
          // The ticket and the day-before reminder on WhatsApp too.
          if (_wantsWhatsapp) 'whatsapp_opt_in': true,
          // The club's tracking link that opened the app, if one did: the
          // server credits the sign-up to it (tracking_ref.dart).
          if (TrackingRef.instance.current case final ref?) 'ref': ref,
          // The ticket type chosen (left out: the event's only one), and a
          // discount code typed. Neither goes to a server without them.
          if (_ticketTypeId != null) 'ticket_type_id': _ticketTypeId,
          if (_codeController.text.trim().isNotEmpty)
            'discount_code': _codeController.text.trim(),
          // This app can take a registration under review, for an event
          // whose club reviews every one. Always said: an event can turn it
          // on after the page was read, and a server without it ignores the
          // field.
          'accepts_approval': true,
        };

        final response = await APIService.instance.request(
          '/events/registration/$_eventId/register',
          DioMethod.post,
          param: requestData,
        );

        if (response.statusCode == 200 && mounted) {
          // Extract ticket data from response
          final data = response.data as Map<String, dynamic>;
          final result = RegistrationResult.fromJson(data);
          // A request, not a registration: no ticket and no payment until
          // the club confirms it.
          if (result.approval case final approval?) {
            _eventName ??= result.eventName;
            _requestSent(approval);
            return;
          }
          // The ticket type, kept with the ticket on this phone: the list
          // of registrations doesn't say it.
          if (result.ticketId != null && result.ticketTypeName != null) {
            ref
                .read(savedTicketsProvider.notifier)
                .rememberTicketType(result.ticketId!, result.ticketTypeName!);
          }
          // The ticket, and whatever was picked from the shelf, are paid in
          // one checkout. Nothing due -- a free type, or a code that covered
          // it -- is no payment step, even on a paid event.
          final due = result.payAmount;
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
            if (result.ticketTypeName != null)
              'ticketType': result.ticketTypeName,
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

  /// The club reviews every registration, and this one is in: its screen
  /// ("You're registered!"), over My events (as a registration's success
  /// is), which says what happens next.
  void _requestSent(RegistrationRequest approval) {
    final eventId = _eventId;
    final request = RegistrationRequest(
      id: approval.id,
      status: approval.status == RequestStatus.unknown
          ? RequestStatus.pending
          : approval.status,
      token: approval.token,
      statusUrl: approval.statusUrl,
      submittedAt: approval.submittedAt,
      fullName: _nameController.text.trim(),
      ticketTypeId: _chosenType?.id,
      ticketTypeName: _showPicker ? _chosenType?.name : null,
      event: eventId == null
          ? null
          : RequestEvent(
              id: eventId,
              name: _eventName ?? '',
              clubName: _clubName.trim().isEmpty ? null : _clubName.trim(),
            ),
    );
    ref.read(myRegistrationRequestsProvider.notifier).remember(request);
    context.go('/events/request-sent', extra: {
      'request': request,
      'email': _emailController.text.trim(),
    });
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

    final shown = _fields.shownKeys;

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
                      // The ticket: which of the event's types, when it
                      // sells more than one.
                      if (_showPicker) ...[
                        KeyedSubtree(
                          key: _ticketKey,
                          child: TicketTypePicker(
                            // A request has no waiting list to mention.
                            types: _confirmsEach
                                ? _ticketing!.withoutWaitlist().types
                                : _ticketing!.types,
                            selected: _ticketTypeId,
                            errorText: _ticketTypeError,
                            onChanged: (id) => setState(() {
                              _ticketTypeId = id;
                              _ticketTypeError = null;
                            }),
                            // Sold out with its list open: back to the
                            // event, which offers the waiting list -- never
                            // when the club reviews every registration.
                            onJoinWaitlist: _confirmsEach
                                ? null
                                : () {
                                    if (context.canPop()) {
                                      context
                                          .pop(RegistrationAction.joinWaitlist);
                                    }
                                  },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
                            if (!looksLikeEmail(value)) {
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

                      // The event's own questions, in order: those the
                      // answers so far show. A follow-up appears as its
                      // answer is chosen.
                      for (final (i, detail) in _questions.indexed)
                        if (shown.contains(detail.key))
                          Padding(
                            key: _questionKeys[i],
                            padding: const EdgeInsets.only(top: 24),
                            child: detail.showIf == null
                                ? QuestionField(
                                    detail: detail, answers: _fields)
                                : RevealedQuestion(
                                    child: QuestionField(
                                        detail: detail, answers: _fields)),
                          ),

                      // The shelf: what the event sells with its ticket.
                      // Not for a request: it carries no add-ons.
                      if (!_confirmsEach)
                        MerchPicker(catalog: _catalog, picks: _picks, onChanged: (next) => setState(() => _picks = next)),

                      // A discount code, and what the order comes to, for
                      // an event with a paid ticket type.
                      if (_ticketing?.anyPaid ?? false) ...[
                        const SizedBox(height: 24),
                        KeyedSubtree(
                          key: _codeKey,
                          child: DiscountCodeField(
                            controller: _codeController,
                            ticketTypeId: _ticketTypeId,
                            needsType: _ticketing!.requiresChoice,
                            serverError: _codeServerError,
                            onQuote: (quote) => setState(() => _quote = quote),
                            check: (code, typeId) => ref
                                .read(ticketingApiProvider)
                                .checkCode(
                                  _eventId!,
                                  code: code,
                                  ticketTypeId: typeId,
                                  email: _emailController.text,
                                  phone: _phoneController.text,
                                ),
                          ),
                        ),
                        if (_chosenType case final type?) ...[
                          const SizedBox(height: 16),
                          _OrderSummary(
                            type: type,
                            quote: _quote?.ticketTypeId == null ||
                                    _quote?.ticketTypeId == type.id
                                ? _quote
                                : null,
                            addOns: _confirmsEach
                                ? 0
                                : picksTotal(_catalog, _picks),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              if (_confirmsEach) ...[
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    reviewsEveryRegistrationNote(_clubName),
                    key: const ValueKey('form-approval-note'),
                    style: const TextStyle(
                        fontSize: 13, height: 1.35, color: Color(0xFF4B5563)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                          _confirmsEach ? 'Register' : 'Continue',
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

/// What the order comes to before it is sent: the ticket, a code's
/// discount, the add-ons. The registration's answer is the final word.
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.type, this.quote, this.addOns = 0});

  final TicketType type;
  final DiscountQuote? quote;
  final double addOns;

  static const totalKey = ValueKey('order-total');

  @override
  Widget build(BuildContext context) {
    final ticket = quote?.amount ?? type.price;
    final total = ticket + addOns;
    Widget line(String label, String value, {bool strong = false, Key? key}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: strong ? FontWeight.w700 : FontWeight.w400)),
              ),
              Text(value,
                  key: key,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: strong ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          line('Ticket · ${type.name}', priceLabel(quote?.price ?? type.price)),
          if (quote != null && quote!.discount > 0)
            line('Code ${quote!.code}', '−${formatRupees(quote!.discount)}'),
          if (addOns > 0) line('Add-ons', formatRupees(addOns)),
          const Divider(height: 12),
          line('Total', total > 0 ? formatRupees(total) : 'Free',
              strong: true, key: totalKey),
        ],
      ),
    );
  }
}
