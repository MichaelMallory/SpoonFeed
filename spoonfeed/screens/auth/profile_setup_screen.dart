import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isChef = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      final user = authService.currentUser;
      if (user == null) throw Exception('No user found');

      await authService.updateUserData(user.uid, {
        'displayName': _displayNameController.text.trim(),
        'bio': _bioController.text.trim(),
        'isChef': _isChef,
        'updatedAt': DateTime.now(),
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
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
        title: const Text('Complete Your Profile'),
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
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
                onPressed: _isLoading ? null : _completeSetup,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Complete Setup'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 