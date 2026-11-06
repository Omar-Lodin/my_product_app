import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Autumn Product Manager',
      home: AuthGate(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, home: AuthGate());
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  late final Stream<User?> authStateChanges = _auth.authStateChanges();

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('A signed-in user is required to change a password.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
  }

  User? get currentUser => _auth.currentUser;
}

class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Unable to check sign-in status. Try again.'),
            ),
          );
        }
        if (snapshot.hasData) return const ProfileScreen();
        return const AuthenticationScreen();
      },
    );
  }
}

class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({super.key});
  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmedPasswordController = TextEditingController();
  bool _isRegistering = false;
  String? _authError;
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmedPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _authError = null);
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    try {
      if (_isRegistering) {
        await _authService.register(email, password);
      } else {
        await _authService.signIn(email, password);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth code: "${e.code}"');
      if (!mounted) return;
      setState(() {
        switch (e.code) {
          case 'email-already-in-use':
            _authError = 'Email is already in use. Please sign in.';
            break;
          case 'user-not-found':
            _authError = 'No user found for that email. Please register.';
            break;
          case 'invalid-email':
            _authError = 'Invalid email format. Please check and try again.';
            break;
          case 'network-request-failed':
            _authError = 'Network error. Please check your connection.';
            break;
          case 'invalid-credentials':
            _authError =
                'Invalid credentials. Please check your email and password.';
            break;
          case 'wrong-password':
            _authError = 'Incorrect password. Please try again.';
            break;
          case 'weak-password':
            _authError = 'Weak password. Please use at least 6 characters.';
          default:
            _authError =
                'Incorrect email/password combination. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegistering ? 'Register' : 'Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_authError != null) {
                    setState(() => _authError = null);
                  }
                },
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) {
                    return 'Email is required';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                    return 'Enter a valid email address with the format \"user@domain.com\"';
                  }
                  return null;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Password'),
                controller: _passwordController,
                obscureText: true,
                onChanged: (_) {
                  if (_authError != null) {
                    setState(() => _authError = null);
                  }
                },
                validator: (value) {
                  final password = value?.trim() ?? '';
                  if (password.isEmpty) {
                    return 'Password is required';
                  }
                  if (_isRegistering && password.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              if (_isRegistering)
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                  ),
                  controller: _confirmedPasswordController,
                  obscureText: true,
                  validator: (value) {
                    final confirmedPassword = value?.trim() ?? '';
                    if (confirmedPassword.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (confirmedPassword != _passwordController.text.trim()) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ElevatedButton(onPressed: _submit, child: const Text('Continue')),
              if (_authError != null)
                Text(_authError!, style: const TextStyle(color: Colors.red)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isRegistering = !_isRegistering;
                    _authError = null;
                    _passwordController.clear();
                    _confirmedPasswordController.clear();
                    _formKey.currentState?.reset();
                    // Clear error when switching modes
                  });
                },
                child: Text(
                  _isRegistering
                      ? 'Already have an account? Sign In'
                      : 'Don\'t have an account? Register',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  bool _signingOut = false;
  bool _changingPassword = false;

  final _passwordFormKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  String? _currentPasswordError;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() {
      _signingOut = true;
    });
    try {
      await _authService.signOut();
    } catch (e) {
      debugPrint('Sign out failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign out failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _signingOut = false;
        });
      }
    }
  }

  Future<void> _changePassword() async {
    //remove below

    //remove above
    if (_passwordFormKey.currentState!.validate() != true) return;
    setState(() {
      _changingPassword = true;
      _currentPasswordError = null;
    });
    try {
      await _authService.changePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _currentPasswordController.clear();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        setState(() {
          _currentPasswordError = 'Current password is incorrect';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Change password failed. '
              'Check your connection and permissions.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Change password failed. Check your connection and permissions.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _changingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Center(
        child: Form(
          key: _passwordFormKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Signed in as: ${user?.email ?? 'Unknown'}'),
              const SizedBox(height: 20),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  errorText: _currentPasswordError,
                ),
                onChanged: (_) {
                  if (_currentPasswordError != null) {
                    setState(() => _currentPasswordError = null);
                  }
                },
                validator: (value) {
                  final currentPassword = value?.trim() ?? '';
                  if (currentPassword.isEmpty) {
                    return 'Current password is required to change password';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
                validator: (value) {
                  final newPassword = value?.trim() ?? '';
                  if (newPassword.isEmpty) {
                    return 'New password is required';
                  }
                  if (newPassword.length < 6) {
                    return 'New password must be at least 6 characters long';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                ),
                validator: (value) {
                  final confirmPassword = value?.trim() ?? '';
                  final newPassword = _newPasswordController.text.trim();
                  if (confirmPassword.isEmpty) {
                    return 'Please confirm your new password';
                  }
                  if (confirmPassword != newPassword) {
                    return 'Passwords do not match';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: _changingPassword ? null : _changePassword,
                child: Text(
                  _changingPassword
                      ? 'Changing password...'
                      : 'Change Password',
                ),
              ),
              ElevatedButton(
                onPressed: _signingOut ? null : _signOut,
                child: Text(_signingOut ? 'Signing out...' : 'Sign Out'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProductPage(),
                    ),
                  );
                },
                child: const Text('Go to Product Manager'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final _products = FirebaseFirestore.instance.collection('products');
  late final _productStream = _products.snapshots();
  String _searchQuery = '';

  final _searchController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _createOrUpdate([
    QueryDocumentSnapshot<Map<String, dynamic>>? document,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) =>
          ProductEditor(products: _products, document: document),
    );
  }

  Future<void> _deleteProduct(String id) async {
    // TODO: Await deletion by ID; report failures, not false success.
    try {
      await _products.doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully.')),
      );
    } on FirebaseException catch (error) {
      debugPrint('Product delete failed (${error.code}): ${error.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Delete failed (${error.code}). '
            'Check your connection and permissions.',
          ),
        ),
      );
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Autumn Product Manager')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search products',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Min price',
                      prefixText: '\$',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Max price',
                      prefixText: '\$',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _minPriceController.clear();
                      _maxPriceController.clear();
                      _searchQuery = '';
                    });
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Products could not load. Check connection and permissions.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final minText = _minPriceController.text.trim();
                final maxText = _maxPriceController.text.trim();
                final minPrice = double.tryParse(minText);
                final maxPrice = double.tryParse(maxText);

                if ((minText.isNotEmpty && minPrice == null) ||
                    (maxText.isNotEmpty && maxPrice == null)) {
                  return const Center(
                    child: Text('Enter valid numbers for min/max price.'),
                  );
                }
                if (minPrice != null &&
                    maxPrice != null &&
                    minPrice > maxPrice) {
                  return const Center(
                    child: Text('Min price cannot be greater than max price.'),
                  );
                }
                final documents = snapshot.data!.docs.where((document) {
                  final data = document.data();
                  final name = data['name'];
                  final price = data['price'];
                  if (name is! String || price is! num) {
                    return false;
                  }
                  final matchesName = name.trim().toLowerCase().contains(
                    _searchQuery,
                  );
                  final matchesMinPrice = minPrice == null || price >= minPrice;
                  final matchesMaxPrice = maxPrice == null || price <= maxPrice;
                  return matchesName && matchesMinPrice && matchesMaxPrice;
                }).toList();
                if (documents.isEmpty) {
                  return const Center(
                    child: Text('No products match the search criteria.'),
                  );
                }
                return ListView.builder(
                  itemCount: documents.length,
                  itemBuilder: (context, index) {
                    final document = documents[index];
                    final data = document.data();
                    final name = data['name'];
                    final price = data['price'];
                    if (name is! String ||
                        name.trim().isEmpty ||
                        price is! num ||
                        !price.isFinite ||
                        price < 0) {
                      return ListTile(
                        title: Text(
                          'Invalid product ${document.id}: check name/price types.',
                        ),
                      );
                    }
                    return Card(
                      child: ListTile(
                        title: Text(name),
                        subtitle: Text(
                          '${price.toStringAsFixed(2)}\nID: ${document.id}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Edit product',
                              icon: const Icon(Icons.edit),
                              onPressed: () => _createOrUpdate(document),
                            ),
                            IconButton(
                              tooltip: 'Delete product',
                              icon: const Icon(Icons.delete),
                              onPressed: () => _deleteProduct(document.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        tooltip: 'Create product',
        onPressed: () => _createOrUpdate(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ProductEditor extends StatefulWidget {
  const ProductEditor({super.key, required this.products, this.document});

  final CollectionReference<Map<String, dynamic>> products;
  final QueryDocumentSnapshot<Map<String, dynamic>>? document;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.document?.data()['name'] as String? ?? '',
  );
  late final _price = TextEditingController(
    text: widget.document?.data()['price']?.toString() ?? '',
  );
  var _saving = false;
  String? _saveError;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final data = <String, Object>{
      'name': _name.text.trim(),
      'price': double.parse(_price.text.trim()),
    };
    try {
      final document = widget.document;
      if (document == null) {
        await widget.products.add(data);
      } else {
        await widget.products.doc(document.id).update(data);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      debugPrint('Product save failed (${error.code}): ${error.message}');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError =
            'Save failed (${error.code}). '
            'Check your connection and permissions.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.document == null ? 'Create product' : 'Edit product',
                ),
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a product name'
                      : null,
                ),
                TextFormField(
                  controller: _price,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price'),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    return amount == null || !amount.isFinite || amount < 0
                        ? 'Enter a finite price of zero or more'
                        : null;
                  },
                ),
                if (_saveError != null)
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (_saving)
                  const Text(
                    'Awaiting server acknowledgement. If offline, reconnect. '
                    'This editor stays open until the write succeeds or fails.',
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save'),
                ),
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
