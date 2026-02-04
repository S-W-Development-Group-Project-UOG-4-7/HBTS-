import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_routes.dart';
import '../services/token_store.dart';

class ProfilePage extends StatefulWidget {
  final ProfileArgs args;

  const ProfilePage({super.key, required this.args});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Editable fields
  late String _name;
  late String _email;
  late String _phone;

  // Newly requested fields
  String? _birthday; // e.g. "2001-08-17"
  String? _gender; // "Male" / "Female" / "Other" / "Prefer not to say"

  // Profile image
  String? _photoUrl; // existing remote photo
  File? _localPhoto; // newly picked photo (not uploaded yet)

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _name = widget.args.name;
    _email = widget.args.email;
    _phone = widget.args.phone ?? "";

    _photoUrl = widget.args.photoUrl;

    // If you already have these in args, map them here (otherwise keep null)
    // _birthday = widget.args.birthday;
    // _gender = widget.args.gender;
  }

  Future<void> _logout(BuildContext context) async {
    await TokenStore.clear();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (x == null) return;

    setState(() {
      _localPhoto = File(x.path);
    });

    // TODO: Upload image to backend and set returned URL:
    // final uploadedUrl = await ProfileApi.uploadPhoto(_localPhoto!);
    // setState(() {
    //   _photoUrl = uploadedUrl;
    //   _localPhoto = null; // optional after upload
    // });
  }

  void _showPhotoPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Choose from Gallery"),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text("Take a Photo"),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile({
    required String name,
    required String email,
    required String phone,
    required String? birthday,
    required String? gender,
  }) async {
    // Update local UI immediately
    setState(() {
      _name = name.trim();
      _email = email.trim();
      _phone = phone.trim();
      _birthday = birthday;
      _gender = gender;
    });

    // TODO: Persist to backend:
    // await ProfileApi.updateProfile(
    //   name: _name,
    //   email: _email,
    //   phone: _phone,
    //   birthday: _birthday,
    //   gender: _gender,
    // );
  }

  void _openEditSheet() {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    final phoneCtrl = TextEditingController(text: _phone);

    String? gender = _gender;
    DateTime? birthdayDt;
    if ((_birthday ?? "").isNotEmpty) {
      // Expect yyyy-mm-dd
      final parts = _birthday!.split("-");
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) {
          birthdayDt = DateTime(y, m, d);
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Edit Profile",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showPhotoPicker();
                    },
                    icon: const Icon(Icons.image),
                    label: const Text("Change Photo"),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Name",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Birthday picker
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final initial = birthdayDt ?? DateTime(now.year - 18, now.month, now.day);
                  final picked = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(1900),
                    lastDate: now,
                    initialDate: initial,
                  );
                  if (picked == null) return;
                  if (!ctx.mounted) return;
                  birthdayDt = picked;
                  // Rebuild bottom sheet UI
                  (ctx as Element).markNeedsBuild();
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Birthday",
                    prefixIcon: Icon(Icons.cake),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    birthdayDt == null
                        ? "Select date"
                        : "${birthdayDt!.year.toString().padLeft(4, '0')}-"
                          "${birthdayDt!.month.toString().padLeft(2, '0')}-"
                          "${birthdayDt!.day.toString().padLeft(2, '0')}",
                  ),
                ),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: gender,
                items: const [
                  DropdownMenuItem(value: "Male", child: Text("Male")),
                  DropdownMenuItem(value: "Female", child: Text("Female")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                  DropdownMenuItem(value: "Prefer not to say", child: Text("Prefer not to say")),
                ],
                onChanged: (v) => gender = v,
                decoration: const InputDecoration(
                  labelText: "Gender",
                  prefixIcon: Icon(Icons.badge),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final bday = birthdayDt == null
                        ? null
                        : "${birthdayDt!.year.toString().padLeft(4, '0')}-"
                          "${birthdayDt!.month.toString().padLeft(2, '0')}-"
                          "${birthdayDt!.day.toString().padLeft(2, '0')}";

                    await _saveProfile(
                      name: nameCtrl.text,
                      email: emailCtrl.text,
                      phone: phoneCtrl.text,
                      birthday: bday,
                      gender: gender,
                    );
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("Save", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  ImageProvider? _profileImageProvider() {
    if (_localPhoto != null) return FileImage(_localPhoto!);
    final hasUrl = _photoUrl != null && _photoUrl!.trim().isNotEmpty;
    if (hasUrl) return NetworkImage(_photoUrl!);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _profileImageProvider();
    final initials = _name.isNotEmpty ? _name[0].toUpperCase() : "U";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile"),
        actions: [
          IconButton(
            tooltip: "Edit Profile",
            onPressed: _openEditSheet,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: imageProvider,
                  child: imageProvider == null
                      ? Text(
                          initials,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _showPhotoPicker,
                    child: CircleAvatar(
                      radius: 18,
                      child: const Icon(Icons.camera_alt, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Center(child: Text(_name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          Center(child: Text(_email, style: TextStyle(color: Colors.grey.shade700))),

          const SizedBox(height: 18),

          _info("Phone", _phone.isNotEmpty ? _phone : "-"),
          _info("Birthday", (_birthday ?? "").isNotEmpty ? _birthday! : "-"),
          _info("Gender", (_gender ?? "").isNotEmpty ? _gender! : "-"),

          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _openEditSheet,
              icon: const Icon(Icons.edit),
              label: const Text("Edit details"),
            ),
          ),

          const SizedBox(height: 18),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text("Logout", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(value),
      ),
    );
  }
}
