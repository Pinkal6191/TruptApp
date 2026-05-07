import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import '../../../core/models/user_model.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterRole = 'All';
  bool _showOnlyPending = false;

  Future<void> _deleteUser(String uid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: const Text('This will permanently remove the user from the database. Note: This does not delete the Auth account.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(uid).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User deleted successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _toggleStatus(String uid, bool currentStatus) async {
    try {
      await _firestore.collection('users').doc(uid).update({'isActive': !currentStatus});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _approveUser(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({'isApproved': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showUserForm({UserModel? user}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => UserFormSheet(
        user: user,
        onSaved: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserForm(),
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterRole,
                        decoration: const InputDecoration(
                          labelText: 'Filter Role',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: ['All', 'admin', 'distributor', 'partner']
                            .map((role) => DropdownMenuItem(value: role, child: Text(role.toUpperCase())))
                            .toList(),
                        onChanged: (val) => setState(() => _filterRole = val!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Pending Approval'),
                      selected: _showOnlyPending,
                      onSelected: (val) => setState(() => _showOnlyPending = val),
                      selectedColor: Colors.teal.withOpacity(0.2),
                      checkmarkColor: Colors.teal,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                var users = snapshot.data!.docs.map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();

                // Apply Filters
                if (_filterRole != 'All') {
                  users = users.where((u) => u.role == _filterRole).toList();
                }
                if (_showOnlyPending) {
                  users = users.where((u) => !u.isApproved).toList();
                }

                if (users.isEmpty) {
                  return const Center(child: Text('No users found matching filters'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return UserCard(
                      user: user,
                      onDelete: () => _deleteUser(user.uid),
                      onToggleStatus: () => _toggleStatus(user.uid, user.isActive),
                      onApprove: () => _approveUser(user.uid),
                      onEdit: () => _showUserForm(user: user),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;
  final VoidCallback onApprove;
  final VoidCallback onEdit;

  const UserCard({
    super.key,
    required this.user,
    required this.onDelete,
    required this.onToggleStatus,
    required this.onApprove,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF1E3A8A).withOpacity(0.1),
                  child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(), style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${user.role.toUpperCase()} • ${user.mobile}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    user.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(color: user.isActive ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!user.isApproved)
                  TextButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Approve'),
                    style: TextButton.styleFrom(foregroundColor: Colors.teal),
                  ),
                TextButton.icon(
                  onPressed: onToggleStatus,
                  icon: Icon(user.isActive ? Icons.block : Icons.check_circle_outline, size: 18),
                  label: Text(user.isActive ? 'Deactivate' : 'Activate'),
                  style: TextButton.styleFrom(foregroundColor: user.isActive ? Colors.orange : Colors.green),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class UserFormSheet extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onSaved;

  const UserFormSheet({super.key, this.user, required this.onSaved});

  @override
  State<UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _passController;
  late String _role;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _mobileController = TextEditingController(text: widget.user?.mobile ?? '');
    _emailController = TextEditingController();
    _passController = TextEditingController();
    _role = widget.user?.role ?? 'partner';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (widget.user == null) {
        // Create New User
        if (_emailController.text.isEmpty || _passController.text.isEmpty) {
          throw Exception('Email and Password are required for new users');
        }

        // Initialize secondary Firebase App to create user without logging out admin
        FirebaseApp secondaryApp = await Firebase.initializeApp(
          name: 'SecondaryApp',
          options: Firebase.app().options,
        );

        UserCredential userCredential = await FirebaseAuth.instanceFor(app: secondaryApp).createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passController.text.trim(),
        );

        final newUser = UserModel(
          uid: userCredential.user!.uid,
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          role: _role,
          isApproved: true, // Admin created users are pre-approved
          isActive: true,
        );

        await FirebaseFirestore.instance.collection('users').doc(newUser.uid).set(newUser.toMap());
        await secondaryApp.delete(); // Important to delete the secondary app
      } else {
        // Update Existing User
        final updatedUser = UserModel(
          uid: widget.user!.uid,
          name: _nameController.text.trim(),
          mobile: _mobileController.text.trim(),
          role: _role,
          isApproved: widget.user!.isApproved,
          isActive: widget.user!.isActive,
          customPrices: widget.user!.customPrices,
        );
        await FirebaseFirestore.instance.collection('users').doc(updatedUser.uid).update(updatedUser.toMap());
      }

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.user == null ? 'User created' : 'User updated'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.user == null ? 'Create New User' : 'Edit User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              if (widget.user == null) ...[
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email ID', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passController,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
              ],
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                items: ['admin', 'distributor', 'partner']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase())))
                    .toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(widget.user == null ? 'Create User' : 'Update User'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
