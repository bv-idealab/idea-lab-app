import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'firebase_options.dart';
import 'ai_chat_screen.dart'; 
import 'admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent, 
    statusBarIconBrightness: Brightness.light
  ));
  
  runApp(const IDEALabApp());
}

/// ----------------------------------------------------------------------------
/// GLOBAL STATE MANAGEMENT
/// ----------------------------------------------------------------------------
class UserModel {
  String firstName; 
  String lastName; 
  String email; 
  String phone; 
  String college;
  String course; 
  String year; 
  String department; 
  String idNumber; 
  String uniqueId; 
  String? profileImageUrl;
  int points;
  Map<String, dynamic> achievements;

  UserModel({
    required this.firstName, 
    required this.lastName, 
    required this.email, 
    required this.phone,
    required this.college, 
    required this.course, 
    required this.year, 
    required this.department,
    required this.idNumber, 
    required this.uniqueId, 
    this.profileImageUrl, 
    this.points = 0,
    this.achievements = const {},
  });
}

class TeamMember {
  String name; String id;
  TeamMember({
    required this.name, 
    required this.id
  });
}

class IssueReportModel {
  final String machineName; 
  final String description; 
  final DateTime timestamp; 
  final String status;

  IssueReportModel({
    required this.machineName, 
    required this.description, 
    required this.timestamp, 
    this.status = 'Pending',
  });
}

class EventModel {
  String title; 
  String date; 
  String time; 
  String participants; 
  String description; 
  String location;

  EventModel({
    required this.title, 
    required this.date, 
    required this.time, 
    required this.participants, 
    required this.description,
    this.location = "AICTE IDEA Lab, Bharati Vidyapeeth College of Engineering, Pune",
  });
}

class AchievementModel {
  String id; 
  String title; 
  String description; 
  int points; 
  bool isUnlocked;

  AchievementModel({
    required this.id, 
    required this.title, 
    required this.description, 
    required this.points, 
    this.isUnlocked = false
  });
}

class AppData {
  static late UserModel currentUser;

  static int get totalPoints => currentUser.points;

  static List<AchievementModel> get achievements {
    Map<String, dynamic> ach = currentUser.achievements;
    return [
      AchievementModel(id: 'reg', title: "Account Registered", description: "Awarded when your profile is approved.", points: 10, isUnlocked: ach['reg'] == true),
      AchievementModel(id: 'proj1', title: "First Project Created", description: "Awarded when you create your first project.", points: 20, isUnlocked: ach['proj1'] == true),
      AchievementModel(id: 'book1', title: "First Machine Booking", description: "Awarded for your first successful booking.", points: 20, isUnlocked: ach['book1'] == true),
      AchievementModel(id: 'proto1', title: "Innovation Starter", description: "Awarded when you complete your first project.", points: 50, isUnlocked: ach['proto1'] == true),
      AchievementModel(id: 'book5', title: "5 Machines Booked", description: "Awarded when you book five machines.", points: 30, isUnlocked: ach['book5'] == true),
    ];
  }

  static List<AchievementModel> checkNewAchievements() => [];

  static final List<EventModel> labEvents = [
    EventModel(title: "Faculty Development Program (FDP)", date: "Upcoming", time: "10:00 AM - 04:00 PM", participants: "Faculty", description: "Training on advanced lab equipment and pedagogy to enhance practical teaching skills."),
    EventModel(title: "Skilling Programs", date: "Multiple Dates", time: "11:00 AM - 05:00 PM", participants: "Students", description: "Hands-on technical training in embedded systems, IoT, PCB design, welding, and 3D printing."),
    EventModel(title: "Bootcamps", date: "Weekend", time: "09:00 AM - 06:00 PM", participants: "Students", description: "Intensive short-term workshops focused on rapid prototyping and project building."),
    EventModel(title: "Ideation Workshops", date: "Friday", time: "02:00 PM - 05:00 PM", participants: "Students", description: "Interactive brainstorming sessions for developing innovative and viable project ideas."),
  ];

  static final List<MachineStatusModel> allMachines = [
    MachineStatusModel(name: "Laser Cutter", status: "Available", statusColor: const Color(0xFF2ECA7F), imagePath: 'assets/laser_cutter.jpg'),
    MachineStatusModel(name: "Vinyl Cutter", status: "Available", statusColor: const Color(0xFF2ECA7F), imagePath: 'assets/vinyl_cutter.jpg'),
    MachineStatusModel(name: "3D Printer", status: "Available", statusColor: const Color(0xFF2ECA7F), imagePath: 'assets/3d_printer.jpg'),
    MachineStatusModel(name: "3D Scanner", status: "Available", statusColor: const Color(0xFF2ECA7F), imagePath: 'assets/3d_scanner.jpg'),
    MachineStatusModel(name: "CNC Router", status: "Not Available", buttonText: "Under Maintenance", statusColor: const Color(0xFFE74C3C), imagePath: 'assets/cnc_router.jpg'),
    MachineStatusModel(name: "Wood Lathe", status: "Available", statusColor: const Color(0xFF2ECA7F), imagePath: 'assets/wood_lathe.jpg'),
    MachineStatusModel(name: "PCB Milling Machine", status: "Not Available", buttonText: "Under Maintenance", statusColor: const Color(0xFFE74C3C), imagePath: 'assets/pcb_milling.jpg'),
    MachineStatusModel(name: "Raspberry Pi", status: "Available", statusColor: const Color(0xFF2ECA7F), imagePath: 'assets/raspberry_pi.jpg'),
    MachineStatusModel(name: "ESP 32", status: "Available", statusColor: const Color(0xFF2ECA7F), imagePath: 'assets/esp_32.jpg'),
    MachineStatusModel(name: "Beagle Board", status: "Available", statusColor: const Color(0xFF2ECA7F), imagePath: 'assets/beagle_board.jpg'),
  ];
}

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final bool isOngoing;
  final String? imagePath;
  final List<String> mentors;
  final List<TeamMember> teamMembers;

  ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isOngoing,
    this.imagePath,
    required this.mentors,
    required this.teamMembers,
  });
}

class BookingModel {
  final String id;
  final String machineName;
  final String projectName;
  final String date;
  final String timeSlot;
  final DateTime createdAt;

  BookingModel({
    required this.id,
    required this.machineName,
    required this.projectName,
    required this.date,
    required this.timeSlot,
    required this.createdAt,
  });
}

class MachineStatusModel {
  String name; 
  String status; 
  String? buttonText; 
  Color statusColor; 
  String imagePath;

  MachineStatusModel({
    required this.name, 
    required this.status, 
    this.buttonText, 
    required this.statusColor, 
    required this.imagePath
  });

  String get effectiveButtonText => buttonText ?? status;
}

/// ----------------------------------------------------------------------------
/// MAIN APP WIDGET
/// ----------------------------------------------------------------------------
class IDEALabApp extends StatelessWidget {
  const IDEALabApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = HSLColor.fromAHSL(1.0, 215, 0.85, 0.50).toColor();
    return MaterialApp(
      title: 'AICTE IDEA Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor, 
        scaffoldBackgroundColor: const Color(0xFFF4F7FB), 
        fontFamily: 'Roboto', 
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor), 
        useMaterial3: true
      ),
      home: const AuthWrapper(), 
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
              
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final data = userSnapshot.data!.data() as Map<String, dynamic>;
                final role = data['role']?.toString().trim().toLowerCase() ?? 'student';
                final status = data['status']?.toString().trim().toLowerCase() ?? 'pending_approval';
                
                if (kIsWeb) {
                  if (role == 'admin') return const AdminDashboardScreen();
                  
                  if (defaultTargetPlatform == TargetPlatform.android) {
                    FirebaseAuth.instance.signOut();
                    return const WelcomeScreen(); 
                  }

                  if (status == 'pending_approval' || status == 'rejected') {
                    return const ProfileSubmittedScreen();
                  }

                  AppData.currentUser = UserModel(
                    firstName: data['firstName'] ?? '', 
                    lastName: data['lastName'] ?? '', 
                    email: data['email'] ?? '',
                    phone: data['phone'] ?? '', 
                    college: data['college'] ?? '', 
                    course: data['course'] ?? '',
                    year: data['year'] ?? '', 
                    department: data['department'] ?? '', 
                    idNumber: data['idNumber'] ?? '',
                    uniqueId: data['uniqueId'] ?? '', 
                    profileImageUrl: data['profileImageUrl'], 
                    points: data['points'] ?? 0,
                    achievements: data['achievements'] ?? {},
                  );
                  return const MainDashboard();
                } else {
                  if (role == 'admin') {
                    FirebaseAuth.instance.signOut();
                    return const WelcomeScreen(); 
                  }

                  if (status == 'pending_approval' || status == 'rejected') {
                    return const ProfileSubmittedScreen();
                  }

                  AppData.currentUser = UserModel(
                    firstName: data['firstName'] ?? '', 
                    lastName: data['lastName'] ?? '', 
                    email: data['email'] ?? '',
                    phone: data['phone'] ?? '', 
                    college: data['college'] ?? '', 
                    course: data['course'] ?? '',
                    year: data['year'] ?? '', 
                    department: data['department'] ?? '', 
                    idNumber: data['idNumber'] ?? '',
                    uniqueId: data['uniqueId'] ?? '', 
                    profileImageUrl: data['profileImageUrl'], 
                    points: data['points'] ?? 0,
                    achievements: data['achievements'] ?? {},
                  );
                  return const MainDashboard();
                }
              }
              return const WelcomeScreen(); 
            }
          );
        }
        return const WelcomeScreen(); 
      }
    );
  }
}

