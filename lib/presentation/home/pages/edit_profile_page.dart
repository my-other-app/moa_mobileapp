import 'dart:io' show HttpHeaders;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';
import 'package:myotherapp/presentation/home/pages/interests_page.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  // ignore: unused_field
  TextEditingController _nameController = TextEditingController();
  TextEditingController _collegeController = TextEditingController();
  TextEditingController _whatsappController = TextEditingController();

  final List<String> colleges = [
    'College of Engineering Trivandrum',
    'Government Engineering College, Thrissur',
    'TKM College of Engineering',
    'Model Engineering College',
    'Government Engineering College, Barton Hill',
    'Government College Thalassey'
  ];

  @override
  void initState() {
    super.initState();
    final initialProfile = context.read<AppBloc>().state.profile;

    _nameController =
        TextEditingController(text: initialProfile?.fullName ?? 'USER');
    _collegeController = TextEditingController(
        text: initialProfile?.profile?.org?.name ?? 'College name');
    _whatsappController = TextEditingController(
        text: initialProfile?.profile?.whatsapp ?? '1234567890');

    if (!colleges.contains(_collegeController.text)) {
      colleges.add(_collegeController.text);
    }
  }

  Widget _buildInputField({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 12,
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppBlocState>(
      listener: (context, state) {
        if (state is UpdateUserDetailsState || state is AppLoggedInState) {
          final updatedProfile = state.profile;
          if (updatedProfile != null) {
            setState(() {
              _nameController.text = updatedProfile.fullName ?? 'USER';
              _collegeController.text =
                  updatedProfile.profile?.org?.name ?? 'College name';
              _whatsappController.text =
                  updatedProfile.profile?.whatsapp ?? '1234567890';
            });
          }
        }
      },
      listenWhen: (previous, current) {
        return previous.profile != current.profile;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios, color: Color(0xFF2C333D)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
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
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildInputField(
                          label: 'Name',
                          child: TextFormField(
                            controller: _nameController,
                            style: TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 16,
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter your name',
                              hintStyle: TextStyle(
                                color: Color(0xFFB4B4B4),
                                fontSize: 16,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w400,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16),
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
                                return 'Please enter your name';
                              }
                              return null;
                            },
                            // onSaved: (value) => _name = value,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildInputField(
                          label: 'College (if you are a student)',
                          child: DropdownButtonFormField2<String>(
                            value: _collegeController.text,
                            hint: Text(
                              'Select your college',
                              style: TextStyle(
                                color: Color(0xFFB4B4B4),
                                fontSize: 16,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            isExpanded: true,
                            buttonStyleData: ButtonStyleData(
                              height: 56,
                              padding: EdgeInsets.only(right: 8),
                            ),
                            iconStyleData: IconStyleData(
                              icon: Icon(Icons.keyboard_arrow_down,
                                  color: Color(0xFF2C333D)),
                            ),
                            dropdownStyleData: DropdownStyleData(
                              maxHeight: 300,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF2C333D).withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              offset: const Offset(0, -4),
                              scrollbarTheme: ScrollbarThemeData(
                                radius: const Radius.circular(40),
                                thickness: MaterialStateProperty.all(6),
                                thumbVisibility:
                                    MaterialStateProperty.all(true),
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
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Select your college',
                              prefixIcon: Padding(
                                padding: EdgeInsets.only(left: 16, right: 8),
                                child: Icon(Icons.search,
                                    size: 18, color: Color(0xFF2C333D)),
                              ),
                              prefixIconConstraints:
                                  BoxConstraints(minWidth: 40, minHeight: 40),
                              hintStyle: TextStyle(
                                color: Color(0xFFB4B4B4),
                                fontSize: 16,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w500,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
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
                            items: colleges.map((String college) {
                              return DropdownMenuItem<String>(
                                value: college,
                                child: Text(
                                  college,
                                  style: TextStyle(
                                    color: Color(0xFF1E1E1E),
                                    fontSize: 16,
                                    fontFamily: 'DM Sans',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() {});
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please select your college';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildInputField(
                          label: 'Whatsapp Number',
                          child: TextFormField(
                            controller: _whatsappController,
                            style: TextStyle(
                              color: Color(0xFF1E1E1E),
                              fontSize: 16,
                              fontFamily: 'DM Sans',
                              fontWeight: FontWeight.w400,
                            ),
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                              hintText: 'Enter your WhatsApp number',
                              hintStyle: TextStyle(
                                color: Color(0xFFB4B4B4),
                                fontSize: 16,
                                fontFamily: 'DM Sans',
                                fontWeight: FontWeight.w400,
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 16),
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
                                return 'Please enter your WhatsApp number';
                              }
                              if (value.length != 10) {
                                return 'Please enter a valid 10-digit number';
                              }
                              return null;
                            },
                            // onSaved: (value) => _whatsappNumber = value,
                          ),
                        ),
                        const SizedBox(height: 24),
                        InkWell(
                          onTap: () {
                            // Navigate to Edit Interests page
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => InterestsPage()),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFEEEEEE)),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Edit Interests',
                                  style: TextStyle(
                                    color: Color(0xFF1E1E1E),
                                    fontSize: 14,
                                    fontFamily: 'DM Sans',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFF2C333D),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 48,
                    margin: EdgeInsets.only(top: 24),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          try{
                          final response = await APIService.instance.request(
                            '/user/profile/create',
                            DioMethod.post,
                            param: {
                              'whatsapp': _whatsappController.text,
                              'profile_pic': '',
                              // 'name': _nameController.text,
                              // 'org_id': _collegeController.text,
                            },
                            headers: {
                              HttpHeaders.acceptHeader : Headers.multipartFormDataContentType
                            }
                          );

                          debugPrint(response.data.toString());}
                          catch(e){
                            debugPrint(e.toString());
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF2C333D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'SAVE',
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
          ),
        ),
      ),
    );
  }
}
