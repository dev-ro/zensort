
# Privacy Policy for ZenSort

## **Effective Date: July 19, 2025**

## 1. Introduction

Welcome to ZenSort ("we," "our," "us"). We are committed to protecting your privacy. This Privacy Policy governs your use of our software application ("App") and services (collectively, the "Service"). It explains how we collect, use, disclose, and safeguard your information when you use our Service.

This Service is operated from the State of Michigan, United States, and this policy is governed by its laws.

## 2. Definitions

- **"Service"** refers to the ZenSort application, website, and any related services provided by us.
- **"Personal Data"** means data about a living individual who can be identified from those data.
- **"YouTube Data"** refers to the metadata of your "Liked Videos" playlist on YouTube, including but not limited to titles, descriptions, thumbnails, and channel names.

## 3. Information We Collect and How We Use It

### 3.1. Information You Provide to Us

When you create an account, we use Google's OAuth service to authenticate your identity. Through this service, and with your explicit consent, we collect the following Personal Data:

- **Name**
- **Email Address**
- **Profile Picture**

We use this information to create and manage your account, to personalize your experience, and for communication purposes related to the Service. **We do not collect or store your Google account password.**

### 3.2. Information Collected via the YouTube API

With your explicit consent, we access your YouTube Data for the sole purpose of providing the Service's core functionality. Our process is as follows:

1. **Access:** We access the metadata of videos in your "Liked Videos" playlist. We do not access your viewing history or any playlists other than "Liked Videos."
2. **Analysis:** This metadata is used to create numerical representations ("embeddings") for automated analysis.
3. **Organization:** We use k-means clustering algorithms to group similar videos based on these embeddings into "Smart Shelves."
4. **Action:** Upon your request, we create new playlists on your YouTube account to organize your liked videos based on the clustering results.

### 3.3. Information Processed by Third-Party Services

To provide our Service, we utilize Google's Gemini API to process your YouTube Data. Specifically, we send YouTube Data (titles, descriptions, etc.) to the Gemini API to generate the embeddings required for our clustering analysis.

Your data, when processed by Google, is subject to the [Google Privacy Policy](https://policies.google.com/privacy). We recommend you review their policy to understand how they handle data.

## 4. How We Share Your Information

We do not sell, trade, or rent your Personal Data to third parties. We may disclose your information only to the following sub-processors for essential service functionality:

- **Google:** For authentication (OAuth), data processing (Gemini API), and service functionality (YouTube API).
- **Firebase:** For secure backend infrastructure, database, and data storage.

## 5. Data Storage and Security

We use Firebase, a Google product, for secure data storage. We implement commercially reasonable security measures to protect your data. However, no method of transmission over the Internet or method of electronic storage is 100% secure, and we cannot guarantee its absolute security.

## 6. Your Data Rights and Choices

You have the following rights regarding your Personal Data:

- **Access:** You can request a copy of the Personal Data we hold about you.
- **Correction:** You can request that we correct any Personal Data you believe is inaccurate or incomplete.
- **Deletion:** You can request that we delete your account and all associated Personal Data.
- **Opt-Out:** You may opt-out of receiving promotional communications from us by following the "unsubscribe" link or instructions provided in any email we send.

## 7. Children's Privacy

Our Service is not intended for anyone under the age of 13. We do not knowingly collect personally identifiable information from children under 13.

## 8. Changes to This Privacy Policy

We may update this Privacy Policy from time to time. We will notify you of any changes by posting the new policy on this page and updating the "Effective Date" at the top. You are advised to review this Privacy Policy periodically for any changes.

## 9. Contact Us

If you have any questions or concerns about this Privacy Policy, please contact us at: **<legal@zensort.app>**