/// ----------------------------------------------------------------------------
/// WELCOME SCREEN
/// ----------------------------------------------------------------------------
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  late final Animation<double> _titleFade;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _titleFade = CurvedAnimation(parent: _fadeController, curve: const Interval(0.2, 0.6, curve: Curves.easeOut));
    _subtitleFade = CurvedAnimation(parent: _fadeController, curve: const Interval(0.5, 0.8, curve: Curves.easeOut));
    _buttonFade = CurvedAnimation(parent: _fadeController, curve: const Interval(0.7, 1.0, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() { _floatController.dispose(); _pulseController.dispose(); _fadeController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final lightPrimaryColor = HSLColor.fromAHSL(1.0, 215, 0.80, 0.92).toColor();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TopLogoImage(assetPath: 'assets/imageA.png', size: 80, placeholderLabel: 'A', fallbackTextColor: primaryColor, fallbackBgColor: primaryColor.withOpacity(0.1)),
                  TopLogoImage(assetPath: 'assets/imageB.png', size: 80, placeholderLabel: 'B', fallbackTextColor: primaryColor, fallbackBgColor: primaryColor.withOpacity(0.1)),
                ],
              ),
            ),
            const Spacer(flex: 2),
            AnimatedBuilder(
              animation: Listenable.merge([_floatController, _pulseController]),
              builder: (context, child) {
                final floatOffset = Offset(0, 15 * _floatController.value - 7.5);
                final pulseScale = 1.0 + (_pulseController.value * 0.15);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.scale(scale: pulseScale, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: lightPrimaryColor))),
                    Transform.translate(offset: floatOffset, child: TopLogoImage(assetPath: 'assets/imageC.png', size: 180, placeholderLabel: 'C', fallbackTextColor: primaryColor, fallbackBgColor: Colors.transparent)),
                  ],
                );
              },
            ),
            const Spacer(flex: 2),
            FadeTransition(opacity: _titleFade, child: Column(children: [Text("AICTE-IDEA Lab", textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 0.5, height: 1.2)), const SizedBox(height: 4), Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Text("Bharati Vidyapeeth College Of Engineering, Pune", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade800, height: 1.2)))])),
            const SizedBox(height: 24),
            FadeTransition(opacity: _subtitleFade, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32.0), child: Text("Innovate • Build • Experiment\nTurn your ideas into working prototypes.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey.shade600, height: 1.5)))),
            const Spacer(flex: 3),
            FadeTransition(opacity: _buttonFade, child: Padding(padding: const EdgeInsets.only(bottom: 48.0), child: AnimatedScaleButton(text: "Start Innovating", color: primaryColor, width: MediaQuery.of(context).size.width * 0.68, onPressed: () { Navigator.push(context, PageRouteBuilder(pageBuilder: (context, a, sa) => const LoginScreen(), transitionsBuilder: (context, a, sa, child) => FadeTransition(opacity: a, child: child))); }))),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// LOGIN SCREEN
/// ----------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter both email and password"), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        
        final String role = data['role']?.toString().trim().toLowerCase() ?? 'student';
        final String status = data['status']?.toString().trim().toLowerCase() ?? 'pending_approval';

        if (kIsWeb) {
          if (role == 'admin') {
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
          } else {
            if (defaultTargetPlatform == TargetPlatform.android) {
              await FirebaseAuth.instance.signOut();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Android users must use the downloaded APK app."), backgroundColor: Colors.redAccent, duration: Duration(seconds: 4)));
              return;
            }

            if (status == 'pending_approval' || status == 'rejected') {
              await FirebaseAuth.instance.signOut();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account not approved yet. Please wait for admin approval."), backgroundColor: Colors.redAccent, duration: Duration(seconds: 4)));
              return;
            }

            AppData.currentUser = UserModel(
              firstName: data['firstName'] ?? '', 
              lastName: data['lastName'] ?? '', 
              email: data['email'] ?? email,
              phone: data['phone'] ?? '', 
              college: data['college'] ?? '', 
              course: data['course'] ?? '',
              year: data['year'] ?? '', 
              department: data['department'] ?? '', 
              idNumber: data['idNumber'] ?? '',
              uniqueId: data['uniqueId'] ?? '', 
              profileImageUrl: data['profileImageUrl'], 
              points: data['points'] ?? 0, 
              achievements: data['achievements'] ?? {},
            );
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainDashboard()));
          }
        } else {
          if (role == 'admin') {
            await FirebaseAuth.instance.signOut();
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Access Denied: Admins must use the Web Dashboard on a PC."), backgroundColor: Colors.redAccent, duration: Duration(seconds: 4)));
          } else {
            if (status == 'pending_approval' || status == 'rejected') {
              await FirebaseAuth.instance.signOut();
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account not approved yet. Please wait for admin approval."), backgroundColor: Colors.redAccent, duration: Duration(seconds: 4)));
              return;
            }

            AppData.currentUser = UserModel(
              firstName: data['firstName'] ?? '', 
              lastName: data['lastName'] ?? '', 
              email: data['email'] ?? email,
              phone: data['phone'] ?? '', 
              college: data['college'] ?? '', 
              course: data['course'] ?? '',
              year: data['year'] ?? '', 
              department: data['department'] ?? '', 
              idNumber: data['idNumber'] ?? '',
              uniqueId: data['uniqueId'] ?? '', 
              profileImageUrl: data['profileImageUrl'], 
              points: data['points'] ?? 0, 
              achievements: data['achievements'] ?? {},
            );
            if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainDashboard()));
          }
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User profile not found in database."), backgroundColor: Colors.redAccent));
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Login failed"), backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TopLogoImage(assetPath: 'assets/imageA.png', size: 80, placeholderLabel: 'A', fallbackTextColor: primaryColor, fallbackBgColor: primaryColor.withOpacity(0.1)),
                      TopLogoImage(assetPath: 'assets/imageB.png', size: 80, placeholderLabel: 'B', fallbackTextColor: primaryColor, fallbackBgColor: primaryColor.withOpacity(0.1)),
                    ],
                  ),
                ),
                const Spacer(),
                Text("Idea Lab", textAlign: TextAlign.center, style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 1.0)),
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email ID",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey.shade600),
                    ),
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  AnimatedScaleButton(
                    text: "Login",
                    color: primaryColor,
                    width: MediaQuery.of(context).size.width * 0.75,
                    onPressed: _login,
                  ),
                const SizedBox(height: 16),
                if (!_isLoading)
                  AnimatedScaleButton(
                    text: "Register",
                    color: primaryColor.withOpacity(0.8),
                    width: MediaQuery.of(context).size.width * 0.75,
                    onPressed: () {
                      Navigator.push(context, PageRouteBuilder(pageBuilder: (context, a, sa) => const ProfileCreationScreen(), transitionsBuilder: (context, a, sa, child) => FadeTransition(opacity: a, child: child)));
                    },
                  ),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// PROFILE CREATION SCREEN
/// ----------------------------------------------------------------------------
class ProfileCreationScreen extends StatefulWidget {
  const ProfileCreationScreen({super.key});

  @override
  State<ProfileCreationScreen> createState() => _ProfileCreationScreenState();
}

