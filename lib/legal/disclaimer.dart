import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:zensort/main.dart'; // Assuming CustomMarkdownStyle is here

const String disclaimerText = """
# Disclaimer

**Effective Date: July 19, 2025**

### 1. General Information

The information and services provided by ZenSort ("we," "our," "us") are for general informational and organizational purposes only. All information on the Service is provided in good faith; however, we make no representation or warranty of any kind, express or implied, regarding the accuracy, adequacy, validity, reliability, availability, or completeness of any information or organizational results on the Service.

### 2. No Professional Advice

The Service is not intended to be a substitute for professional advice. The organizational structures, categories, and "Smart Shelves" are generated through automated algorithmic processes (k-means clustering) based on metadata from your liked videos. These results should not be considered as professional, curated, or expert-level advice or recommendations.

### 3. External Links and Third-Party Content Disclaimer

The Service provides access to content hosted on YouTube. We do not own, control, or endorse the content of these videos. Any views, opinions, or information expressed in the videos belong solely to the original creators and do not represent the views of ZenSort. Under no circumstance shall we have any liability to you for any loss or damage of any kind incurred as a result of the use of the site or reliance on any information provided on the site.

### 4. "As Is" and "As Available" Disclaimer

The Service is provided to you "AS IS" and "AS AVAILABLE" and with all faults and defects without warranty of any kind. To the maximum extent permitted under applicable law, ZenSort, on its own behalf and on behalf of its affiliates and its and their respective licensors and service providers, expressly disclaims all warranties, whether express, implied, statutory, or otherwise, with respect to the Service.

### 5. Contact Information

If you have any questions about this Disclaimer, please contact us at **legal@zensort.app**.
""";

class DisclaimerPage extends StatelessWidget {
  const DisclaimerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disclaimer'),
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
            data: disclaimerText,
            styleSheet: CustomMarkdownStyle.getTheme(context),
          ),
        ),
      ),
    );
  }
}
