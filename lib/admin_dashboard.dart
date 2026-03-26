import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart'; // Imports the global models from main.dart

/// --- LOCAL NOTIFICATION HELPER FOR ADMIN DASHBOARD ---
Future<void> sendNotification(String userId, String title, String message, String type) async {
  await FirebaseFirestore.instance.collection('notifications').add({
    'userId': userId, // Use "ALL" for global broadcasts
    'title': title,
    'message': message,
    'type': type,
    'timestamp': FieldValue.serverTimestamp(),
    'isRead': false,
  });
}

/// ============================================================================
/// 💻 ADMIN DASHBOARD (WEB / PC ONLY)
/// ============================================================================
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<String> _menuItems = [
    "Dashboard", 
    "User Approvals", 
    "Machines", 
    "Bookings", 
    "Projects", 
    "Maintenance", 
    "Events", 
    "Grievances",
    "Leaderboard",
    "Analytics"
  ];

  final List<IconData> _menuIcons = [
    Icons.dashboard_rounded, 
    Icons.how_to_reg_rounded, 
    Icons.precision_manufacturing_rounded, 
    Icons.event_available_rounded, 
    Icons.assignment_rounded, 
    Icons.build_rounded, 
    Icons.event_note_rounded, 
    Icons.report_problem_rounded, 
    Icons.emoji_events_rounded,
    Icons.analytics_rounded
  ];

  @override
  void initState() {
    super.initState();
    _seedDatabase();
  }

  Future<void> _seedDatabase() async {
    final snap = await FirebaseFirestore.instance.collection('machines').limit(1).get();
    if (snap.docs.isEmpty) {
      for (var m in AppData.allMachines) {
        await FirebaseFirestore.instance.collection('machines').doc(m.name).set({
          'name': m.name, 
          'status': m.status, 
          'imagePath': m.imagePath,
        });
      }
    }
    final eventSnap = await FirebaseFirestore.instance.collection('events').limit(1).get();
    if (eventSnap.docs.isEmpty) {
      for (var e in AppData.labEvents) {
        await FirebaseFirestore.instance.collection('events').add({
          'title': e.title, 
          'date': e.date, 
          'time': e.time, 
          'participants': e.participants, 
          'description': e.description, 
          'location': e.location, 
          'createdAt': FieldValue.serverTimestamp()
        });
      }
    }
  }

  Widget _getAdminScreen() {
    switch (_selectedIndex) {
      case 0: return const AdminHomeTab();
      case 1: return const AdminUserApprovalsTab();
      case 2: return AdminMachinesTab(onUpdate: () => setState((){})); 
      case 3: return const AdminBookingsTab();
      case 4: return const AdminProjectsTab();
      case 5: return const AdminMaintenanceTab(); 
      case 6: return AdminEventsTab(onUpdate: () => setState((){}));
      case 7: return const AdminGrievancesTab(); 
      case 8: return const AdminLeaderboardTab();
      case 9: return const AdminAnalyticsTab();
      default: return const AdminHomeTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Row(
        children: [
          Container(
            width: 260,
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  height: 80,
                  color: primaryColor,
                  alignment: Alignment.center,
                  child: const Text(
                    "IDEA Lab Admin", 
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _selectedIndex == index;
                      return ListTile(
                        leading: Icon(
                          _menuIcons[index], 
                          color: isSelected ? primaryColor : Colors.grey.shade600
                        ),
                        title: Text(
                          _menuItems[index], 
                          style: TextStyle(
                            color: isSelected ? primaryColor : Colors.grey.shade800, 
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
                          )
                        ),
                        selected: isSelected,
                        selectedTileColor: primaryColor.withOpacity(0.1),
                        onTap: () => setState(() => _selectedIndex = index),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text("Logout", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context, 
                        MaterialPageRoute(builder: (context) => const WelcomeScreen())
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 80,
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _menuItems[_selectedIndex], 
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade800)
                      ),
                      Row(
                        children: [
                          Icon(Icons.admin_panel_settings, color: primaryColor, size: 32),
                          const SizedBox(width: 8),
                          const Text("System Administrator", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: _getAdminScreen(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// --- ADMIN TAB: DASHBOARD ---
class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            int totalUsers = snapshot.data?.docs.where((d) => (d.data() as Map)['role'] != 'admin').length ?? 0;
            int pendingUsers = snapshot.data?.docs.where((d) => (d.data() as Map)['status'] == 'pending_approval' && (d.data() as Map)['role'] != 'admin').length ?? 0;

            return Row(
              children: [
                Expanded(child: _buildStatCard("Total Registered Users", totalUsers.toString(), Icons.group_rounded, primaryColor)),
                const SizedBox(width: 24),
                Expanded(child: _buildStatCard("Pending Approvals", pendingUsers.toString(), Icons.how_to_reg_rounded, Colors.orange)),
              ],
            );
          }
        ),
        const SizedBox(height: 32),
        Text("Recent Bookings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: Colors.grey.shade200)
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bookings').orderBy('createdAt', descending: true).limit(10).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No recent bookings."));
                
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.1), 
                        child: Icon(Icons.precision_manufacturing, color: primaryColor)
                      ),
                      title: Text(data['machineName'] ?? 'Unknown Machine', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("User ID: ${data['userId']} • Project: ${data['projectName']}"),
                      trailing: Text(
                        "${data['date']} | ${data['timeSlot']}", 
                        style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16), 
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), 
            child: Icon(icon, color: color, size: 32)
          ),
          const SizedBox(width: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.black87, fontSize: 32, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }
}

/// --- ADMIN TAB: USER APPROVALS ---
class AdminUserApprovalsTab extends StatelessWidget {
  const AdminUserApprovalsTab({super.key});

  void _updateStatus(String uid, String status) async {
    if (status == 'approved') {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data() as Map<String, dynamic>? ?? {};
      Map<String, dynamic> achievements = data['achievements'] ?? {};
      
      if (achievements['reg'] != true) {
        achievements['reg'] = true;
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'status': status,
          'points': FieldValue.increment(10),
          'achievements': achievements
        });
        return;
      }
    }
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'status': status});
  }

  void _showProfileModal(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Student Profile Details"),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data['profileImageUrl'] != null) 
                  Center(child: Image.network(data['profileImageUrl'], height: 100)),
                const SizedBox(height: 16),
                Text("Name: ${data['firstName']} ${data['lastName']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("Email: ${data['email']}"),
                Text("Phone: ${data['phone']}"),
                Text("College: ${data['college']}"),
                Text("Department: ${data['department']} (${data['year']})"),
                Text("PRN: ${data['idNumber']}"),
                Text("IDEA ID: ${data['uniqueId']}"),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
        ],
      ),
    );
  }

  Widget _buildUserList(String targetStatus) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>?;
          if (data == null) return false;
          return data['status'] == targetStatus && data['role'] != 'admin';
        }).toList();
        
        if (docs.isEmpty) return const Center(child: Text("No users in this category."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String uid = docs[index].id;
            return Card(
              color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(backgroundImage: data['profileImageUrl'] != null ? NetworkImage(data['profileImageUrl']) : null, child: data['profileImageUrl'] == null ? const Icon(Icons.person) : null),
                title: Text("${data['firstName']} ${data['lastName']} • ${data['college']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${data['department']} | PRN: ${data['idNumber']}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (targetStatus == 'pending_approval' || targetStatus == 'rejected') ElevatedButton(onPressed: () => _updateStatus(uid, 'approved'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("Approve", style: TextStyle(color: Colors.white))),
                    const SizedBox(width: 8),
                    if (targetStatus == 'pending_approval' || targetStatus == 'approved') ElevatedButton(onPressed: () => _updateStatus(uid, 'rejected'), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text("Reject", style: TextStyle(color: Colors.white))),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.visibility, color: Colors.blue), onPressed: () => _showProfileModal(context, data)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              tabs: [
                Tab(text: "Pending Users"), 
                Tab(text: "Approved Users"), 
                Tab(text: "Rejected Users")
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              children: [
                _buildUserList('pending_approval'),
                _buildUserList('approved'),
                _buildUserList('rejected'),
              ],
            ),
          )
        ],
      ),
    );
  }
}