class _ProfileCreationScreenState extends State<ProfileCreationScreen> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<Offset> _slideAnimation;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  bool isBVStudent = true;
  bool _isProfilePhotoUploaded = false;
  bool _isDocumentUploaded = false;
  bool _isLoading = false;

  File? _profileImageFile; 

  String? _selectedCollege = "BVDU College of Engineering, Pune";
  String? _selectedCourse;
  String? _selectedDepartment;
  String? _selectedYear;

  final List<String> bvColleges = [
    "BVDU College of Engineering, Pune",
    "Bharati Vidyapeeth’s College of Engineering for Women, Pune",
    "Bharati Vidyapeeth’s Jawaharlal Nehru Institute of Technology (Polytechnic), Pune",
    "Others",
  ];

  final List<String> bvCourses = ["B.Tech", "M.Tech"];

  final List<String> bvDepartments = [ "CE", "Chemical", "Civil", "CSBS", "CSE", "CSE AI&ML", "ECE", "ELCE", "ENTC", "IT", "Mech", "Robotics & Automation", ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutQuint));
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pulseController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _idController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _profileImageFile = File(pickedFile.path);
        _isProfilePhotoUploaded = true;
      });
    }
  }

  void _showMediaPicker(String title, bool isPdfOnly) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(padding: const EdgeInsets.all(16.0), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (!isPdfOnly) ...[
                ListTile(leading: const Icon(Icons.camera_alt_rounded), title: const Text('Take a Photo'), onTap: () { Navigator.pop(context); _pickProfileImage(ImageSource.camera); }),
                ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose from Gallery'), onTap: () { Navigator.pop(context); _pickProfileImage(ImageSource.gallery); }),
              ] else ...[
                ListTile(leading: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent), title: const Text('Select PDF Document (Max 2MB)'), onTap: () { Navigator.pop(context); setState(() => _isDocumentUploaded = true); }),
              ],
            ],
          ),
        );
      },
    );
  }

  List<String> getAvailableYears() {
    if (_selectedCourse == "M.Tech") return ["1st", "2nd"];
    return ["1st", "2nd", "3rd", "4th"];
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    bool isDefaultBvcoe = _selectedCollege == "BVDU College of Engineering, Pune";
    List<String> currentYears = getAvailableYears();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TopLogoImage(assetPath: 'assets/imageA.png', size: 60, placeholderLabel: 'A', fallbackTextColor: primaryColor, fallbackBgColor: primaryColor.withOpacity(0.1)),
                  TopLogoImage(assetPath: 'assets/imageB.png', size: 60, placeholderLabel: 'B', fallbackTextColor: primaryColor, fallbackBgColor: primaryColor.withOpacity(0.1)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Create Your Profile", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text("Register to access AICTE-IDEA Lab resources.", textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildSelectionCard(title: "Bharati Vidyapeeth\nStudent", isSelected: isBVStudent, onTap: () => setState(() { isBVStudent = true; _selectedCollege = "BVDU College of Engineering, Pune"; _selectedCourse = null; _selectedDepartment = null; _selectedYear = null; _isDocumentUploaded = false; }), primaryColor: primaryColor)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSelectionCard(title: "Other College\nStudent", isSelected: !isBVStudent, onTap: () => setState(() { isBVStudent = false; _selectedCollege = null; _selectedCourse = null; _selectedDepartment = null; _selectedYear = null; _isDocumentUploaded = false; }), primaryColor: primaryColor)),
                          ],
                        ),
                        const SizedBox(height: 32),
                        GestureDetector(
                          onTap: () => _showMediaPicker("Upload Profile Photo", false),
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: DashedShapePainter(color: _isProfilePhotoUploaded ? primaryColor : Colors.grey.shade400, isCircle: true, strokeWidth: 2, gap: 6),
                                child: Container(
                                  width: 110, height: 110,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: _isProfilePhotoUploaded ? primaryColor.withOpacity(0.1) : primaryColor.withOpacity(0.02 + (_pulseController.value * 0.05))),
                                  clipBehavior: Clip.antiAlias,
                                  child: _isProfilePhotoUploaded && _profileImageFile != null
                                      ? Image.file(_profileImageFile!, width: 110, height: 110, fit: BoxFit.cover)
                                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt_rounded, size: 28, color: primaryColor.withOpacity(0.7))]),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text("Upload Profile Photo (Optional)", style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 32),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildTextField("First Name", controller: _firstNameController, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))])),
                            const SizedBox(width: 16),
                            Expanded(child: _buildTextField("Last Name", controller: _lastNameController, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]'))])),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField("Email ID", controller: _emailController, keyboardType: TextInputType.emailAddress, validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'This field is required';
                          if (!value.contains('@')) return 'Please enter a valid email address';
                          return null;
                        }),
                        const SizedBox(height: 16),
                        _buildTextField("Password", controller: _passwordController, obscureText: true, validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Password is required';
                          if (value.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        }),
                        const SizedBox(height: 16),
                        if (isBVStudent)
                          _buildDropdownField(label: "College Name", value: _selectedCollege, items: bvColleges, onChanged: (val) { setState(() { _selectedCollege = val; _selectedCourse = null; _selectedDepartment = null; _selectedYear = null; }); })
                        else
                          _buildTextField("College Name", controller: TextEditingController(text: "Other")),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: isDefaultBvcoe ? _buildDropdownField(label: "Course", value: _selectedCourse, items: bvCourses, onChanged: (val) { setState(() { _selectedCourse = val; _selectedYear = null; }); }) : _buildTextField("Course")),
                            const SizedBox(width: 16),
                            Expanded(child: isDefaultBvcoe ? _buildDropdownField(label: "Year of Study", value: _selectedYear, items: currentYears, onChanged: (val) => setState(() => _selectedYear = val)) : _buildTextField("Year of Study")),
                          ],
                        ),
                        const SizedBox(height: 16),
                        isDefaultBvcoe ? _buildDropdownField(label: "Department", value: _selectedDepartment, items: bvDepartments, onChanged: (val) => setState(() => _selectedDepartment = val)) : _buildTextField("Department"),
                        const SizedBox(height: 16),
                        if (isBVStudent) ...[
                          _buildTextField("PRN Number", controller: _idController, keyboardType: TextInputType.number, 
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'This field is required';
                              if (value.length != 10) return 'PRN must be exactly 10 digits';
                              return null;
                            }
                          ),
                          const SizedBox(height: 16),
                        ],
                        _buildTextField(
                          "Phone Number",
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        ),
                        const SizedBox(height: 24),
                        _buildDocumentUploadArea(isBVStudent ? "Upload College ID (PDF, max 2MB limit)" : "Upload Aadhaar Card (PDF, max 2MB limit)", primaryColor, true),
                        const SizedBox(height: 48),

                        if (_isLoading)
                          const CircularProgressIndicator()
                        else
                          AnimatedScaleButton(
                            text: "Create Profile",
                            color: primaryColor,
                            width: MediaQuery.of(context).size.width * 0.8,
                            onPressed: () async {
                              bool isDocsValid = true;
                              if (!_isDocumentUploaded) { 
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please upload your ID Document'), backgroundColor: Colors.redAccent)); 
                                isDocsValid = false; 
                              }

                              if (_formKey.currentState!.validate() && isDocsValid) {
                                setState(() => _isLoading = true);
                                try {
                                  UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text.trim(),
                                  );

                                  String generatedId = "IDEA-${(Random().nextInt(9000) + 1000).toString()}";
                                  String uid = userCredential.user!.uid;

                                  String? uploadedImageUrl;
                                  if (_isProfilePhotoUploaded && _profileImageFile != null && !kIsWeb) {
                                    try {
                                      final storageRef = FirebaseStorage.instance.ref().child('profile_images/$uid.jpg');
                                      await storageRef.putFile(_profileImageFile!);
                                      uploadedImageUrl = await storageRef.getDownloadURL();
                                    } catch (e) {
                                      debugPrint("Image upload failed, skipping: $e");
                                    }
                                  }

                                  try {
                                    await FirebaseFirestore.instance.collection('users').doc(uid).set({
                                      'firstName': _firstNameController.text.trim(),
                                      'lastName': _lastNameController.text.trim(),
                                      'email': _emailController.text.trim(),
                                      'phone': _phoneController.text.trim(),
                                      'college': _selectedCollege ?? "Other College",
                                      'course': _selectedCourse ?? "N/A",
                                      'year': _selectedYear ?? "N/A",
                                      'department': _selectedDepartment ?? "N/A",
                                      'idNumber': _idController.text.trim().isNotEmpty ? _idController.text.trim() : "N/A",
                                      'uniqueId': generatedId,
                                      'profileImageUrl': uploadedImageUrl,
                                      'createdAt': FieldValue.serverTimestamp(),
                                      'status': 'pending_approval',
                                      'points': 0, 
                                      'achievements': {}, 
                                      'role': 'student'
                                    });

                                    if (mounted) {
                                      Navigator.pushReplacement(context, PageRouteBuilder(pageBuilder: (context, a, sa) => const ProfileSubmittedScreen(), transitionsBuilder: (context, a, sa, child) => FadeTransition(opacity: a, child: child)));
                                    }
                                  } catch (dbError) {
                                    await userCredential.user!.delete();
                                    throw Exception("Database error. Please try again.");
                                  }
                                } on FirebaseAuthException catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Registration failed"), backgroundColor: Colors.redAccent));
                                } catch (e) {
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error saving profile. Try again."), backgroundColor: Colors.redAccent));
                                } finally {
                                  if (mounted) setState(() => _isLoading = false);
                                }
                              }
                            },
                          ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionCard({required String title, required bool isSelected, required VoidCallback onTap, required Color primaryColor}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(color: isSelected ? primaryColor.withOpacity(0.08) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300, width: isSelected ? 2 : 1)),
        alignment: Alignment.center,
        child: Column(
          children: [
            if (isSelected) Icon(Icons.check_circle_rounded, color: primaryColor, size: 20) else Icon(Icons.radio_button_unchecked, color: Colors.grey.shade400, size: 20),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? primaryColor : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {TextEditingController? controller, String? initialValue, bool readOnly = false, bool obscureText = false, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator, List<TextInputFormatter>? inputFormatters}) {
    return TextFormField(
      controller: controller, initialValue: initialValue, readOnly: readOnly, keyboardType: keyboardType, obscureText: obscureText,
      validator: validator ?? (value) { if (value == null || value.trim().isEmpty) return 'This field is required'; return null; },
      inputFormatters: inputFormatters, style: TextStyle(color: readOnly ? Colors.grey.shade600 : Colors.black87, fontWeight: FontWeight.w500),
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14), filled: true, fillColor: readOnly ? Colors.grey.shade100 : Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2)), errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2)), focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2))),
    );
  }

  Widget _buildDropdownField({required String label, required String? value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return DropdownButtonFormField<String>(
      value: value, isExpanded: true, icon: const Icon(Icons.arrow_drop_down_rounded),
      validator: (val) { if (val == null || val.isEmpty) return 'This field is required'; return null; },
      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500, fontSize: 14, fontFamily: 'Roboto'),
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2))),
      items: items.map((item) => DropdownMenuItem<String>(value: item, child: Text(item, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildDocumentUploadArea(String title, Color primaryColor, bool isPdf) {
    return GestureDetector(
      onTap: () => _showMediaPicker(title, isPdf),
      child: CustomPaint(
        painter: DashedShapePainter(color: _isDocumentUploaded ? primaryColor : Colors.grey.shade400, isCircle: false, strokeWidth: 2, gap: 6, radius: 16),
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(color: _isDocumentUploaded ? primaryColor.withOpacity(0.05) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              if (_isDocumentUploaded) ...[
                Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: primaryColor.withOpacity(0.3))), child: Icon(Icons.picture_as_pdf_rounded, color: primaryColor, size: 30)),
                const SizedBox(height: 12),
              ] else ...[
                Icon(Icons.upload_file_rounded, color: primaryColor.withOpacity(0.7), size: 40),
                const SizedBox(height: 12),
              ],
              Text(title, style: TextStyle(color: _isDocumentUploaded ? primaryColor : Colors.grey.shade700, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// PROFILE SUBMITTED SCREEN
/// ----------------------------------------------------------------------------
class ProfileSubmittedScreen extends StatelessWidget {
  const ProfileSubmittedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 80.0), 
          child: Align(
            alignment: Alignment.topCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: primaryColor), child: const Icon(Icons.check_rounded, color: Colors.white, size: 50)),
                const SizedBox(height: 48),
                Text("Profile Submitted", textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 0.5)),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text("Your profile has been submitted for verification. Please wait for an Admin to approve your account. This screen will automatically update when approved.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.grey.shade700, height: 1.5))
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// GLOBAL CUSTOM TAB HEADER
/// ----------------------------------------------------------------------------
class CustomTabHeader extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final bool isMainTab;

  const CustomTabHeader({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.onBackPressed,
    this.actions,
    this.isMainTab = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      color: primaryColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (isMainTab) ...[
              Padding(
                padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 8.0, bottom: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TopLogoImage(assetPath: 'assets/imageA.png', size: 64, placeholderLabel: 'A', fallbackTextColor: Colors.white, fallbackBgColor: Colors.white.withOpacity(0.2)),
                    TopLogoImage(assetPath: 'assets/imageB.png', size: 64, placeholderLabel: 'B', fallbackTextColor: Colors.white, fallbackBgColor: Colors.white.withOpacity(0.2)),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
            ],
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  height: isMainTab ? 32 : 60,
                  alignment: isMainTab ? Alignment.topCenter : Alignment.center,
                  child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (showBackButton)
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: onBackPressed ?? () => Navigator.pop(context),
                    ),
                  ),
                if (actions != null)
                  Positioned(
                    right: 8,
                    child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
                  ),
              ],
            ),
            if (!isMainTab) const SizedBox(height: 8),
            if (isMainTab) const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// MAIN DASHBOARD WRAPPER
/// ----------------------------------------------------------------------------
class MainDashboard extends StatefulWidget {
  final int initialIndex;
  const MainDashboard({super.key, this.initialIndex = 0});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _getScreen() {
    switch (_selectedIndex) {
      case 0: return HomeScreen(onNavigateToTab: _changeTab);
      case 1: return const ProjectsScreen();
      case 2: return const MachineBookingScreen();
      case 3: return const AIChatScreen();
      case 4: return const ProfileScreen();
      default: return HomeScreen(onNavigateToTab: _changeTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: _getScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: primaryColor,
          unselectedItemColor: Colors.grey.shade500,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.book_rounded), label: 'Projects'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_month_rounded), label: 'Bookings'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_rounded), label: 'AI Chat'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// HOME SCREEN (Student Dashboard)
/// ----------------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  final Function(int)? onNavigateToTab;
  const HomeScreen({super.key, this.onNavigateToTab});

  void _showFullPassModal(BuildContext context, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final String fullName = "${AppData.currentUser.firstName} ${AppData.currentUser.lastName}";
        final String uniqueIdText = "ID: ${AppData.currentUser.uniqueId}"; 

        return Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                fullName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                uniqueIdText,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: QrImageView(
                  data: "$fullName | $uniqueIdText | AICTE IDEA Lab Entry Pass",
                  version: QrVersions.auto,
                  size: 220.0,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Scan this QR code at the IDEA Lab entrance for access verification.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    foregroundColor: Colors.grey.shade800,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Close", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    final String prnText = AppData.currentUser.idNumber != "N/A" && AppData.currentUser.idNumber.isNotEmpty
        ? "PRN: ${AppData.currentUser.idNumber}"
        : "Phone: ${AppData.currentUser.phone}";

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipPath(
            clipper: HeaderClipper(),
            child: Container(
              height: 250, 
              width: double.infinity,
              decoration: BoxDecoration(
                color: primaryColor,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, HSLColor.fromColor(primaryColor).withLightness(0.4).toColor()],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TopLogoImage(assetPath: 'assets/imageA.png', size: 64, placeholderLabel: 'A', fallbackTextColor: Colors.white, fallbackBgColor: Colors.white.withOpacity(0.2)),
                          TopLogoImage(assetPath: 'assets/imageB.png', size: 64, placeholderLabel: 'B', fallbackTextColor: Colors.white, fallbackBgColor: Colors.white.withOpacity(0.2)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text("Hello, ${AppData.currentUser.firstName} 👋", style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Welcome to IDEA Lab", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w400)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          Transform.translate(
            offset: const Offset(0, -30),
            child: GestureDetector(
              onTap: () => _showFullPassModal(context, primaryColor),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [HSLColor.fromColor(primaryColor).withLightness(0.4).toColor(), primaryColor], begin: Alignment.centerLeft, end: Alignment.centerRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 60, height: 60, 
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                          clipBehavior: Clip.antiAlias,
                          child: AppData.currentUser.profileImageUrl != null 
                              ? Image.network(AppData.currentUser.profileImageUrl!, fit: BoxFit.cover)
                              : const Icon(Icons.person, color: Colors.white, size: 40)
                        ),
                        const SizedBox(height: 8),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: const Row(children: [Icon(Icons.check_circle, color: Colors.white, size: 12), SizedBox(width: 4), Text("ID Verified", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))])),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Digital Lab Pass", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(AppData.currentUser.college.split(',').first, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(prnText, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13)),
                        ],
                      ),
                    ),
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.qr_code_2, size: 50, color: Colors.black87))
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: GestureDetector(
                            onTap: () {
                              if (onNavigateToTab != null) onNavigateToTab!(1);
                            },
                            child: _buildActionCard(Icons.assignment_rounded, "Register Project", primaryColor)
                        )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: GestureDetector(
                            onTap: () {
                              if (onNavigateToTab != null) onNavigateToTab!(2);
                            },
                            child: _buildActionCard(Icons.precision_manufacturing_rounded, "Book a Machine", primaryColor)
                        )
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportIssueScreen())),
                        child: _buildActionCard(Icons.build_rounded, "Report an Issue", primaryColor, hasAlert: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AllMachineStatusScreen())),
                        child: _buildActionCard(Icons.settings_rounded, "Machine Status", primaryColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Lab Updates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('machines').limit(2).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox(height: 20, child: CircularProgressIndicator());
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) return const Text("No updates.");
                          return Row(
                            children: docs.map((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              Color sColor = data['status'] == 'Available' ? const Color(0xFF2ECA7F) : const Color(0xFFE74C3C);
                              return _buildStatusRow(data['name'] ?? '', data['status'] ?? '', sColor);
                            }).toList(),
                          );
                        }
                      ),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1, color: Color(0xFFEEEEEE))),
                      Center(
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AllMachineStatusScreen())),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.list_alt_rounded, color: primaryColor, size: 16),
                              const SizedBox(width: 8),
                              Text("See all machine updates", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: [
                Expanded(child: _buildInfoCard(Icons.event_rounded, "Events", "View Activities", primaryColor, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EventsScreen()));
                })),
                const SizedBox(width: 12),
                Expanded(child: _buildInfoCard(Icons.event_available_rounded, "My Bookings", "View Bookings", primaryColor, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyBookingsScreen(fromHome: true)));
                })),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildActionCard(IconData icon, String title, Color color, {bool hasAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 22)),
              if (hasAlert) Positioned(right: -4, bottom: -4, child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 16)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String machineName, String status, Color statusColor) {
    return Expanded(
      child: Row(
        children: [
          Flexible(child: Text(machineName, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(6)), child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, maxLines: 1),
                  const SizedBox(height: 4),
                  Row(children: [
                    Flexible(child: Text(subtitle, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    Icon(Icons.chevron_right_rounded, color: color, size: 14)
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// EVENTS SCREEN
/// ----------------------------------------------------------------------------
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});
  
  @override 
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(children: [
        const CustomTabHeader(title: "IDEA Lab Events", showBackButton: true, isMainTab: false),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('events').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) return const Center(child: Text("No upcoming events."));

              return ListView.builder(
                padding: const EdgeInsets.all(16), 
                itemCount: docs.length, 
                itemBuilder: (context, index) {
                  var data = docs[index].data() as Map<String, dynamic>;
                  return Card(
                    color: Colors.white, margin: const EdgeInsets.only(bottom: 12), 
                    child: ListTile(
                      leading: Icon(Icons.event_note, color: primaryColor), 
                      title: Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), 
                      subtitle: Text("${data['date']} • ${data['time']}\n${data['description']}"), 
                      isThreeLine: true
                    )
                  );
                }
              );
            }
          )
        )
      ]),
    );
  }
}

