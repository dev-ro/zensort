# **Goal of this Context Document**

To provide an LLM Coding Agent with the essential knowledge and strict operational constraints required to correctly implement Search Engine Optimization (SEO) for Flutter web applications. The agent must adhere to these rules to produce technically sound and effective solutions.

## **Core Concepts: The Flutter SEO Problem**

1. **Fundamental Conflict:** Flutter is designed for app-like experiences, which conflicts with how search crawlers index content from static, text-based HTML documents.  
2. **Client-Side Rendering (CSR):** Flutter web is a CSR framework. It sends a minimal HTML "shell" and a large JavaScript bundle. Crawlers may see a blank page because they might not wait for or execute the JavaScript needed to render the content.  
3. **Two Renderers (Critical Distinction):**  
   * **CanvasKit (Default):** Renders the UI to a single \<canvas\> element. This is a black box to crawlers and is **unacceptable for SEO**.  
   * **HTML Renderer:** Translates Flutter widgets into standard HTML elements, creating a parsable DOM. This is **mandatory for any SEO effort**.  
4. **Primary SEO Consequences of Default Setup:**  
   * **Content Invisibility:** Crawlers see a blank page.  
   * **Metadata Blindness:** All pages share the same \<title\> and \<meta\> tags.  
   * **Poor Core Web Vitals (CWV):** Large initial bundle sizes result in slow load times (bad LCP), harming search rankings.

## **Key Solutions & Strategies**

1. **Foundational Rendering Solutions (Architectural Choices):**  
   * **Prerendering / Dynamic Rendering:** A service (like Prerender.io) detects crawlers and serves them a pre-rendered, static HTML version of the page. This is an effective workaround.  
   * **Hybrid Architecture (Most Recommended):** Use a Static Site Generator (SSG) for public-facing, content-heavy pages (landing page, blog). This static site then links to the feature-rich Flutter application. The Dart-native SSG **Static Shock** is an excellent option for keeping the entire project in the Dart ecosystem.  
2. **On-Page & Technical SEO Implementation:**  
   * **Routing:** Use the **go\_router** package for clean, path-based URLs.  
   * **Dynamic Metadata:** Update page titles and meta descriptions as the user navigates. This can be done client-side (meta\_seo package) or, more reliably, via server-side injection for bots.  
   * **Structured Data (Schema.org):** Use JSON-LD to provide explicit context to search engines.  
   * **Performance Optimization (Core Web Vitals):** The primary technique is **code splitting using Dart's deferred as keyword** to reduce the initial bundle size.

## **Constraints & Rules for the LLM Coding Agent**

### **Rule 1: Build Configuration**

* **MUST** use the HTML renderer for all web builds intended for production. The command is flutter build web \--web-renderer html.  
* **MUST NOT** use the CanvasKit renderer for any project where SEO is a requirement.

### **Rule 2: Routing**

* **MUST** use the go\_router package to implement all routing.  
* **MUST** generate clean, path-based URLs (e.g., /products/123).  
* **MUST NOT** use hash-based URLs (e.g., /\#/products/123).

### **Rule 3: Rendering Strategy for Search Bots**

* **MUST NOT** attempt to implement or claim to implement true, isomorphic Server-Side Rendering (SSR). This is not supported by Flutter.  
* **MUST** select one of two valid strategies for serving content to crawlers:  
  1. **Prerendering:** Implement a service (e.g., Prerender.io) to serve a static HTML snapshot to identified bot user-agents.  
  2. **Hybrid Architecture (Preferred):** For content-driven sites, generate the public-facing pages (blog, marketing) using a Static Site Generator like Static Shock. The Flutter app should handle the interactive, post-login experience.

### **Rule 4: On-Page Metadata (Titles, Descriptions, Social Tags)**

* **MUST** ensure every route has a unique, descriptive \<title\> and \<meta name="description"\> tag.  
* For applications where social media sharing is important, **MUST** implement a server-side injection mechanism (e.g., using Firebase Functions or another edge function). This function will detect bot user-agents (from Facebook, X, etc.), fetch the necessary data, and inject the correct Open Graph (og:title, og:image, etc.) tags into the HTML *before* serving it.  
* **MUST NOT** rely solely on client-side packages for metadata if robust social sharing is a requirement, as they fail for bots that do not execute JavaScript.

### **Rule 5: Structured Data**

* **MUST** generate and embed structured data using the JSON-LD format for relevant content (e.g., Product, Article, Event schemas).  
* **MUST** inject the JSON-LD \<script\> tag into the document's \<head\>. Server-side injection is the most reliable method to ensure crawlers see it.

### **Rule 6: Performance & Core Web Vitals**

* **MUST** prioritize reducing the initial application bundle size to improve Largest Contentful Paint (LCP).  
* The primary technique to achieve this is aggressive **code splitting** using Dart's deferred as keyword to load non-critical features on demand.  
* **MUST** implement standard asset optimizations, including image compression (using formats like WebP) and serving assets via a CDN.

### **Rule 7: Communication**

* When explaining solutions, **MUST** frame Flutter SEO as a set of deliberate architectural choices and workarounds, not as a native, out-of-the-box feature.  
* **MUST** clearly articulate the trade-offs of each strategy (e.g., prerendering cost vs. hybrid architecture complexity).