/// --- ADMIN TAB: MACHINES ---
class AdminMachinesTab extends StatelessWidget {
  final VoidCallback onUpdate;
  const AdminMachinesTab({super.key, required this.onUpdate});

  void _editMachine(BuildContext context, String docId, Map<String, dynamic> data) {
    TextEditingController nameCtrl = TextEditingController(text: data['name']);
    String selectedStatus = data['status'] == "Available" ? "Available" : "Under Maintenance";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Machine"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl, 
              decoration: const InputDecoration(labelText: "Machine Name")
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              items: ["Available", "Under Maintenance"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (val) => selectedStatus = val!,
              decoration: const InputDecoration(labelText: "Status"),
            )
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel")
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('machines').doc(docId).update({
                'name': nameCtrl.text,
                'status': selectedStatus,
              });
              Navigator.pop(context);
            }, 
            child: const Text("Save")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('machines').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            Color statusColor = data['status'] == 'Available' ? const Color(0xFF2ECA7F) : const Color(0xFFE74C3C);

            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Image.asset(
                  data['imagePath'] ?? 'assets/laser_cutter.jpg', 
                  width: 80, 
                  fit: BoxFit.cover, 
                  errorBuilder: (c,e,s) => const Icon(Icons.precision_manufacturing, size: 40)
                ),
                title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                subtitle: Text("Status: ${data['status']}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _editMachine(context, docs[index].id, data), 
                      icon: const Icon(Icons.edit, size: 16), 
                      label: const Text("Edit")
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }
}

