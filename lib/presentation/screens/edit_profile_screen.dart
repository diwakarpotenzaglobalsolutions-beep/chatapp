import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/theme.dart';
import '../../domain/entities/user_entity.dart';
import '../../injection/injection_container.dart';
import '../blocs/edit_profile/edit_profile_bloc.dart';
import '../blocs/home/home_bloc.dart';
import '../blocs/upload_profile_image/upload_profile_image_bloc.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _dobController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  
  String _selectedGender = 'Male';
  String _profilePictureUrl = '';
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Populate existing user details from HomeBloc state
    final homeState = context.read<HomeBloc>().state;
    if (homeState is HomeLoaded) {
      final user = homeState.currentUser;
      _fullNameController.text = user.fullName;
      _usernameController.text = user.username;
      _phoneController.text = user.phoneNumber;
      _bioController.text = user.bio;
      _dobController.text = user.dateOfBirth;
      _countryController.text = user.country;
      _cityController.text = user.city;
      _selectedGender = user.gender.isNotEmpty ? user.gender : 'Male';
      _profilePictureUrl = user.profilePicture;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _dobController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage(String uid) async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      context.read<UploadProfileImageBloc>().add(
        UploadImageRequested(uid: uid, filePath: pickedFile.path),
      );
    }
  }

  void _saveProfile(UserEntity originalUser) {
    if (_formKey.currentState?.validate() ?? false) {
      final updatedUser = UserEntity(
        uid: originalUser.uid,
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        email: originalUser.email, // read-only
        phoneNumber: _phoneController.text.trim(),
        bio: _bioController.text.trim(),
        profilePicture: _profilePictureUrl,
        dateOfBirth: _dobController.text.trim(),
        gender: _selectedGender,
        country: _countryController.text.trim(),
        city: _cityController.text.trim(),
        onlineStatus: originalUser.onlineStatus,
        lastSeen: originalUser.lastSeen,
        createdAt: originalUser.createdAt,
        updatedAt: DateTime.now(),
      );

      context.read<EditProfileBloc>().add(EditProfileSubmitted(updatedUser));
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeState = context.watch<HomeBloc>().state;
    if (homeState is! HomeLoaded) {
      return const Scaffold(body: Center(child: Text('User details not loaded')));
    }
    
    final user = homeState.currentUser;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Profile'),
        ),
        body: MultiBlocListener(
          listeners: [
            BlocListener<EditProfileBloc, EditProfileState>(
              listener: (context, state) {
                if (state is EditProfileSuccess) {
                  // Reload home details to update profile representation
                  context.read<HomeBloc>().add(const LoadHome(silent: true));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated successfully'), backgroundColor: AppColors.success),
                  );
                  Navigator.pop(context);
                } else if (state is EditProfileFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.error), backgroundColor: AppColors.error),
                  );
                }
              },
            ),
            BlocListener<UploadProfileImageBloc, UploadProfileImageState>(
              listener: (context, state) {
                if (state is UploadImageSuccess) {
                  setState(() {
                    _profilePictureUrl = state.downloadUrl;
                  });
                  context.read<HomeBloc>().add(const LoadHome(silent: true));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile picture updated'), backgroundColor: AppColors.success),
                  );
                } else if (state is RemoveImageSuccess) {
                  setState(() {
                    _profilePictureUrl = '';
                  });
                  context.read<HomeBloc>().add(const LoadHome(silent: true));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile picture removed'), backgroundColor: AppColors.success),
                  );
                } else if (state is UploadImageFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.error), backgroundColor: AppColors.error),
                  );
                }
              },
            ),
          ],
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppColors.darkBackgroundGradient,
            ),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar view and modify
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 54,
                            backgroundColor: AppColors.surfaceLight,
                            backgroundImage: _profilePictureUrl.isNotEmpty
                                ? CachedNetworkImageProvider(_profilePictureUrl)
                                : null,
                            child: _profilePictureUrl.isEmpty
                                ? const Icon(Icons.person, size: 54, color: Colors.white)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Builder(
                              builder: (context) {
                                return GestureDetector(
                                  onTap: () => _pickAndUploadImage(user.uid),
                                  child: const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary,
                                    child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                  ),
                                );
                              }
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Remove Image Button
                    if (_profilePictureUrl.isNotEmpty)
                      Center(
                        child: Builder(
                          builder: (context) {
                            return TextButton(
                              onPressed: () {
                                context.read<UploadProfileImageBloc>().add(RemoveImageRequested(user.uid));
                              },
                              child: const Text('Remove Photo', style: TextStyle(color: AppColors.error)),
                            );
                          }
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Full Name
                    TextFormField(
                      controller: _fullNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Username
                    TextFormField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Username'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Username is required';
                        }
                        if (value.trim().length < 4) {
                          return 'Username must be at least 4 characters';
                        }
                        if (value.trim().contains(' ')) {
                          return 'Username cannot contain spaces';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    TextFormField(
                      controller: _bioController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Bio'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),

                    // Phone Number
                    TextFormField(
                      controller: _phoneController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Phone Number'),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Date of Birth
                    TextFormField(
                      controller: _dobController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)', hintText: '1998-05-12'),
                    ),
                    const SizedBox(height: 16),

                    // Gender Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      dropdownColor: AppColors.surface,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedGender = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Country & City
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cityController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'City'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _countryController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Country'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Submit
                    BlocBuilder<EditProfileBloc, EditProfileState>(
                      builder: (context, state) {
                        if (state is EditProfileLoading) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                        }
                        return ElevatedButton(
                          onPressed: () => _saveProfile(user),
                          child: const Text('SAVE CHANGES'),
                        );
                      },
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
