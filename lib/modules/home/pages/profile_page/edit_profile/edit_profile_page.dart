import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';
import 'package:myotherapp/modules/login/data/models/profile.dart';
import 'package:myotherapp/modules/login/pages/interests_selection_page.dart';
import 'package:myotherapp/modules/login/pages/onboarding_details_page.dart'
    show Organization;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _whatsappController;
  final ValueNotifier<Organization?> _collegeNameNotifier = ValueNotifier(null);
  List<Organization> colleges = [];

  @override
  void initState() {
    super.initState();
    final initialProfile = context.read<AppBloc>().state.profile;
    _nameController =
        TextEditingController(text: initialProfile?.fullName ?? 'USER');
    _whatsappController = TextEditingController(
        text: initialProfile?.profile?.whatsapp ?? '1234567890');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await fetchOrgDetails();
      _collegeNameNotifier.value = colleges.firstWhere(
        (college) => college.name == initialProfile?.profile?.org?.name,
        orElse: () => colleges.first,
      );
    });
  }

  Future<void> fetchOrgDetails() async {
    final response =
        await APIService.instance.request('/orgs/list', DioMethod.get);
    final List data = response.data;
    setState(() {
      colleges = data.map((json) => Organization.fromJson(json)).toList();
    });
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

  TextStyle get _labelTextStyle => TextStyle(
        color: const Color(0xFF1E1E1E),
        fontSize: 12,
        fontFamily: 'DM Sans',
        fontWeight: FontWeight.w400,
      );

  @override
  Widget build(BuildContext context) {
    return BlocListener<AppBloc, AppBlocState>(
      listener: (context, state) {
        if (state is UpdateUserDetailsState || state is AppLoggedInState) {
          final updatedProfile = state.profile;
          if (updatedProfile != null) {
            setState(() {
              _nameController.text = updatedProfile.profile?.fullName ?? 'USER';
              _whatsappController.text =
                  updatedProfile.profile?.whatsapp ?? '1234567890';
            });
          }
        }
      },
      listenWhen: (previous, current) => previous.profile != current.profile,
      child: Scaffold(
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
            height: 40, // Reduced height
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
              thumbVisibility: MaterialStateProperty.all(true),
            ),
          ),
          menuItemStyleData: const MenuItemStyleData(
            height: 40,
            padding: EdgeInsets.symmetric(horizontal: 16),
          ),
          style: _inputTextStyle,
          decoration: InputDecoration(
            hintText: 'Select your college',
            hintStyle: TextStyle(
              color: Color(0xFFB4B4B4),
              fontSize: 16,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Icon(Icons.school, size: 18, color: Color(0xFF2C333D)),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8), // Reduced vertical padding
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
          items: colleges.map((Organization college) {
            return DropdownMenuItem<Organization>(
              value: college,
              child: Text(
                college.name,
                style: _inputTextStyle,
              ),
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
          if (value == null || value.isEmpty)
            return 'Please enter your WhatsApp number';
          if (value.length != 10) return 'Please enter a valid 10-digit number';
          return null;
        },
      ),
    );
  }

  Widget _buildEditInterestsButton() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  InterestsSelectionPage(isOnboarding: false)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE)))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Edit Interests', style: _inputTextStyle),
            const Icon(Icons.arrow_forward_ios,
                color: Color(0xFF2C333D), size: 16),
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
        onPressed: _onSavePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2C333D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text(
          'SAVE',
          style: TextStyle(
              color: Colors.white, fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
    );
  }

  void _onSavePressed() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
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

        if (response.statusCode == 200) {
          Profile? updatedProfile = context.read<AppBloc>().state.profile;
          if (updatedProfile != null) {
            updatedProfile.profile?.whatsapp = response.data['whatsapp'];
            updatedProfile.profile?.fullName = response.data['full_name'];
            updatedProfile.profile?.org = _collegeNameNotifier.value != null
                ? Org(
                    id: _collegeNameNotifier.value?.id,
                    name: _collegeNameNotifier.value?.name)
                : null;

            debugPrint(
                'Dispatching UpdateUserDetailsEvent with profile: ${updatedProfile.fullName}');
            context
                .read<AppBloc>()
                .add(UpdateUserDetailsEvent(profile: updatedProfile));
            debugPrint('UpdateUserDetailsEvent dispatched');
          }
        }
      } catch (e) {
        debugPrint(e.toString());
      }
    }
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
          color: Color(0xFFB4B4B4),
          fontSize: 16,
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w400),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF2C333D), width: 0.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF2C333D), width: 1)),
    );
  }

  TextStyle get _inputTextStyle => TextStyle(
        color: Color(0xFF1E1E1E),
        fontSize: 16,
        fontFamily: 'DM Sans',
        fontWeight: FontWeight.w400,
      );

  Widget _dropdownHint(String hint) {
    return Text(
      hint,
      style: TextStyle(
          color: Color(0xFFB4B4B4),
          fontSize: 16,
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w400),
    );
  }

  DropdownStyleData _dropdownStyle() {
    return DropdownStyleData(
      maxHeight: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0xFF2C333D).withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(0, 2)),
        ],
      ),
      offset: const Offset(0, -4),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(40),
        thickness: MaterialStateProperty.all(6),
        thumbVisibility: MaterialStateProperty.all(true),
      ),
    );
  }
}
