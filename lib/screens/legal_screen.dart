import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zensort/theme.dart';
import 'package:zensort/widgets/animated_gradient_app_bar.dart';
import 'package:zensort/widgets/gradient_loader.dart';

class LegalScreen extends StatefulWidget {
  final String docName;

  const LegalScreen({super.key, required this.docName});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String _markdownData = '';

  @override
  void initState() {
    super.initState();
    _loadMarkdownFile();
  }

  Future<void> _loadMarkdownFile() async {
    final String data = await rootBundle.loadString(
      'assets/legal/${widget.docName}.md',
    );
    setState(() {
      _markdownData = data;
    });
  }

  String _getTitle() {
    switch (widget.docName) {
      case 'disclaimer':
        return 'Disclaimer';
      case 'privacy_policy':
        return 'Privacy Policy';
      case 'terms_of_service':
        return 'Terms of Service';
      default:
        return 'Legal Document';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AnimatedGradientAppBar(
        title: _getTitle(),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
            left: 16.0,
            right: 16.0,
            bottom: 16.0,
          ),
          child: _markdownData.isEmpty
              ? const Center(child: GradientLoader())
              : MarkdownBody(
                  data: _markdownData,
                  styleSheet: CustomMarkdownStyle.getTheme(context),
                  onTapLink: (text, href, title) async {
                    if (href != null) {
                      final url = Uri.parse(href);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      }
                    }
                  },
                ),
        ),
      ),
    );
  }
}
