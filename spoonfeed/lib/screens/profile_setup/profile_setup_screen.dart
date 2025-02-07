import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isInitialSetup;
  
  const ProfileSetupScreen({
    super.key,
    this.isInitialSetup = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _authService = AuthService();
  bool _isChef = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed('/auth');
        return;
      }

      // Only load existing data if not initial setup
      if (!widget.isInitialSetup) {
        final userData = await _authService.getUserData(user.uid);
        if (mounted && userData != null) {
          setState(() {
            _displayNameController.text = userData.displayName ?? user.displayName ?? '';
            _bioController.text = userData.bio ?? '';
            _isChef = userData.isChef;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading user data: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('No user found');

      await _authService.updateUserData(user.uid, {
        'displayName': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'isChef': _isChef,
        'updatedAt': DateTime.now(),
      });

      if (!mounted) return;
      
      if (widget.isInitialSetup) {
        // For initial setup, go to main screen and clear navigation stack
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      } else {
        // For profile edit, just pop back with success result
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isInitialSetup ? 'Complete Your Profile' : 'Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about yourself',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person),
                  hintText: 'How should we call you?',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  prefixIcon: Icon(Icons.description),
                  hintText: 'Tell us about your cooking journey...',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please tell us a bit about yourself';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('I\'m a Chef/Professional Cook'),
                subtitle: const Text(
                  'Enable this if you\'re a professional in the culinary industry',
                ),
                value: _isChef,
                onChanged: (value) => setState(() => _isChef = value),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _isLoading ? null : _saveProfile,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(widget.isInitialSetup ? 'Complete Setup' : 'Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 