/// --- ADMIN TAB: BOOKINGS ---
class AdminBookingsTab extends StatelessWidget {
  const AdminBookingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No bookings recorded."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id; 
            
            return Card(
              color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text("${data['machineName']} • ${data['date']} (${data['timeSlot']})", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Project: ${data['projectName']}\nUser ID: ${data['userId']}"),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_forever, color: Colors.red),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('bookings').doc(docId).delete();
                  },
                ),
              ),
            );
          },
        );
      }
    );
  }
}

/// --- ADMIN TAB: PROJECTS ---
class AdminProjectsTab extends StatelessWidget {
  const AdminProjectsTab({super.key});

  void _showProjectDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['name'] ?? 'Project Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Status: ${data['isOngoing'] == true ? 'Ongoing' : 'Completed'}", style: TextStyle(fontWeight: FontWeight.bold, color: data['isOngoing'] == true ? Colors.blue : Colors.green)),
              const SizedBox(height: 12),
              Text("Description:\n${data['description'] ?? 'No description'}"),
              const SizedBox(height: 12),
              Text("Mentors: ${(data['mentors'] as List?)?.join(', ') ?? 'None'}"),
              const SizedBox(height: 12),
              const Text("Team Members:", style: TextStyle(fontWeight: FontWeight.bold)),
              ...(data['teamMembers'] as List<dynamic>? ?? []).map((t) => Text(" • ${t['name']} (${t['id']})")),
              if (data['imagePath'] != null && data['imagePath'].toString().startsWith('http')) ...[
                const SizedBox(height: 16),
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(data['imagePath'], height: 150, width: double.infinity, fit: BoxFit.cover)),
              ]
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('projects').orderBy('updatedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Total Projects: ${docs.length}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return GestureDetector(
                    onTap: () => _showProjectDetails(context, data),
                    child: Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['name'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 4),
                            Text("Created By UID: ${data['createdBy']}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }
    );
  }
}

/// --- ADMIN TAB: MAINTENANCE ---
class AdminMaintenanceTab extends StatelessWidget {
  const AdminMaintenanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('machines').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            bool isMaintenance = data['status'] != "Available";
            