/// ----------------------------------------------------------------------------
/// REPORT AN ISSUE SCREEN
/// ----------------------------------------------------------------------------
class ReportIssueScreen extends StatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  String? _selectedMachine;
  late List<String> _machines = [];
  final TextEditingController _descController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMachines();
  }

  Future<void> _fetchMachines() async {
    final snap = await FirebaseFirestore.instance.collection('machines').get();
    if(mounted) {
      setState(() {
        _machines = snap.docs.map((doc) => (doc.data())['name'] as String).toList();
      });
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Report an Issue", showBackButton: true, isMainTab: false),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PreviousGrievancesScreen())),
                      icon: Icon(Icons.history_rounded, color: primaryColor),
                      label: Text("View Previous Grievances", style: TextStyle(color: primaryColor)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text("Select Machine", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedMachine,
                    isExpanded: true,
                    hint: const Text("Select Machine"),
                    icon: const Icon(Icons.arrow_drop_down_rounded),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                    ),
                    items: _machines.map((name) => DropdownMenuItem<String>(value: name, child: Text(name))).toList(),
                    onChanged: (val) => setState(() => _selectedMachine = val),
                  ),
                  const SizedBox(height: 24),

                  Text("Describe the Issue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    maxLines: 5,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                    decoration: InputDecoration(
                      hintText: "Please describe the problem with the machine or lab...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 32),
                  AnimatedScaleButton(
                    text: "Submit Report",
                    color: primaryColor,
                    width: double.infinity,
                    onPressed: () async {
                      if (_selectedMachine == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a machine first.'), backgroundColor: Colors.redAccent));
                        return;
                      }
                      if (_descController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please describe the issue.'), backgroundColor: Colors.redAccent));
                        return;
                      }

                      await FirebaseFirestore.instance.collection('issues').add({
                        'machineName': _selectedMachine!,
                        'description': _descController.text.trim(),
                        'timestamp': FieldValue.serverTimestamp(),
                        'userId': FirebaseAuth.instance.currentUser?.uid,
                        'status': 'Pending' 
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Issue reported successfully.'), backgroundColor: Colors.green));
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// PREVIOUS GRIEVANCES SCREEN
/// ----------------------------------------------------------------------------
class PreviousGrievancesScreen extends StatelessWidget {
  const PreviousGrievancesScreen({super.key});

  String _formatDate(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Previous Grievances", showBackButton: true, isMainTab: false),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('issues')
                  .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No previous grievances found.", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)));
                }

                var issuesList = snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return IssueReportModel(
                    machineName: data['machineName'] ?? 'Unknown',
                    description: data['description'] ?? '',
                    timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
                    status: data['status'] ?? 'Pending',
                  );
                }).toList();
                
                issuesList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: issuesList.length,
                  itemBuilder: (context, index) {
                    final issue = issuesList[index];
                    Color statusColor = issue.status == 'Completed' ? Colors.green : (issue.status == 'Processing' ? Colors.blue : Colors.orange);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.build_circle_rounded, size: 16, color: primaryColor),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(issue.machineName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.grey.shade800))),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(_formatDate(issue.timestamp), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: statusColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(issue.status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(issue.description, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4)),
                        ],
                      ),
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

/// ----------------------------------------------------------------------------
/// MY PROJECTS SCREEN 
/// ----------------------------------------------------------------------------
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "My Projects", isMainTab: true),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('projects')
                  .where('createdBy', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No projects found."));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    
                    ProjectModel project = ProjectModel(
                      id: docs[index].id,
                      name: data['name'] ?? '',
                      description: data['description'] ?? '',
                      isOngoing: data['isOngoing'] ?? true,
                      imagePath: data['imagePath'],
                      mentors: List<String>.from(data['mentors'] ?? []),
                      teamMembers: (data['teamMembers'] as List<dynamic>? ?? []).map((t) => TeamMember(name: t['name'] ?? '', id: t['id'] ?? '')).toList(),
                    );

                    return _buildProjectCard(context, project, primaryColor);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ProjectDetailScreen(
              primaryColor: primaryColor,
              onSave: (newProject) {
              },
            )),
          );
        },
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Create New Project", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProjectCard(BuildContext context, ProjectModel project, Color primaryColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ProjectDetailScreen(
            project: project,
            primaryColor: primaryColor,
            onSave: (updatedProject) {
            },
          )),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: project.imagePath != null && project.imagePath!.startsWith('http')
                    ? Image.network(project.imagePath!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildPlaceholderIcon(primaryColor))
                    : (project.imagePath != null && project.imagePath != 'uploaded_simulated'
                        ? Image.asset(project.imagePath!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildPlaceholderIcon(primaryColor))
                        : _buildPlaceholderIcon(primaryColor)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade900)),
                    const SizedBox(height: 6),
                    Text(project.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: project.isOngoing ? Colors.blue.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: project.isOngoing ? Colors.blue.shade200 : Colors.green.shade200),
                ),
                child: Text(
                  project.isOngoing ? "Ongoing" : "Completed",
                  style: TextStyle(color: project.isOngoing ? Colors.blue.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(Color color) {
    return Icon(Icons.rocket_launch_rounded, color: color.withOpacity(0.6), size: 30);
  }
}

/// ----------------------------------------------------------------------------
/// PROJECT DETAIL SCREEN 
/// ----------------------------------------------------------------------------
class TeamMemberEntry {
  TextEditingController nameCtrl = TextEditingController();
  TextEditingController idCtrl = TextEditingController();
  TeamMemberEntry({String name = "", String id = ""}) {
    nameCtrl.text = name;
    idCtrl.text = id;
  }
}

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel? project;
  final Color primaryColor;
  final Function(ProjectModel) onSave;

  const ProjectDetailScreen({super.key, this.project, required this.primaryColor, required this.onSave});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  bool _isOngoing = true;
  String? _imagePath;
  File? _selectedImageFile; 
  bool _isUploading = false;

  List<TextEditingController> _mentorControllers = [];
  List<TeamMemberEntry> _teamEntries = [];

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _nameController = TextEditingController(text: p?.name ?? "");
    _descController = TextEditingController(text: p?.description ?? "");
    _isOngoing = p?.isOngoing ?? true;
    _imagePath = p?.imagePath;

    if (p != null) {
      _mentorControllers = p.mentors.map((m) => TextEditingController(text: m)).toList();
      _teamEntries = p.teamMembers.map((t) => TeamMemberEntry(name: t.name, id: t.id)).toList();
    }

    if (_mentorControllers.isEmpty) _mentorControllers.add(TextEditingController());
    if (_teamEntries.isEmpty) _teamEntries.add(TeamMemberEntry());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    for (var c in _mentorControllers) { c.dispose(); }
    for (var entry in _teamEntries) {
      entry.nameCtrl.dispose();
      entry.idCtrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _selectedImageFile = File(pickedFile.path);
        _imagePath = null; 
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("Image selected!"), backgroundColor: widget.primaryColor));
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(padding: EdgeInsets.all(16.0), child: Text("Upload Project Image", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ListTile(leading: Icon(Icons.camera_alt_rounded, color: widget.primaryColor), title: const Text('Take a Photo'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
              ListTile(leading: Icon(Icons.photo_library_rounded, color: widget.primaryColor), title: const Text('Choose from Gallery'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProject() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Project Name is required"), backgroundColor: Colors.red));
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Project Description is required"), backgroundColor: Colors.red));
      return;
    }

    List<Map<String, String>> validTeam = [];
    for (var entry in _teamEntries) {
      if (entry.nameCtrl.text.trim().isNotEmpty && entry.idCtrl.text.trim().isNotEmpty) {
        validTeam.add({'name': entry.nameCtrl.text.trim(), 'id': entry.idCtrl.text.trim()});
      }
    }

    if (validTeam.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("At least one valid Team Member with Name and ID is required"), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? finalImageUrl = _imagePath;
      if (_selectedImageFile != null) {
        final storageRef = FirebaseStorage.instance.ref().child('project_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(_selectedImageFile!);
        finalImageUrl = await storageRef.getDownloadURL();
      }

      final docRef = FirebaseFirestore.instance.collection('projects').doc(widget.project?.id);
      
      await docRef.set({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'isOngoing': _isOngoing,
        'imagePath': finalImageUrl,
        'mentors': _mentorControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
        'teamMembers': validTeam,
        'createdBy': FirebaseAuth.instance.currentUser?.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      Map<String, dynamic> ach = userDoc.data()?['achievements'] ?? {};
      int pointsToAdd = 0;
      
      if (ach['proj1'] != true) {
        ach['proj1'] = true;
        pointsToAdd += 20;
      }
      if (!_isOngoing && ach['proto1'] != true) {
        ach['proto1'] = true;
        pointsToAdd += 50;
      }

      if (pointsToAdd > 0) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'points': FieldValue.increment(pointsToAdd),
          'achievements': ach
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🏆 Achievements Unlocked! +$pointsToAdd Points'), backgroundColor: Colors.green.shade700));
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving project: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.project != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          CustomTabHeader(title: isEditing ? "Project Details" : "Create New Project", showBackButton: true, isMainTab: false),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: (_imagePath == null && _selectedImageFile == null) ? Colors.redAccent.withOpacity(0.5) : Colors.grey.shade300, width: (_imagePath == null && _selectedImageFile == null) ? 2 : 1),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _selectedImageFile != null
                              ? Image.file(_selectedImageFile!, fit: BoxFit.cover)
                              : (_imagePath != null && _imagePath!.startsWith('http')
                                  ? Image.network(_imagePath!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildPlaceholder())
                                  : (_imagePath != null && _imagePath != 'uploaded_simulated'
                                      ? Image.asset(_imagePath!, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildPlaceholder())
                                      : _buildPlaceholder())),
                        ),
                        Positioned(
                          top: -10,
                          right: -10,
                          child: GestureDetector(
                            onTap: _showImageSourcePicker,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: widget.primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: widget.primaryColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Project Name", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                      GestureDetector(
                        onTap: () => setState(() => _isOngoing = !_isOngoing),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _isOngoing ? Colors.blue.shade50 : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _isOngoing ? Colors.blue.shade200 : Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Text(_isOngoing ? "Ongoing" : "Completed", style: TextStyle(color: _isOngoing ? Colors.blue.shade700 : Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(width: 4),
                              Icon(Icons.swap_horiz_rounded, size: 14, color: _isOngoing ? Colors.blue.shade700 : Colors.green.shade700)
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
                    decoration: InputDecoration(
                      hintText: "Enter project name here...",
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text("Project Description", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    maxLength: 2000,
                    maxLines: 5,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
                    decoration: InputDecoration(
                      hintText: "Write a short project description here...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildDynamicMentorSection("Faculty Mentors", _mentorControllers),
                  const SizedBox(height: 24),
                  _buildDynamicTeamSection("Team Members", _teamEntries),
                  const SizedBox(height: 48),
                  if (_isUploading)
                    const Center(child: CircularProgressIndicator())
                  else
                    AnimatedScaleButton(
                      text: "Save Project",
                      color: widget.primaryColor,
                      width: double.infinity,
                      onPressed: _saveProject,
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        Text("Add Project Image", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDynamicMentorSection(String title, List<TextEditingController> controllers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            IconButton(icon: Icon(Icons.add_circle_outline_rounded, color: widget.primaryColor), onPressed: () => setState(() => controllers.add(TextEditingController())))
          ],
        ),
        const SizedBox(height: 8),
        ...controllers.map((controller) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                  child: TextField(controller: controller, decoration: InputDecoration(hintText: "Enter Name", hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), border: InputBorder.none, icon: Icon(Icons.person_outline_rounded, color: Colors.grey.shade400, size: 20))),
                ),
              ),
              if (controllers.length > 1)
                IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent), onPressed: () => setState(() => controllers.remove(controller)))
              else
                const SizedBox(width: 48),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildDynamicTeamSection(String title, List<TeamMemberEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                Text("Members must be registered", style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            IconButton(icon: Icon(Icons.add_circle_outline_rounded, color: widget.primaryColor), onPressed: () => setState(() => entries.add(TeamMemberEntry())))
          ],
        ),
        const SizedBox(height: 12),
        ...entries.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                  child: Column(
                    children: [
                      TextField(controller: entry.nameCtrl, decoration: InputDecoration(hintText: "Member Name", hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), border: InputBorder.none, icon: Icon(Icons.person, color: Colors.grey.shade400, size: 18), isDense: true, contentPadding: EdgeInsets.zero)),
                      const Divider(height: 16),
                      TextField(controller: entry.idCtrl, decoration: InputDecoration(hintText: "Registered Lab ID", hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14), border: InputBorder.none, icon: Icon(Icons.badge, color: Colors.grey.shade400, size: 18), isDense: true, contentPadding: EdgeInsets.zero)),
                    ],
                  ),
                ),
              ),
              if (entries.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: IconButton(icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent), onPressed: () => setState(() => entries.remove(entry))),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        )),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// ALL MACHINE STATUS SCREEN
/// ----------------------------------------------------------------------------
class AllMachineStatusScreen extends StatelessWidget {
  const AllMachineStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "All Machine Status", showBackButton: true, isMainTab: false),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('machines').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    Color sColor = data['status'] == 'Available' ? const Color(0xFF2ECA7F) : const Color(0xFFE74C3C);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(data['name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey.shade800))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: sColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: sColor)),
                            child: Text(data['status'] ?? '', style: TextStyle(color: sColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// MACHINE BOOKING LIST SCREEN 
/// ----------------------------------------------------------------------------
class MachineBookingScreen extends StatelessWidget {
  const MachineBookingScreen({super.key});

  void _showMaintenanceDialog(BuildContext context, String machineName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28), SizedBox(width: 8), Text("Machine Not Available")]),
          content: Text("$machineName is currently not available. Please check back later."),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text("OK", style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)))],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Book a Machine", isMainTab: true),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('machines').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    bool canBook = data['status'] == "Available";
                    Color statusColor = canBook ? const Color(0xFF2ECA7F) : const Color(0xFFE74C3C);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                              clipBehavior: Clip.antiAlias,
                              child: Image.asset(data['imagePath'] ?? '', fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => Icon(Icons.precision_manufacturing_rounded, color: Colors.grey.shade400, size: 40)),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const SizedBox(height: 4),
                                  Text(data['status'] ?? '', style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                if (canBook) {
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => BookingDetailScreen(machineName: data['name'])));
                                } else {
                                  _showMaintenanceDialog(context, data['name']);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(color: canBook ? statusColor : statusColor.withOpacity(0.8), borderRadius: BorderRadius.circular(6)),
                                child: Text(canBook ? "Book Now" : "Under Maintenance", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
                              ),
                            ),
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
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// BOOKING DETAIL SCREEN 
/// ----------------------------------------------------------------------------
class BookingDetailScreen extends StatefulWidget {
  final String machineName;
  const BookingDetailScreen({super.key, required this.machineName});

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  int? selectedSlotIndex;
  double _dragPosition = 0.0;
  DateTime _selectedDate = DateTime.now();
  String? _selectedProject;

  final List<String> times = [
    "09:00 AM - 10:00 AM", "10:00 AM - 11:00 AM", "11:00 AM - 12:00 PM",
    "12:00 PM - 01:00 PM", "01:00 PM - 02:00 PM", "02:00 PM - 03:00 PM", "03:00 PM - 04:00 PM"
  ];

  String _formatDate(DateTime date) {
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return "${months[date.month - 1]} ${date.day}, ${date.year}";
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Theme.of(context).primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        selectedSlotIndex = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          CustomTabHeader(title: "${widget.machineName} Booking", showBackButton: true, isMainTab: false),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text("Select Date: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Text(_formatDate(_selectedDate), style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              const Icon(Icons.calendar_today_rounded, size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text("Choose a Project", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('projects')
                        .where('createdBy', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      List<String> projectNames = [];
                      if (snapshot.hasData) {
                        projectNames = snapshot.data!.docs.map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String).toList();
                      }

                      return DropdownButtonFormField<String>(
                        value: _selectedProject,
                        isExpanded: true,
                        hint: const Text("Select Project"),
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
                        ),
                        items: projectNames.map((name) => DropdownMenuItem<String>(value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) => setState(() => _selectedProject = val),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  const Text("Choose Time Slot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 16),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('bookings')
                        .where('machineName', isEqualTo: widget.machineName)
                        .where('date', isEqualTo: _formatDate(_selectedDate))
                        .snapshots(),
                    builder: (context, bookingSnap) {
                      List<String> bookedSlots = [];
                      if (bookingSnap.hasData) {
                        bookedSlots = bookingSnap.data!.docs.map((doc) => (doc.data() as Map<String, dynamic>)['timeSlot'] as String).toList();
                      }

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.8,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: times.length,
                        itemBuilder: (context, index) {
                          bool isAvailable = !bookedSlots.contains(times[index]);
                          bool isSelected = selectedSlotIndex == index;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: isAvailable ? () {
                              setState(() {
                                selectedSlotIndex = index;
                              });
                            } : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isAvailable ? (isSelected ? primaryColor : Colors.white) : Colors.grey.shade200,
                                border: Border.all(
                                  color: isAvailable ? (isSelected ? primaryColor : Colors.grey.shade300) : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isAvailable && !isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))] : [],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                times[index],
                                style: TextStyle(
                                  color: isAvailable ? (isSelected ? Colors.white : Colors.grey.shade800) : Colors.grey.shade400,
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  decoration: isAvailable ? TextDecoration.none : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }
                  ),

                  const SizedBox(height: 40),

                  if (selectedSlotIndex != null)
                    Container(
                      height: 56,
                      decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(28)),
                      child: Stack(
                        children: [
                          const Center(child: Text("Slide to Confirm Booking", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                          Positioned(
                            left: _dragPosition,
                            child: GestureDetector(
                              onHorizontalDragUpdate: (details) {
                                setState(() {
                                  _dragPosition += details.delta.dx;
                                  if (_dragPosition < 0) _dragPosition = 0;
                                  if (_dragPosition > MediaQuery.of(context).size.width - 40 - 56) {
                                    _dragPosition = MediaQuery.of(context).size.width - 40 - 56;
                                  }
                                });
                              },
                              onHorizontalDragEnd: (details) async {
                                if (_dragPosition > MediaQuery.of(context).size.width - 150) {
                                  if (_selectedProject == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Project first'), backgroundColor: Colors.redAccent));
                                    setState(() => _dragPosition = 0.0);
                                    return;
                                  }

                                  final uid = FirebaseAuth.instance.currentUser!.uid;

                                  await FirebaseFirestore.instance.collection('bookings').add({
                                    'machineName': widget.machineName,
                                    'projectName': _selectedProject,
                                    'date': _formatDate(_selectedDate),
                                    'timeSlot': times[selectedSlotIndex!],
                                    'userId': uid,
                                    'createdAt': FieldValue.serverTimestamp(),
                                  });

                                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                                  Map<String, dynamic> ach = userDoc.data()?['achievements'] ?? {};
                                  
                                  final bookingsSnap = await FirebaseFirestore.instance.collection('bookings').where('userId', isEqualTo: uid).get();
                                  int totalBookings = bookingsSnap.docs.length;

                                  int pointsToAdd = 0;
                                  if (totalBookings == 1 && ach['book1'] != true) {
                                    ach['book1'] = true;
                                    pointsToAdd += 20;
                                  }
                                  if (totalBookings >= 5 && ach['book5'] != true) {
                                    ach['book5'] = true;
                                    pointsToAdd += 30;
                                  }

                                  if (pointsToAdd > 0) {
                                    await FirebaseFirestore.instance.collection('users').doc(uid).update({
                                      'points': FieldValue.increment(pointsToAdd),
                                      'achievements': ach
                                    });
                                  }

                                  if (mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, a, sa) => BookingConfirmedScreen(
                                          machineName: widget.machineName,
                                          timeSlot: times[selectedSlotIndex!],
                                          bookingDate: _formatDate(_selectedDate),
                                          projectName: _selectedProject!,
                                        ),
                                        transitionsBuilder: (context, a, sa, child) => FadeTransition(opacity: a, child: child),
                                      ),
                                    );
                                  }
                                } else {
                                  setState(() => _dragPosition = 0.0);
                                }
                              },
                              child: Container(
                                width: 56, height: 56,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(Icons.arrow_forward_ios_rounded, color: primaryColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// BOOKING CONFIRMED SCREEN
/// ----------------------------------------------------------------------------
class BookingConfirmedScreen extends StatefulWidget {
  final String machineName;
  final String timeSlot;
  final String bookingDate;
  final String projectName;

  const BookingConfirmedScreen({super.key, required this.machineName, required this.timeSlot, required this.bookingDate, required this.projectName});

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: const Interval(0.4, 1.0, curve: Curves.easeIn));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 120, height: 120,
                  decoration: const BoxDecoration(color: Color(0xFF2ECA7F), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 70),
                ),
              ),
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    Text("Machine Booking Confirmed", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                    const SizedBox(height: 32),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          _buildDetailRow("Machine:", widget.machineName),
                          const SizedBox(height: 12),
                          _buildDetailRow("Date:", widget.bookingDate),
                          const SizedBox(height: 12),
                          _buildDetailRow("Time:", widget.timeSlot),
                          const SizedBox(height: 12),
                          _buildDetailRow("Project:", widget.projectName),
                          const SizedBox(height: 32),
                          AnimatedScaleButton(
                            text: "View My Bookings",
                            color: primaryColor,
                            width: double.infinity,
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const MainDashboard(initialIndex: 2)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, textAlign: TextAlign.right, style: TextStyle(color: Colors.grey.shade800, fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// VIEW MY BOOKINGS SCREEN 
/// ----------------------------------------------------------------------------
class MyBookingsScreen extends StatelessWidget {
  final bool fromHome;
  const MyBookingsScreen({super.key, this.fromHome = false});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          CustomTabHeader(
              title: "My Bookings",
              showBackButton: true,
              isMainTab: false,
              onBackPressed: () {
                if (fromHome) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainDashboard(initialIndex: 2)));
                }
              }
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('bookings')
                  .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("No bookings found.", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)));
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.precision_manufacturing_rounded, color: primaryColor),
                              const SizedBox(width: 8),
                              Expanded(child: Text(data['machineName'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                          _buildRow("Project:", data['projectName'] ?? ''),
                          const SizedBox(height: 8),
                          _buildRow("Date:", data['date'] ?? ''),
                          const SizedBox(height: 8),
                          _buildRow("Time:", data['timeSlot'] ?? ''),
                        ],
                      ),
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

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w600))),
      ],
    );
  }
}

/// ----------------------------------------------------------------------------
/// ACHIEVEMENTS SCREEN
/// ----------------------------------------------------------------------------
class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Achievements", showBackButton: true, isMainTab: false),
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                int points = userData['points'] ?? 0;
                Map<String, dynamic> unlocked = userData['achievements'] ?? {};

                List<Map<String, dynamic>> allBadges = [
                  {'id': 'reg', 'title': 'Account Registered', 'desc': 'Awarded when your profile is approved.', 'points': 10, 'isUnlocked': unlocked['reg'] == true},
                  {'id': 'proj1', 'title': 'First Project Created', 'desc': 'Awarded when you create your first project.', 'points': 20, 'isUnlocked': unlocked['proj1'] == true},
                  {'id': 'book1', 'title': 'First Machine Booking', 'desc': 'Awarded for your first successful booking.', 'points': 20, 'isUnlocked': unlocked['book1'] == true},
                  {'id': 'proto1', 'title': 'Innovation Starter', 'desc': 'Awarded when you complete your first project.', 'points': 50, 'isUnlocked': unlocked['proto1'] == true},
                  {'id': 'book5', 'title': '5 Machines Booked', 'desc': 'Awarded when you book five machines.', 'points': 30, 'isUnlocked': unlocked['book5'] == true},
                ];

                return ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primaryColor, HSLColor.fromColor(primaryColor).withLightness(0.4).toColor()],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))],
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.white, size: 48),
                          const SizedBox(height: 12),
                          const Text("Total IDEA Points", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(points.toString(), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text("Your Badges", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey.shade800)),
                    const SizedBox(height: 16),

                    ...allBadges.map((ach) {
                      bool isUnlocked = ach['isUnlocked'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isUnlocked ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))] : [],
                          border: isUnlocked ? null : Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isUnlocked ? primaryColor.withOpacity(0.1) : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  isUnlocked ? Icons.emoji_events_rounded : Icons.lock_rounded,
                                  color: isUnlocked ? primaryColor : Colors.grey.shade400,
                                  size: 28
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(ach['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isUnlocked ? Colors.grey.shade900 : Colors.grey.shade500)),
                                  const SizedBox(height: 4),
                                  Text(ach['desc'], style: TextStyle(fontSize: 13, color: isUnlocked ? Colors.grey.shade600 : Colors.grey.shade400, height: 1.4)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isUnlocked ? Colors.amber.shade100 : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "+${ach['points']}",
                                style: TextStyle(
                                    color: isUnlocked ? Colors.amber.shade900 : Colors.grey.shade400,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}


/// ----------------------------------------------------------------------------
/// PROFILE SCREEN 
/// ----------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    
    if (pickedFile != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Uploading image...')));
        try {
          final ref = FirebaseStorage.instance.ref().child('profile_images/${user.uid}.jpg');
          await ref.putFile(File(pickedFile.path));
          final url = await ref.getDownloadURL();
          
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'profileImageUrl': url});
          
          setState(() {
            AppData.currentUser.profileImageUrl = url;
          });
          
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated!'), backgroundColor: Colors.green));
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.redAccent));
        }
      }
    }
  }

  void _showMediaPicker(BuildContext context, Color primaryColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text("Update Profile Picture", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
              ),
              ListTile(
                  leading: Icon(Icons.camera_alt_rounded, color: primaryColor),
                  title: const Text('Take a Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfileImage(ImageSource.camera);
                  }
              ),
              ListTile(
                  leading: Icon(Icons.photo_library_rounded, color: primaryColor),
                  title: const Text('Choose from Gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickProfileImage(ImageSource.gallery);
                  }
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final String fullName = "${AppData.currentUser.firstName} ${AppData.currentUser.lastName}";

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Profile", isMainTab: true),
          Expanded(
            child: FadeTransition(
              opacity: _fadeController,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showMediaPicker(context, primaryColor),
                            child: Stack(
                              children: [
                                Container(
                                  width: 80, height: 80,
                                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                                  clipBehavior: Clip.antiAlias,
                                  child: AppData.currentUser.profileImageUrl != null
                                      ? Image.network(AppData.currentUser.profileImageUrl!, fit: BoxFit.cover, width: 80, height: 80)
                                      : Icon(Icons.person, size: 50, color: primaryColor.withOpacity(0.5)),
                                ),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(AppData.currentUser.email, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                const SizedBox(height: 8),
                                Text("${AppData.currentUser.department} – ${AppData.currentUser.year}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
                                const SizedBox(height: 2),
                                Text(AppData.currentUser.college, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSettingsGroup([
                      _buildSettingsTile(
                        icon: Icons.emoji_events_rounded,
                        title: "Achievements",
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AchievementsScreen()));
                        },
                      ),
                      _buildSettingsTile(
                        icon: Icons.school_rounded,
                        title: "Academic Details",
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const AcademicDetailsScreen()));
                        },
                      ),
                    ]),
                    const SizedBox(height: 24),

                    Text("IDEA Lab Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 12),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('projects').where('createdBy', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
                      builder: (context, projectSnap) {
                        int projCount = projectSnap.data?.docs.length ?? 0;
                        int ongoingCount = projectSnap.data?.docs.where((d) => (d.data() as Map<String, dynamic>)['isOngoing'] == true).length ?? 0;

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('bookings').where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid).snapshots(),
                          builder: (context, bookingSnap) {
                            int bookCount = bookingSnap.data?.docs.length ?? 0;
                            return Row(
                              children: [
                                Expanded(child: _buildActivityCard("$projCount", "Projects\nCreated", primaryColor)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildActivityCard("$ongoingCount", "Ongoing\nProjects", primaryColor)),
                                const SizedBox(width: 12),
                                Expanded(child: _buildActivityCard("$bookCount", "Machines\nBooked", primaryColor)),
                              ],
                            );
                          }
                        );
                      }
                    ),

                    const SizedBox(height: 24),

                    Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                      child: SwitchListTile(
                        value: _notificationsEnabled,
                        onChanged: (val) {
                          setState(() => _notificationsEnabled = val);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(val ? "Notifications are now allowed" : "Notifications have been disabled"),
                              ],
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: Colors.grey.shade900,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ));
                        },
                        title: const Text("Notifications", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                        activeColor: primaryColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildSettingsGroup([
                      _buildSettingsTile(icon: Icons.help_outline_rounded, title: "Help & FAQ", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FAQScreen()))),
                      _buildSettingsTile(icon: Icons.privacy_tip_outlined, title: "Privacy & Safety", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen()))),
                      _buildSettingsTile(icon: Icons.mail_outline_rounded, title: "Contact Lab Admin", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DummyContentScreen(title: "Contact Lab Admin")))),
                    ]),
                    const SizedBox(height: 24),

                    Text("Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    const SizedBox(height: 12),
                    _buildSettingsGroup([
                      _buildSettingsTile(icon: Icons.manage_accounts_outlined, title: "Edit Profile", onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()))),
                      
                      _buildSettingsTile(icon: Icons.logout_rounded, title: "Logout", isDestructive: true, onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
                        }
                      }),
                    ]),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({required IconData icon, required String title, required VoidCallback onTap, bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.redAccent : Colors.grey.shade700),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDestructive ? Colors.redAccent : Colors.black87)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }
}

