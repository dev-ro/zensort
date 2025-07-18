import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zensort/main.dart';

const String termsOfServiceText = """
# Terms of Service for ZenSort

**Effective Date: July 19, 2025**

### 1. Introduction and Definitions

These Terms of Service ("Terms") govern your access to and use of the ZenSort application and its related services (collectively, the "Service"). By accessing or using the Service, you agree to be bound by these Terms.

- **"Service"**: The ZenSort application, website, and related content.
- **"User"**: Any individual who accesses or uses the Service.
- **"Content"**: Any data, text, graphics, or other materials generated, provided, or otherwise made accessible on or through the Service.
- **"YouTube Data"**: Metadata from a User's "Liked Videos" playlist on YouTube.

### 2. Service Description

The Service provides Users with tools to organize their YouTube Data. This is achieved by using k-means clustering algorithms to group videos and creating new playlists on the User's YouTube account upon their request.

### 3. User Accounts

To access the Service, you must create an account using Google OAuth. You represent and warrant that you are at least 13 years of age and that all information you provide is accurate and complete. You are responsible for all activities that occur under your account.

### 4. User Responsibilities and Conduct

You agree not to use the Service for any unlawful purpose. You are solely responsible for your conduct and any data you provide or actions you take within the Service.

### 5. Third-Party Services

The Service integrates with and uses the following third-party services:

- **Google OAuth**: For user authentication.
- **YouTube API**: To access YouTube Data and manage playlists. Your use of this functionality is subject to the [YouTube Terms of Service](https://www.youtube.com/t/terms).
- **Google Gemini API**: For data processing and analysis.

We are not responsible for the practices of any third-party services.

### 6. Intellectual Property

All rights, title, and interest in and to the Service (excluding Content provided by Users) are and will remain the exclusive property of ZenSort and its licensors.

### 7. Subscriptions and Payments

Certain features of the Service may require a subscription. All subscription fees will be clearly disclosed to you. Payments are billed in advance on a recurring basis as specified at the time of purchase.

### 8. Termination

We may terminate or suspend your access to the Service immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms.

### 9. Disclaimer of Warranties and Limitation of Liability

The Service is provided on an "AS IS" and "AS AVAILABLE" basis. ZenSort, its directors, employees, and affiliates make no warranties, express or implied, regarding the Service. In no event shall ZenSort be liable for any indirect, incidental, special, consequential, or punitive damages arising out of your use of the Service.

### 10. Governing Law

These Terms shall be governed and construed in accordance with the laws of the State of Michigan, United States, without regard to its conflict of law provisions.

### 11. Changes to Terms

We reserve the right, at our sole discretion, to modify or replace these Terms at any time. We will provide at least 30 days' notice prior to any new terms taking effect.

### 12. Contact Information

For any questions about these Terms, please contact us at **legal@zensort.app**.
""";

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
          padding: const EdgeInsets.all(16.0),
          child: MarkdownBody(
            data: termsOfServiceText,
            styleSheet: CustomMarkdownStyle.getTheme(context),
            onTapLink: (text, href, title) {
              if (href != null) {
                launchUrl(Uri.parse(href));
              }
            },
          ),
        ),
      ),
    );
  }
}