            return Card(
              color: Colors.white,
              child: ListTile(
                leading: Image.asset(data['imagePath'] ?? 'assets/laser_cutter.jpg', width: 60, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.build)),
                title: Text(data['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isMaintenance ? "Under Maintenance" : "Available", style: TextStyle(color: isMaintenance ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Switch(
                      value: isMaintenance,
                      activeColor: Colors.red,
                      onChanged: (val) {
                        FirebaseFirestore.instance.collection('machines').doc(docs[index].id).update({
                          'status': val ? 'Under Maintenance' : 'Available'
                        });

                        // --- NEW NOTIFICATION TRIGGER: MACHINE STATUS ---
                        String newStatus = val ? 'Under Maintenance' : 'Available';
                        sendNotification(
                          "ALL", 
                          "Machine Status Update", 
                          "${data['name']} is now $newStatus.", 
                          "machine"
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    );
  }
}

/// --- ADMIN TAB: EVENTS ---
class AdminEventsTab extends StatelessWidget {
  final VoidCallback onUpdate;
  const AdminEventsTab({super.key, required this.onUpdate});

  void _showEventDialog(BuildContext context, {String? docId, Map<String, dynamic>? existingData}) {
    final titleCtrl = TextEditingController(text: existingData?['title'] ?? '');
    final dateCtrl = TextEditingController(text: existingData?['date'] ?? '');
    final timeCtrl = TextEditingController(text: existingData?['time'] ?? '');
    final descCtrl = TextEditingController(text: existingData?['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(docId == null ? "Add New Event" : "Edit Event"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Event Title")),
              TextField(controller: dateCtrl, decoration: const InputDecoration(labelText: "Date (e.g., 2024-10-15)")),
              TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: "Time (e.g., 10:00 AM)")),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: "Description"), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'title': titleCtrl.text, 'date': dateCtrl.text, 'time': timeCtrl.text, 'description': descCtrl.text,
                'participants': existingData?['participants'] ?? 'All', 'location': existingData?['location'] ?? 'AICTE IDEA Lab, Pune', 'updatedAt': FieldValue.serverTimestamp(),
              };
              if (docId == null) {
                data['createdAt'] = FieldValue.serverTimestamp();
                await FirebaseFirestore.instance.collection('events').add(data);
              } else {
                await FirebaseFirestore.instance.collection('events').doc(docId).update(data);
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(onPressed: () => _showEventDialog(context), icon: const Icon(Icons.add), label: const Text("Add Event")),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('events').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No events scheduled."));

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  String docId = docs[index].id;
                  
                  return Card(
                    color: Colors.white,
                    child: ListTile(
                      title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${data['date']} | ${data['time']}\n${data['description']}"),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showEventDialog(context, docId: docId, existingData: data)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => FirebaseFirestore.instance.collection('events').doc(docId).delete()),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          ),
        ),
      ],
    );
  }
}

/// --- ADMIN TAB: GRIEVANCES ---
class AdminGrievancesTab extends StatelessWidget {
  const AdminGrievancesTab({super.key});

  void _showGrievanceDetails(BuildContext context, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Grievance: ${data['machineName'] ?? 'Unknown'}"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Reported by User ID: ${data['userId'] ?? 'Unknown'}"),
              const SizedBox(height: 8),
              Text("Date: ${(data['timestamp'] as Timestamp?)?.toDate().toString() ?? 'Unknown'}"),
              const SizedBox(height: 16),
              const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(data['description'] ?? 'No details provided.'),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('issues').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text("No grievances reported by students."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String status = data['status'] ?? 'Pending';
            Color statusColor = status == 'Completed' ? Colors.green : (status == 'Processing' ? Colors.blue : Colors.orange);

            return GestureDetector(
              onTap: () => _showGrievanceDetails(context, data),
              child: Card(
                color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(Icons.report_problem, color: statusColor),
                  title: Text(data['machineName'] ?? 'Unknown Machine', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor)),
                        child: DropdownButton<String>(
                          value: status,
                          underline: const SizedBox(),
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 13),
                          icon: Icon(Icons.arrow_drop_down, color: statusColor),
                          items: ['Pending', 'Processing', 'Completed'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) {
                            FirebaseFirestore.instance.collection('issues').doc(docs[index].id).update({'status': val});
                            
                            // --- NEW NOTIFICATION TRIGGER: GRIEVANCE UPDATE ---
                            if (val != 'Pending') {
                              sendNotification(
                                data['userId'], 
                                "Grievance Update", 
                                "Your issue regarding ${data['machineName']} is now marked as $val.", 
                                "grievance"
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                        tooltip: "Delete Grievance",
                        onPressed: () => FirebaseFirestore.instance.collection('issues').doc(docs[index].id).delete(),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );
  }
}

/// --- ADMIN TAB: LEADERBOARD ---
class AdminLeaderboardTab extends StatelessWidget {
  const AdminLeaderboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').orderBy('points', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>?;
          return data != null && data['role'] != 'admin';
        }).toList();
        
        if (docs.isEmpty) return const Center(child: Text("No students found."));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            return Card(
              color: Colors.white, margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  child: Text("#${index + 1}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ),
                title: Text("${data['firstName']} ${data['lastName']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${data['college']} | PRN: ${data['idNumber']}"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                  child: Text("${data['points'] ?? 0} pts", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            );
          },
        );
      }
    );
  }
}