/// ----------------------------------------------------------------------------
/// FAQ SCREEN
/// ----------------------------------------------------------------------------
class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  final List<Map<String, String>> faqs = const [
    {"q": "1. What is the IDEA Lab App?", "a": "The IDEA Lab app allows students to register, create projects, book machines, and access lab resources efficiently."},
    {"q": "2. How do I get access to the app?", "a": "You must complete your profile and submit required documents. Access will be granted after admin approval."},
    {"q": "3. Why is my profile under review?", "a": "Your profile is being verified by the admin. This ensures only authorized users can access the lab."},
    {"q": "4. What should I do if my profile is rejected?", "a": "Please check your details and uploaded documents. You may contact the lab admin for further assistance."},
    {"q": "5. How can I book a machine?", "a": "You must first register a project. After that, you can select a machine, choose a time slot, and confirm your booking."},
    {"q": "6. Why can’t I select certain time slots?", "a": "Those time slots are already booked by other users or the machine may be under maintenance."},
    {"q": "7. What happens if a machine is under maintenance?", "a": "The machine will not be available for booking and will be marked as “Under Maintenance” in the app."},
    {"q": "8. How do I report an issue with a machine?", "a": "Go to the “Report Issue” section, select the machine, describe the issue, and submit."},
    {"q": "9. What are IDEA Points?", "a": "IDEA Points are rewards earned for activities like creating projects, booking machines, and participating in lab activities."},
    {"q": "10. How can I see my bookings?", "a": "You can view all your bookings in the “My Bookings” section."},
    {"q": "11. Will I receive notifications?", "a": "Yes, you will receive notifications for approvals, events, machine updates, and announcements from the admin."},
    {"q": "12. Who can I contact for help?", "a": "You can contact the IDEA Lab admin through the “Contact Lab Admin” section in the app."},
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Help & FAQ", showBackButton: true, isMainTab: false),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: faqs.length,
              itemBuilder: (context, index) {
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: primaryColor,
                      collapsedIconColor: Colors.grey.shade600,
                      title: Text(faqs[index]['q']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          child: Text(faqs[index]['a']!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5)),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// PRIVACY POLICY SCREEN
/// ----------------------------------------------------------------------------
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  final List<Map<String, String>> policies = const [
    {"q": "1. Information We Collect", "a": "We collect the following user information:\n• Name\n• Email address\n• Phone number\n• College and department details\n• PRN number (if applicable)\n• Uploaded documents (ID card / Aadhaar)"},
    {"q": "2. How We Use Your Information", "a": "Your data is used to:\n• Verify your identity\n• Provide access to the lab system\n• Manage bookings and projects\n• Send important notifications"},
    {"q": "3. Data Security", "a": "We use secure cloud services to store your data. Your information is protected and not shared without authorization."},
    {"q": "4. Data Sharing", "a": "We do not sell or share your personal data with third parties. Data is only accessible to authorized administrators."},
    {"q": "5. User Control", "a": "You can update your profile information. For deletion or correction requests, contact the admin."},
    {"q": "6. Notifications", "a": "We may send notifications related to:\n• Profile approval\n• Machine bookings\n• Events and updates"},
    {"q": "7. Uploaded Documents", "a": "Documents such as ID cards are used only for verification and are stored securely."},
    {"q": "8. Changes to Policy", "a": "The privacy policy may be updated. Users will be notified of major changes."},
    {"q": "9. Contact Information", "a": "For any privacy concerns, contact: IDEA Lab Admin\nEmail: idealab@bvucoep.edu.in"},
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Privacy & Safety", showBackButton: true, isMainTab: false),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: policies.length,
              itemBuilder: (context, index) {
                return Card(
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      iconColor: primaryColor,
                      collapsedIconColor: Colors.grey.shade600,
                      initiallyExpanded: index == 0, // Auto-expand the first item
                      title: Text(policies[index]['q']!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey.shade800)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(policies[index]['a']!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.5)),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// ACADEMIC DETAILS SCREEN
/// ----------------------------------------------------------------------------
class AcademicDetailsScreen extends StatelessWidget {
  const AcademicDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Academic Details", showBackButton: true, isMainTab: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildInfoField("College Name", AppData.currentUser.college),
                _buildInfoField("Department", AppData.currentUser.department),
                _buildInfoField("Year of Study", AppData.currentUser.year),
                _buildInfoField("PRN Number", AppData.currentUser.idNumber),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
            child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// EDIT PROFILE SCREEN
/// ----------------------------------------------------------------------------
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _deptController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: "${AppData.currentUser.firstName} ${AppData.currentUser.lastName}");
    _emailController = TextEditingController(text: AppData.currentUser.email);
    _phoneController = TextEditingController(text: AppData.currentUser.phone);
    _deptController = TextEditingController(text: AppData.currentUser.department);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _deptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          const CustomTabHeader(title: "Edit Profile", showBackButton: true, isMainTab: false),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildEditableField("Full Name", _nameController),
                _buildEditableField("Email", _emailController),
                _buildEditableField("Phone Number", _phoneController),
                _buildEditableField("Department", _deptController),
                const SizedBox(height: 32),
                AnimatedScaleButton(
                  text: "Save Changes",
                  color: primaryColor,
                  width: double.infinity,
                  onPressed: () {
                    List<String> names = _nameController.text.split(" ");
                    AppData.currentUser.firstName = names.isNotEmpty ? names.first : "";
                    AppData.currentUser.lastName = names.length > 1 ? names.sublist(1).join(" ") : "";
                    AppData.currentUser.email = _emailController.text;
                    AppData.currentUser.phone = _phoneController.text;
                    AppData.currentUser.department = _deptController.text;

                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully.'), backgroundColor: Colors.green));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 2)),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// DUMMY CONTENT SCREEN
/// ----------------------------------------------------------------------------
class DummyContentScreen extends StatelessWidget {
  final String title;
  const DummyContentScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(
        children: [
          CustomTabHeader(title: title, showBackButton: true, isMainTab: false),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  title == "Contact Lab Admin" ? "Email: idealab@bvucoep.edu.in\nPhone: +91 1234567890" : "$title content goes here.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------------
/// SHARED GLOBAL COMPONENTS
/// ----------------------------------------------------------------------------

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height - 20);
    path.quadraticBezierTo(size.width * 0.75, size.height - 40, size.width, size.height - 20);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class TopLogoImage extends StatelessWidget {
  final String assetPath;
  final double size;
  final String placeholderLabel;
  final Color fallbackTextColor;
  final Color fallbackBgColor;

  const TopLogoImage({super.key, required this.assetPath, required this.size, required this.placeholderLabel, required this.fallbackTextColor, required this.fallbackBgColor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Image.asset(assetPath, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) {
        return Container(decoration: BoxDecoration(color: fallbackBgColor, shape: BoxShape.circle), alignment: Alignment.center, child: Text('Img\n$placeholderLabel', textAlign: TextAlign.center, style: TextStyle(color: fallbackTextColor, fontSize: size * 0.25, fontWeight: FontWeight.bold)));
      }),
    );
  }
}

class AnimatedScaleButton extends StatefulWidget {
  final String text;
  final Color color;
  final double width;
  final VoidCallback onPressed;

  const AnimatedScaleButton({super.key, required this.text, required this.color, required this.width, required this.onPressed});

  @override
  State<AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<AnimatedScaleButton> with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _scaleController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) { _scaleController.reverse(); widget.onPressed(); },
      onTapCancel: () => _scaleController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width, padding: const EdgeInsets.symmetric(vertical: 18.0),
          decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(30.0), boxShadow: [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))]),
          alignment: Alignment.center, child: Text(widget.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

class DashedShapePainter extends CustomPainter {
  final Color color;
  final bool isCircle;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedShapePainter(
      {required this.color, required this.isCircle, this.strokeWidth = 2.0, this.gap = 5.0, this.radius = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final Path path = Path();
    if (isCircle)
      path.addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    else
      path.addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius)));

    final Path dashedPath = Path();
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? gap * 1.5 : gap;
        if (draw) dashedPath.addPath(
            metric.extractPath(distance, distance + len), Offset.zero);
        distance += len;
        draw = !draw;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedShapePainter oldDelegate) => true;
}