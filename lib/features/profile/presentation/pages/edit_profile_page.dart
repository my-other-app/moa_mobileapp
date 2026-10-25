import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:finnet/features/profile/presentation/widgets/my_picture.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_details_page.dart'
    show Organization;
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/topics/presentation/widgets/interest_tags.dart';
import 'package:finnet/shared/widgets/toast.dart';

/// Edit Profile Page - fully migrated to Riverpod.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  /// Their picture at the top, which opens "Change Avatar".
  static const pictureKey = ValueKey('edit-profile-picture');

  /// "Change photo or avatar", under the picture.
  static const changePictureKey = ValueKey('edit-profile-change-picture');

  /// The cross that takes their college off, shown while they have one.
  static const clearCollegeKey = ValueKey('edit-profile-clear-college');

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _whatsappController;

  /// Their college, or null for none: it is optional. SAVE sends it as
  /// `org_id`, and the server clears the college when `org_id` is left out.
  final ValueNotifier<Organization?> _collegeNameNotifier = ValueNotifier(null);
  List<Organization> colleges = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _whatsappController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialProfile = ref.read(profileProvider).profile;

      if (initialProfile != null) {
        _nameController.text = initialProfile.fullName;
        _whatsappController.text = initialProfile.whatsapp ?? '';
        // Their own college from the start, not one picked off the list: a
        // SAVE before the list arrives, or when it never does, keeps it.
        final org = initialProfile.organization;
        if (org != null) {
          _collegeNameNotifier.value = Organization(id: org.id, name: org.name);
        }
      }

      await fetchOrgDetails();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _collegeNameNotifier.dispose();
    super.dispose();
  }

  Future<void> fetchOrgDetails() async {
    try {
      final response =
          await APIService.instance.request('/orgs/list', DioMethod.get);
      final List data = response.data;
      if (mounted) {
        setState(() {
          colleges = data.map((json) => Organization.fromJson(json)).toList();
          // The dropdown matches its value by identity, so point it at the
          // list's own entry for their college.
          final chosen = _collegeNameNotifier.value;
          if (chosen != null) {
            for (final college in colleges) {
              if (college.id == chosen.id) {
                _collegeNameNotifier.value = college;
                break;
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch organizations: $e');
    }
  }

  Widget _buildInputField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelTextStyle),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  TextStyle get _labelTextStyle => const TextStyle(
        color: Color(0xFF1E1E1E),
        fontSize: 12,
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w400,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C333D)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'EDIT PROFILE',
          style: TextStyle(
            color: Color(0xFF2C333D),
            fontSize: 20,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.w400,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildPicture(),
                        const SizedBox(height: 24),
                        _buildNameField(),
                        const SizedBox(height: 24),
                        _buildCollegeDropdown(),
                        const SizedBox(height: 24),
                        _buildWhatsappField(),
                        const SizedBox(height: 24),
                        _buildEditInterestsButton(),
                      ],
                    ),
                  ),
                ),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Their picture, centred above the fields, and the way to change it. A
  /// pick takes effect at once, like on sign-up; Save is for the fields.
  Widget _buildPicture() {
    return Column(
      children: [
        Semantics(
          button: true,
          label: 'Change your photo or avatar',
          excludeSemantics: true,
          child: GestureDetector(
            key: EditProfilePage.pictureKey,
            onTap: () => changeAvatar(context),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const MyPicture(size: 96),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C333D),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.photo_camera_outlined,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          key: EditProfilePage.changePictureKey,
          onPressed: () => changeAvatar(context),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF2C333D),
            minimumSize: const Size(48, 48),
          ),
          child: const Text(
            'Change photo or avatar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return _buildInputField(
      label: 'Name',
      child: TextFormField(
        controller: _nameController,
        style: _inputTextStyle,
        decoration: _inputDecoration('Enter your name'),
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter your name' : null,
      ),
    );
  }

  /// The list to pick from, with their own college first when the list
  /// lacks it (it has not arrived, could not be read, or leaves it out).
  List<Organization> _collegeChoices(Organization? college) =>
      college == null || colleges.contains(college)
          ? colleges
          : [college, ...colleges];

  Widget _buildCollegeDropdown() {
    return ValueListenableBuilder<Organization?>(
      valueListenable: _collegeNameNotifier,
      builder: (_, college, __) => _buildInputField(
        label: 'College (if you are a student)',
        child: DropdownButtonFormField2<Organization>(
          value: college,
          hint: _dropdownHint('Select your college'),
          isExpanded: true,
          buttonStyleData: const ButtonStyleData(
            height: 40,
            padding: EdgeInsets.only(right: 8),
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
          style: _inputTextStyle,
          decoration: InputDecoration(
            hintText: 'Select your college',
            hintStyle: const TextStyle(
              color: Color(0xFFB4B4B4),
              fontSize: 16,
              fontFamily: 'DMSans',
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 8),
              child: Icon(Icons.school, size: 18, color: Color(0xFF2C333D)),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
            // Optional, so it can be taken off again.
            suffixIcon: college == null
                ? null
                : IconButton(
                    key: EditProfilePage.clearCollegeKey,
                    tooltip: 'Remove college',
                    icon: const Icon(Icons.close,
                        size: 18, color: Color(0xFF2C333D)),
                    onPressed: () => _collegeNameNotifier.value = null,
                  ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF2C333D), width: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: Color(0xFF2C333D), width: 0.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2C333D), width: 1),
            ),
          ),
          items: _collegeChoices(college).map((Organization college) {
            return DropdownMenuItem<Organization>(
              value: college,
              child: Text(college.name, style: _inputTextStyle),
            );
          }).toList(),
          onChanged: (Organization? newValue) {
            _collegeNameNotifier.value = newValue;
          },
        ),
      ),
    );
  }

  Widget _buildWhatsappField() {
    return _buildInputField(
      label: 'WhatsApp Number (Optional)',
      child: TextFormField(
        controller: _whatsappController,
        style: _inputTextStyle,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        decoration: _inputDecoration('Enter your WhatsApp number'),
        // Optional, as on sign-up, and checked the same way when given.
        validator: (value) {
          final number = value?.trim() ?? '';
          if (number.isNotEmpty && number.length != 10) {
            return 'Please enter a valid 10-digit number';
          }
          return null;
        },
      ),
    );
  }

  /// "Edit Interests", with the interests chosen so far beneath it, each
  /// marked with its topic's colour. Opens the topic-grouped picker.
  Widget _buildEditInterestsButton() {
    final interests =
        ref.watch(profileProvider.select((s) => s.profile?.interests)) ??
            const [];
    return InkWell(
      onTap: () {
        context.push('/profile/interests');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Edit Interests', style: _inputTextStyle),
                const Icon(Icons.arrow_forward_ios,
                    color: Color(0xFF2C333D), size: 16),
              ],
            ),
            if (interests.isNotEmpty) ...[
              const SizedBox(height: 10),
              InterestTags(interests: interests),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 48,
      margin: const EdgeInsets.only(top: 24),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _onSavePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C333D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Text(
                'SAVE',
                style: TextStyle(
                    color: Colors.white, fontSize: 24, fontFamily: 'BebasNeue'),
              ),
      ),
    );
  }

  Future<void> _onSavePressed() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isLoading = true);

      // /user/profile/update sets every field it is given and clears the
      // ones left out, so a blank WhatsApp number or no college is left out.
      final whatsapp = _whatsappController.text.trim();
      final college = _collegeNameNotifier.value;
      try {
        final response = await APIService.instance.request(
          contentType: Headers.formUrlEncodedContentType,
          '/user/profile/update',
          DioMethod.post,
          param: {
            'full_name': _nameController.text,
            if (whatsapp.isNotEmpty) 'whatsapp': whatsapp,
            if (college != null) 'org_id': college.id,
          },
        );

        if (response.statusCode == 200 && mounted) {
          // Refresh profile using Riverpod provider
          await ref.read(profileProvider.notifier).loadProfile();

          if (mounted) {
            showToast(context, 'Profile updated successfully');
            Navigator.of(context).pop();
          }
        }
      } catch (e) {
        // APIService.request throws an ApiException for every failed call
        // (never the DioException a dead branch here used to catch);
        // extractErrorMessage reads the server's message off it.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                extractErrorMessage(
                  e,
                  defaultMessage: 'Could not save your profile.',
                ),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFB4B4B4),
        fontSize: 16,
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w400,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
    );
  }

  TextStyle get _inputTextStyle => const TextStyle(
        color: Color(0xFF1E1E1E),
        fontSize: 16,
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w400,
      );

  Widget _dropdownHint(String hint) {
    return Text(
      hint,
      style: const TextStyle(
        color: Color(0xFFB4B4B4),
        fontSize: 16,
        fontFamily: 'DMSans',
        fontWeight: FontWeight.w400,
      ),
    );
  }
}
