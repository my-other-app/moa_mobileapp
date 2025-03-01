import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';
import 'package:myotherapp/presentation/login/interests_selection_page.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:dio/dio.dart';

// Import your bloc file here

// Organization model
class Organization {
  final int id;
  final String name;

  Organization({required this.id, required this.name});

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class OnboardingDetailsPage extends StatefulWidget {
  final String? initialName; // Optional initial value for name
  final String profileUrl;
  const OnboardingDetailsPage(
      {super.key, this.initialName, required this.profileUrl});

  @override
  State<OnboardingDetailsPage> createState() => _OnboardingDetailsPageState();
}

class _OnboardingDetailsPageState extends State<OnboardingDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  final TextEditingController _whatsappController = TextEditingController();
  Organization? _selectedOrganization;
  bool _autovalidateMode = false;
  List<Organization> _orgList = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    //need to handle these using provider || bloc
    setState(() {
      _nameController = TextEditingController(text: widget.initialName);
    });

    print("profile = ${widget.profileUrl}");
    fetchOrganizations();
  }

  // Fetch organization list from API.
  Future<void> fetchOrganizations() async {
    try {
      // Dio dio = Dio(
      //   BaseOptions(
      //     baseUrl: 'https://api.staging.myotherapp.com/api/v1',
      //     headers: {'Content-Type': 'application/json'},
      //   ),
      // );
      // final response = await dio.get('/orgs/list');
      final response =
          await APIService.instance.request('/orgs/list', DioMethod.get);
      final List data = response.data;
      setState(() {
        _orgList = data.map((json) => Organization.fromJson(json)).toList();
      });
    } catch (error) {
      print("Error fetching organizations: $error");
    }
  }

  // Function to create the user profile by calling the POST API.
  Future<void> _createUserProfile() async {
    if (_selectedOrganization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an organization.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Retrieve the access token from your bloc.
      // final accessToken = context.read<AppBloc>().state.accessToken;

      // Dio dio = Dio(
      //   BaseOptions(
      //     baseUrl: 'https://api.staging.myotherapp.com/api/v1',
      //     headers: {
      //       'accept': 'application/json',
      //       'Content-Type': 'application/x-www-form-urlencoded',
      //       'Authorization': 'Bearer $accessToken',
      //     },
      //   ),
      // );

      // // Prepare the form data.
      final data = {
        'full_name': _nameController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'org_id': _selectedOrganization!.id.toString(),
      };

      // final response = await dio.post('/user/profile/create', data: data);
      final response = await APIService.instance.request(
          '/user/profile/create',
          contentType: Headers.formUrlEncodedContentType,
          DioMethod.post,
          param: data);
      print("Profile creation response: ${response.data}");

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => InterestsSelectionPage(isOnboarding: true,)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create profile.')),
        );
      }
    } catch (error) {
      print("Error creating profile: $error");
      if (error is DioException && error.response != null) {
        print("Response data: ${error.response?.data}");
      }

      if (error is DioException && error.response?.data['message'] == 'Profile already exists') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => InterestsSelectionPage(isOnboarding: true,)),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('An error occurred during profile creation.')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _validateAndContinue() {
    setState(() {
      _autovalidateMode = true;
    });

    if (_formKey.currentState?.validate() ?? false) {
      _createUserProfile();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _whatsappController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: _autovalidateMode
                        ? AutovalidateMode.always
                        : AutovalidateMode.disabled,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildDragIndicator(),
                        const SizedBox(height: 24),
                        const Text(
                          'Slide in your deets!',
                          style: TextStyle(
                            color: Color(0xFF1E1E1E),
                            fontSize: 24,
                            fontFamily: 'Bebas Neue',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildNameField(),
                        const SizedBox(height: 36),
                        _buildOrganizationField(),
                        const SizedBox(height: 36),
                        _buildWhatsappField(),
                        const SizedBox(height: 48),
                        _buildContinueButton(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/grass.png',
              fit: BoxFit.cover,
            ),
          ),
          if (_isLoading)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildDragIndicator() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 4,
            decoration: ShapeDecoration(
              color: const Color(0xFF17A58F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 4,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Name',
          style: TextStyle(
            color: Color(0xFF2C333D),
            fontSize: 12,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 0.5, color: Color(0xFF2C333D)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: TextFormField(
            controller: _nameController,
            style: const TextStyle(
              color: Color(0xFF1E1E1E),
              fontSize: 16,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter your name',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorStyle: TextStyle(
                color: Color(0xFFCC0000),
                fontSize: 12,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your name';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Make sure you've dropped your legit OG name.",
          style: TextStyle(
            color: Color(0xFFCC0000),
            fontSize: 12,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Organization (if you are a student)',
          style: TextStyle(
            color: Color(0xFF2C333D),
            fontSize: 12,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 0.5, color: Color(0xFF2C333D)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton2<Organization>(
              isExpanded: true,
              hint: Row(
                children: const [
                  Icon(Icons.search, size: 18, color: Color(0xFF2C333D)),
                  SizedBox(width: 8),
                  Text(
                    'Search Your Organization',
                    style: TextStyle(
                      color: Color(0xFFB4B4B4),
                      fontSize: 16,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              items: _orgList
                  .map((org) => DropdownMenuItem<Organization>(
                        value: org,
                        child: Text(
                          org.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontFamily: 'DM Sans',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ))
                  .toList(),
              value: _selectedOrganization,
              onChanged: (value) {
                setState(() {
                  _selectedOrganization = value;
                });
              },
              buttonStyleData: ButtonStyleData(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                height: 44,
              ),
              dropdownStyleData: DropdownStyleData(
                maxHeight: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                offset: const Offset(0, -4),
                scrollbarTheme: ScrollbarThemeData(
                  radius: const Radius.circular(40),
                  thickness: WidgetStateProperty.all(6),
                  thumbVisibility: WidgetStateProperty.all(true),
                ),
              ),
              dropdownSearchData: DropdownSearchData<Organization>(
                searchController: _searchController,
                searchInnerWidget: Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      hintText: 'Search...',
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                ),
                searchInnerWidgetHeight: 50,
                searchMatchFn: (item, searchValue) {
                  return item.value!.name
                      .toLowerCase()
                      .contains(searchValue.toLowerCase());
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWhatsappField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Whatsapp Number',
          style: TextStyle(
            color: Color(0xFF2C333D),
            fontSize: 12,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 0.5, color: Color(0xFF2C333D)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: TextFormField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            style: const TextStyle(
              color: Color(0xFF1E1E1E),
              fontSize: 16,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter your WhatsApp number',
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorStyle: TextStyle(
                color: Color(0xFFCC0000),
                fontSize: 12,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your WhatsApp number';
              }
              if (value.length != 10) {
                return 'Please enter a valid 10-digit number';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          "Make sure it's your active WhatsApp number.",
          style: TextStyle(
            color: Color(0xFFCC0000),
            fontSize: 12,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: ShapeDecoration(
        color: const Color(0xFF2C333D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _validateAndContinue,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'Bebas Neue',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
