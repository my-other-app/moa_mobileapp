import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';

class EventFormPage extends ConsumerStatefulWidget {
  final int eventId;
  final List<AdditionalDetail> additionalDetails;

  const EventFormPage({
    super.key,
    required this.eventId,
    required this.additionalDetails,
  });

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

  // Organization selection
  Organization? _selectedOrganization;
  bool _isOtherOrganization = false;
  final _otherOrgController = TextEditingController();

  bool _isSubmitting = false;
  bool _hasPrefilledData = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers for text fields
    for (var detail in widget.additionalDetails) {
      if (detail.fieldType == 'text') {
        _additionalTextControllers[detail.key] = TextEditingController();
      }
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

  /// Pre-fill form data from user profile
  void _prefillFromProfile(UserProfile profile) {
    if (_hasPrefilledData) return;
    _hasPrefilledData = true;

    _nameController.text = profile.fullName;
    _emailController.text = profile.email;
    if (profile.phone != null && profile.phone!.isNotEmpty) {
      _phoneController.text = profile.phone!;
    } else if (profile.whatsapp != null && profile.whatsapp!.isNotEmpty) {
      _phoneController.text = profile.whatsapp!;
    }

    if (profile.organization != null) {
      _selectedOrganization = profile.organization;
    }
  }

  Widget _buildInputField({
    required String label,
    required Widget child,
    String? errorText,
    bool isRequired = false,
  }) {
    return SizedBox(
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
                  fontFamily: 'DM Sans',
                  fontWeight: FontWeight.w400,
                ),
              ),
              if (isRequired)
                Text(
                  ' *',
                  style: TextStyle(
                    color: Color(0xFFCC0000),
                    fontSize: 12,
                    fontFamily: 'DM Sans',
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

  Widget _buildAdditionalField(AdditionalDetail detail) {
    if (detail.fieldType == 'text') {
      return _buildInputField(
        label: detail.label,
        isRequired: detail.requiredField,
        child: TextFormField(
          controller: _additionalTextControllers[detail.key],
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 16,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Enter ${detail.label.toLowerCase()}',
            hintStyle: TextStyle(
              color: Color(0xFFB4B4B4),
              fontSize: 16,
              fontFamily: 'DM Sans',
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
            if (detail.requiredField && (value == null || value.isEmpty)) {
              return 'Please enter ${detail.label.toLowerCase()}';
            }
            return null;
          },
        ),
      );
    } else if (detail.fieldType == 'select') {
      return _buildInputField(
        label: detail.label,
        isRequired: detail.requiredField,
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
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Select ${detail.label.toLowerCase()}',
            hintStyle: TextStyle(
              color: Color(0xFFB4B4B4),
              fontSize: 16,
              fontFamily: 'DM Sans',
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
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _additionalSelectValues[detail.key] = newValue;
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
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: 'Select your organization',
              hintStyle: TextStyle(
                color: Color(0xFFB4B4B4),
                fontSize: 16,
                fontFamily: 'DM Sans',
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
                      fontFamily: 'DM Sans',
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
                    fontFamily: 'DM Sans',
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
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Enter your organization name',
                hintStyle: TextStyle(
                  color: Color(0xFFB4B4B4),
                  fontSize: 16,
                  fontFamily: 'DM Sans',
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        // Build additional details map
        Map<String, String> additionalDetailsMap = {};

        // Add text field values
        _additionalTextControllers.forEach((key, controller) {
          if (controller.text.isNotEmpty) {
            additionalDetailsMap[key] = controller.text;
          }
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
        };

        final response = await APIService.instance.request(
          '/events/registration/${widget.eventId}/register',
          DioMethod.post,
          param: requestData,
        );

        if (response.statusCode == 200 && mounted) {
          // Extract ticket data from response
          final data = response.data as Map<String, dynamic>;
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(extractErrorMessage(e,
                  defaultMessage: 'Registration failed')),
            ),
          );
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Hop on and fill out this form! 📝✨',
                    style: TextStyle(
                      color: Color(0xFF1E1E1E),
                      fontSize: 24,
                      fontFamily: 'Bebas Neue',
                      fontWeight: FontWeight.w400,
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
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your name',
                            hintStyle: TextStyle(
                              color: Color(0xFFB4B4B4),
                              fontSize: 16,
                              fontFamily: 'DM Sans',
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
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your email',
                            hintStyle: TextStyle(
                              color: Color(0xFFB4B4B4),
                              fontSize: 16,
                              fontFamily: 'DM Sans',
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
                        label: 'Phone Number',
                        isRequired: true,
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          style: TextStyle(
                            color: Color(0xFF1E1E1E),
                            fontSize: 16,
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter your phone number',
                            hintStyle: TextStyle(
                              color: Color(0xFFB4B4B4),
                              fontSize: 16,
                              fontFamily: 'DM Sans',
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
                            return null;
                          },
                        ),
                      ),
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
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your organization name',
                              hintStyle: TextStyle(
                                color: Color(0xFFB4B4B4),
                                fontSize: 16,
                                fontFamily: 'DM Sans',
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
                      ...widget.additionalDetails.map((detail) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: _buildAdditionalField(detail),
                        );
                      }),
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
                            fontFamily: 'Bebas Neue',
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
