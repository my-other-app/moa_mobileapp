import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart';
import 'package:myotherapp/features/profile/domain/entities/profile_entity.dart';

/// Edit profile page for updating user details.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _whatsappController;
  Organization? _selectedOrg;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).profile;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _whatsappController = TextEditingController(text: profile?.whatsapp ?? '');
    _selectedOrg = profile?.organization;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(profileProvider.notifier).updateProfile(
          fullName: _nameController.text,
          whatsapp: _whatsappController.text,
          organizationId: _selectedOrg?.id,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      context.pop();
    } else if (mounted) {
      final error = ref.read(profileProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error ?? 'Failed to update profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizationsAsync = ref.watch(organizationsProvider);
    final profileState = ref.watch(profileProvider);

    // Listen for profile updates
    ref.listen(profileProvider, (prev, current) {
      if (current.profile != null && prev?.profile != current.profile) {
        _nameController.text = current.profile!.fullName;
        _whatsappController.text = current.profile!.whatsapp ?? '';
        _selectedOrg = current.profile!.organization;
      }
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C333D)),
          onPressed: () => context.pop(),
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
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name field
                        _buildLabel('Name'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          style: _inputTextStyle,
                          decoration: _inputDecoration('Enter your name'),
                          validator: (value) => value?.isEmpty == true
                              ? 'Please enter your name'
                              : null,
                        ),
                        const SizedBox(height: 24),

                        // Organization dropdown
                        _buildLabel('College (if you are a student)'),
                        const SizedBox(height: 8),
                        organizationsAsync.when(
                          data: (orgs) => _buildOrgDropdown(orgs),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) =>
                              const Text('Failed to load organizations'),
                        ),
                        const SizedBox(height: 24),

                        // WhatsApp field
                        _buildLabel('WhatsApp Number'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _whatsappController,
                          style: _inputTextStyle,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration:
                              _inputDecoration('Enter your WhatsApp number'),
                          validator: (value) {
                            if (value?.isEmpty == true) {
                              return 'Please enter your WhatsApp number';
                            }
                            if (value!.length != 10) {
                              return 'Please enter a valid 10-digit number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),

                        // Edit interests
                        InkWell(
                          onTap: () => context.pushNamed('onboardingInterests',
                              extra: {'isOnboarding': false}),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Color(0xFFEEEEEE))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Edit Interests', style: _inputTextStyle),
                                const Icon(Icons.arrow_forward_ios,
                                    color: Color(0xFF2C333D), size: 16),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Change avatar
                        InkWell(
                          onTap: () => context.pushNamed('onboardingAvatar',
                              extra: {'isOnboarding': false}),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: const BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: Color(0xFFEEEEEE))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Change Avatar', style: _inputTextStyle),
                                const Icon(Icons.arrow_forward_ios,
                                    color: Color(0xFF2C333D), size: 16),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: profileState.isLoading ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C333D),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: profileState.isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('SAVE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontFamily: 'BebasNeue')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: const Color(0xFF1E1E1E),
            fontSize: 12,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400));
  }

  Widget _buildOrgDropdown(List<Organization> orgs) {
    return DropdownButtonFormField2<Organization>(
      value: _selectedOrg != null
          ? orgs.firstWhere((o) => o.id == _selectedOrg!.id,
              orElse: () => orgs.first)
          : null,
      hint: const Text('Select your college',
          style: TextStyle(color: Color(0xFFB4B4B4))),
      isExpanded: true,
      items: orgs
          .map((o) => DropdownMenuItem<Organization>(
              value: o, child: Text(o.name, style: _inputTextStyle)))
          .toList(),
      onChanged: (value) => setState(() => _selectedOrg = value),
      decoration: _inputDecoration(''),
      dropdownStyleData: DropdownStyleData(
        maxHeight: 300,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8), color: Colors.white),
      ),
    );
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
          color: Color(0xFFB4B4B4), fontSize: 16, fontFamily: 'DM Sans'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2C333D), width: 0.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2C333D), width: 0.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF2C333D), width: 1)),
    );
  }

  TextStyle get _inputTextStyle => const TextStyle(
      color: Color(0xFF1E1E1E),
      fontSize: 16,
      fontFamily: 'DM Sans',
      fontWeight: FontWeight.w400);
}
