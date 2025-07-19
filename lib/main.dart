import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:go_router/go_router.dart';
import 'firebase_options.dart' as prod_options;
import 'firebase_options_dev.dart' as dev_options;
import 'theme.dart';
import 'package:zensort/router.dart';
import 'package:zensort/widgets/animated_gradient_app_bar.dart';
import 'package:email_validator/email_validator.dart';

class CustomMarkdownStyle {
  static MarkdownStyleSheet getTheme(BuildContext context) {
    final pStyle = Theme.of(context).textTheme.bodyMedium;
    final fontSize = pStyle?.fontSize ?? 14.0;
    return MarkdownStyleSheet(
      a: TextStyle(
        decoration: TextDecoration.none,
        foreground: Paint()
          ..shader = ZenSortTheme.orangePurpleGradient.createShader(
            Rect.fromLTWH(0, 0, 70, fontSize),
          ),
      ),
      blockquoteDecoration: BoxDecoration(
        color: ZenSortTheme.purple.withAlpha(26),
        borderRadius: BorderRadius.circular(8.0),
      ),
      blockquotePadding: const EdgeInsets.all(16.0),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // To run in prod mode: flutter run --dart-define=FLAVOR=prod
  const flavor = String.fromEnvironment('FLAVOR');

  final options = flavor == 'prod'
      ? prod_options.DefaultFirebaseOptions.currentPlatform
      : dev_options.DefaultFirebaseOptions.currentPlatform;

  await Firebase.initializeApp(options: options);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ZenSort',
      theme: getLightTheme(),
      routerConfig: router,
      restorationScopeId: 'app',
      debugShowCheckedModeBanner: false,
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const AnimatedGradientAppBar(),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        key: const PageStorageKey<String>('landingPage'),
        children: [
          Hero(tag: 'zensort_logo', child: const HeroSection()),
          const FeaturesSection(),
          HowItWorksSection(),
          const CallToActionSection(),
          const Footer(),
        ],
      ),
    );
  }
}

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24.0, 80.0, 24.0, 24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SvgPicture.asset(
                'assets/images/zensort_logo_wordmark.svg',
                height: 75,
                placeholderBuilder: (BuildContext context) => Container(
                  padding: const EdgeInsets.all(30.0),
                  child: const CircularProgressIndicator(),
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Find clarity in the chaos.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'It all starts with your liked videos. ZenSort is the essential tool for organizing your YouTube library into clean, beautiful shelves. Stop endlessly scrolling and rediscover the content you love. Your journey to digital clarity begins here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturesSection extends StatefulWidget {
  const FeaturesSection({super.key});

  @override
  State<FeaturesSection> createState() => _FeaturesSectionState();
}

class _FeaturesSectionState extends State<FeaturesSection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(_isHovered ? 51 : 26),
                    blurRadius: _isHovered ? 30 : 20,
                    offset: Offset(0, _isHovered ? 15 : 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.0),
                child: Container(
                  padding: const EdgeInsets.all(1.5), // Border width
                  decoration: const BoxDecoration(
                    gradient: ZenSortTheme.orangePurpleGradient,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(22.5), // Content padding
                    decoration: BoxDecoration(
                      color: ZenSortTheme.scaffoldBackground,
                      borderRadius: BorderRadius.circular(18.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: SvgPicture.asset(
                                'assets/images/zensort_logo.svg',
                              ),
                            ),
                            const SizedBox(width: 12),
                            ShaderMask(
                              shaderCallback: (bounds) => ZenSortTheme
                                  .orangePurpleGradient
                                  .createShader(
                                    Rect.fromLTWH(
                                      0,
                                      0,
                                      bounds.width,
                                      bounds.height,
                                    ),
                                  ),
                              child: Text(
                                'Features',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const _FeatureItem(
                          icon: Icons.video_library_outlined,
                          title: 'Rediscover Your Library',
                          description:
                              'Effortlessly organize your entire liked video library, no matter the size.',
                          gradient: ZenSortTheme.orangePurpleGradient,
                        ),
                        const SizedBox(height: 20),
                        const _FeatureItem(
                          icon: Icons.playlist_play_outlined,
                          title: 'Break the Plateau',
                          description:
                              'Turn your Shelves into new YouTube playlists to escape the algorithm.',
                          gradient: ZenSortTheme.orangePurpleGradient,
                        ),
                        const SizedBox(height: 20),
                        const _FeatureItem(
                          icon: Icons.music_note_outlined,
                          title: 'Find Lost Music',
                          description:
                              'Locate and restore your legacy music uploads.',
                          gradient: ZenSortTheme.orangePurpleGradient,
                        ),
                        const SizedBox(height: 20),
                        const _FeatureItem(
                          icon: Icons.delete_sweep_outlined,
                          title: 'Effortless Cleanup',
                          description: 'Mass unlike videos to start fresh.',
                          gradient: ZenSortTheme.orangePurpleGradient,
                        ),
                        const SizedBox(height: 20),
                        const _FeatureItem(
                          icon: Icons.history_outlined,
                          title: 'Travel Back in Time',
                          description:
                              "Rediscover what you loved with Timely Shelves, perfect for nostalgic journeys.",
                          gradient: ZenSortTheme.orangePurpleGradient,
                        ),
                        const SizedBox(height: 20),
                        const _FeatureItem(
                          icon: Icons.sync_problem_outlined,
                          title: 'Track Unavailable Videos',
                          description:
                              'Get notified when liked videos are made private or deleted.',
                          gradient: ZenSortTheme.orangePurpleGradient,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Gradient gradient;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => gradient.createShader(
                Rect.fromLTWH(0, 0, bounds.width, bounds.height),
              ),
              child: Icon(
                icon,
                color: Colors.white, // This color is necessary for ShaderMask
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 44), // Aligns with text
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }
}

class HowItWorksSection extends StatefulWidget {
  const HowItWorksSection({super.key});

  @override
  State<HowItWorksSection> createState() => _HowItWorksSectionState();
}

class _HowItWorksSectionState extends State<HowItWorksSection> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: SvgPicture.asset('assets/images/zensort_logo.svg'),
                  ),
                  const SizedBox(width: 8),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        ZenSortTheme.orangePurpleGradient.createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        ),
                    child: Text(
                      'How It Works',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const _BuildStep(
                stepNumber: '1',
                title: 'Connect Your YouTube Account',
                description:
                    'Securely link your YouTube account to ZenSort in just a few clicks.',
              ),
              const SizedBox(height: 48),
              const _BuildStep(
                stepNumber: '2',
                title: 'AI-Powered "Smart Shelves"',
                description:
                    'Our AI uses k-means clustering to automatically group your videos into intelligent, well-defined shelves.',
              ),
              const SizedBox(height: 48),
              const _BuildStep(
                stepNumber: '3',
                title: 'Rediscover & Export',
                description:
                    'Enjoy your newly organized library and export Shelves to YouTube playlists.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildStep extends StatefulWidget {
  final String stepNumber;
  final String title;
  final String description;

  const _BuildStep({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  @override
  State<_BuildStep> createState() => _BuildStepState();
}

class _BuildStepState extends State<_BuildStep> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(_isHovered ? 26 : 0),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ZenSortTheme.orangePurpleGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(_isHovered ? 51 : 26),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: ZenSortTheme.scaffoldBackground,
                  child: ShaderMask(
                    shaderCallback: (bounds) =>
                        ZenSortTheme.orangePurpleGradient.createShader(
                          Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                        ),
                    child: Text(
                      widget.stepNumber,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: Theme.of(context).textTheme.bodyMedium,
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
}

class CallToActionSection extends StatefulWidget {
  const CallToActionSection({super.key});

  @override
  State<CallToActionSection> createState() => _CallToActionSectionState();
}

class _CallToActionSectionState extends State<CallToActionSection>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _isLoading = false;
  bool _isHovering = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _joinWaitlist() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
          'add_to_waitlist',
        );
        final result = await callable.call({'email': _emailController.text});
        if (!mounted) return;

        final message = result.data['message'];
        if (message.contains('is already on our waitlist')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
          _emailController.clear();
        }
      } on FirebaseFunctionsException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An unexpected error occurred: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 40.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(2.0),
                decoration: BoxDecoration(
                  gradient: ZenSortTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withAlpha(51),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: ZenSortTheme.scaffoldBackground,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            ZenSortTheme.orangePurpleGradient.createShader(
                              Rect.fromLTWH(0, 0, bounds.width, bounds.height),
                            ),
                        child: const Icon(
                          Icons.local_offer,
                          color: Colors.white, // Needs to be non-transparent
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Join the waitlist now and be one of the first 100 subscribers to get 50% off for life.',
                          textAlign: TextAlign.left,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: ZenSortTheme.darkText),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '''To check if you're on the list, just enter your email again and a confirmation will appear at the bottom of your screen. We'll only email you at launch.
Tip: Use your primary YouTube Gmail for early adopter rewards!''',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16.0),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2.0,
                      ),
                    ),
                  ),
                  style: Theme.of(context).textTheme.bodyLarge,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!EmailValidator.validate(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _joinWaitlist(),
                ),
              ),
              const SizedBox(height: 24),
              MouseRegion(
                onEnter: (event) => setState(() => _isHovering = true),
                onExit: (event) => setState(() => _isHovering = false),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(77),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ScaleTransition(
                    scale: _animation,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _joinWaitlist,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: ZenSortTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          alignment: Alignment.center,
                          child: _isLoading
                              ? CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.onPrimary,
                                  ),
                                )
                              : AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  scale: _isHovering ? 1.05 : 1.0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Join the Waitlist',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onPrimary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Footer extends StatelessWidget {
  const Footer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withAlpha(77),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            children: [
              Text(
                '© ${DateTime.now().year} ZenSort. All rights reserved.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      context.push('/privacy');
                    },
                    child: Text(
                      'Privacy Policy',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    '•',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.push('/terms');
                    },
                    child: Text(
                      'Terms of Service',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  Text(
                    '•',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      context.push('/disclaimer');
                    },
                    child: Text(
                      'Disclaimer',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