/// --- ADMIN TAB: ANALYTICS ---
class AdminAnalyticsTab extends StatelessWidget {
  const AdminAnalyticsTab({super.key});

  Future<Map<String, dynamic>> fetchAnalyticsData() async {
    final usersSnap = await FirebaseFirestore.instance.collection('users').get();
    final machinesSnap = await FirebaseFirestore.instance.collection('machines').get();
    final bookingsSnap = await FirebaseFirestore.instance.collection('bookings').get();
    final projectsSnap = await FirebaseFirestore.instance.collection('projects').get();
    final issuesSnap = await FirebaseFirestore.instance.collection('issues').get();

    // 1. User Analytics
    int totalUsers = 0, pendingUsers = 0, approvedUsers = 0, rejectedUsers = 0;
    Map<String, int> deptCounts = {};
    for (var doc in usersSnap.docs) {
      var data = doc.data();
      if (data['role'] != 'admin') {
        totalUsers++;
        String status = data['status'] ?? 'pending_approval';
        if (status == 'approved') approvedUsers++;
        else if (status == 'rejected') rejectedUsers++;
        else pendingUsers++;

        String dept = data['department'] ?? 'Unknown';
        deptCounts[dept] = (deptCounts[dept] ?? 0) + 1;
      }
    }
    String topDept = deptCounts.isNotEmpty ? (deptCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key : "N/A";

    // 2. Machine Analytics
    int totalMachines = machinesSnap.docs.length;
    int availableMachines = 0, maintenanceMachines = 0;
    for (var doc in machinesSnap.docs) {
      if (doc.data()['status'] == 'Available') availableMachines++;
      else maintenanceMachines++;
    }

    // 3. Booking Analytics
    int totalBookings = bookingsSnap.docs.length;
    Map<String, int> machineBookingCounts = {};
    for (var doc in bookingsSnap.docs) {
      String mName = doc.data()['machineName'] ?? 'Unknown';
      machineBookingCounts[mName] = (machineBookingCounts[mName] ?? 0) + 1;
    }
    String mostBookedMachine = "N/A";
    if (machineBookingCounts.isNotEmpty) {
      var sorted = machineBookingCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      mostBookedMachine = "${sorted.first.key} (${sorted.first.value})";
    }

    // 4. Project Analytics
    int totalProjects = projectsSnap.docs.length;
    int ongoingProjects = 0, completedProjects = 0;
    for (var doc in projectsSnap.docs) {
      if (doc.data()['isOngoing'] == true) ongoingProjects++;
      else completedProjects++;
    }

    // 5. Issue Analytics
    int totalIssues = issuesSnap.docs.length;
    int pendingIssues = 0, resolvedIssues = 0;
    Map<String, int> issueMachineCounts = {};
    for (var doc in issuesSnap.docs) {
      var data = doc.data();
      if (data['status'] == 'Completed') resolvedIssues++;
      else pendingIssues++;

      String mName = data['machineName'] ?? 'Unknown';
      issueMachineCounts[mName] = (issueMachineCounts[mName] ?? 0) + 1;
    }
    String mostIssuesMachine = "N/A";
    if (issueMachineCounts.isNotEmpty) {
      var sorted = issueMachineCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      mostIssuesMachine = "${sorted.first.key} (${sorted.first.value})";
    }

    return {
      'totalUsers': totalUsers, 'approvedUsers': approvedUsers, 'pendingUsers': pendingUsers, 'rejectedUsers': rejectedUsers, 'topDept': topDept,
      'totalMachines': totalMachines, 'availableMachines': availableMachines, 'maintenanceMachines': maintenanceMachines,
      'totalBookings': totalBookings, 'mostBookedMachine': mostBookedMachine,
      'totalProjects': totalProjects, 'ongoingProjects': ongoingProjects, 'completedProjects': completedProjects,
      'totalIssues': totalIssues, 'pendingIssues': pendingIssues, 'resolvedIssues': resolvedIssues, 'mostIssuesMachine': mostIssuesMachine,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchAnalyticsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(child: Text("Error loading analytics data."));
        }

        final data = snapshot.data!;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Lab Analytics Overview", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Update this URL to your specific Looker Studio Link if desired!
                      final Uri url = Uri.parse('https://lookerstudio.google.com/');
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        debugPrint("Could not launch $url");
                      }
                    }, 
                    icon: const Icon(Icons.open_in_new, size: 16), 
                    label: const Text("Advanced Analytics (Looker)"),
                  )
                ],
              ),
              const SizedBox(height: 24),

              _buildSectionHeader("👤 User Analytics"),
              Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _buildMetricCard("Total Students", data['totalUsers'].toString(), Icons.people, Colors.blue),
                  _buildMetricCard("Approved", data['approvedUsers'].toString(), Icons.check_circle, Colors.green),
                  _buildMetricCard("Pending", data['pendingUsers'].toString(), Icons.hourglass_empty, Colors.orange),
                  _buildMetricCard("Top Department", data['topDept'], Icons.school, Colors.purple),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionHeader("⚙️ Machine & Booking Analytics"),
              Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _buildMetricCard("Total Bookings", data['totalBookings'].toString(), Icons.event_available, Colors.teal),
                  _buildMetricCard("Most Booked", data['mostBookedMachine'], Icons.star, Colors.amber.shade600),
                  _buildMetricCard("Available Machines", data['availableMachines'].toString(), Icons.check, Colors.green),
                  _buildMetricCard("In Maintenance", data['maintenanceMachines'].toString(), Icons.build, Colors.redAccent),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionHeader("🚀 Project Analytics"),
              Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _buildMetricCard("Total Projects", data['totalProjects'].toString(), Icons.assignment, Colors.indigo),
                  _buildMetricCard("Ongoing Projects", data['ongoingProjects'].toString(), Icons.autorenew, Colors.blue),
                  _buildMetricCard("Completed Projects", data['completedProjects'].toString(), Icons.task_alt, Colors.green),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionHeader("⚠️ Issue & Maintenance Analytics"),
              Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _buildMetricCard("Total Issues", data['totalIssues'].toString(), Icons.report_problem, Colors.orange),
                  _buildMetricCard("Pending Issues", data['pendingIssues'].toString(), Icons.pending_actions, Colors.red),
                  _buildMetricCard("Resolved Issues", data['resolvedIssues'].toString(), Icons.check_circle_outline, Colors.green),
                  _buildMetricCard("Most Problematic", data['mostIssuesMachine'], Icons.warning, Colors.redAccent),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionHeader("🏢 Lab Usage (Hardware Dependencies)"),
              Wrap(
                spacing: 16, runSpacing: 16,
                children: [
                  _buildMetricCard("Total Lab Entries", "N/A", Icons.door_front_door, Colors.grey),
                  _buildMetricCard("Avg Time Spent", "N/A", Icons.timer, Colors.grey),
                  _buildMetricCard("Peak Usage Hour", "N/A", Icons.access_time_filled, Colors.grey),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text("*Lab Usage metrics require integration with physical RFID/QR Turnstile hardware logs.", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
              ),
              const SizedBox(height: 48),
            ],
          ),
        );
      }
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 20)),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.grey.shade900)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}