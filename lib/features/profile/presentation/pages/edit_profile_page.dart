import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/auth/presentation/pages/onboarding_details_page.dart'
    show Organization;
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/topics/presentation/widgets/interest_tags.dart';

/// Edit Profile Page - fully migrated to Riverpod.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _whatsappController;
  final ValueNotifier<Organization?> _collegeNameNotifier = ValueNotifier(null);
  List<Organization> colleges = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Controllers will be initialized in didChangeDependencies
    _nameController = TextEditingController();
    _whatsappController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Get initial profile from Riverpod provider
      final profileState = ref.read(profileProvider);
      final initialProfile = profileState.profile;

      if (initialProfile != null) {
        _nameController.text = initialProfile.fullName;
        _whatsappController.text = initialProfile.whatsapp ?? '';
      }

      await fetchOrgDetails();
      if (mounted && colleges.isNotEmpty && initialProfile != null) {
        _collegeNameNotifier.value = colleges.firstWhere(
          (college) => college.name == initialProfile.organization?.name,
          orElse: () => colleges.first,
        );
      }
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
          items: colleges.map((Organization college) {
            return DropdownMenuItem<Organization>(
              value: college,
              child: Text(college.name, style: _inputTextStyle),
            );
          }).toList(),
          onChanged: (Organization? newValue) {
            _collegeNameNotifier.value = newValue;
          },
          validator: (value) =>
              value == null ? 'Please select your college' : null,
        ),
      ),
    );
  }

  Widget _buildWhatsappField() {
    return _buildInputField(
      label: 'Whatsapp Number',
      child: TextFormField(
        controller: _whatsappController,
        style: _inputTextStyle,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        decoration: _inputDecoration('Enter your WhatsApp number'),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your WhatsApp number';
          }
          if (value.length != 10) {
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

      try {
        final response = await APIService.instance.request(
          contentType: Headers.formUrlEncodedContentType,
          '/user/profile/update',
          DioMethod.post,
          param: {
            'full_name': _nameController.text,
            'whatsapp': _whatsappController.text,
            if (_collegeNameNotifier.value != null)
              'org_id': _collegeNameNotifier.value?.id,
          },
        );

        if (response.statusCode == 200 && mounted) {
          // Refresh profile using Riverpod provider
          await ref.read(profileProvider.notifier).loadProfile();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully')),
            );
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
