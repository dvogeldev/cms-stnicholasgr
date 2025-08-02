---

# **Project Architecture Document**  
**Headless WordPress with Next.js Frontend**  
**Date:** August 2, 2025  

---

## **1. Overview**  
This document outlines the architecture for a headless WordPress (WP) setup with a Next.js frontend. The goal is to create a scalable, performant, and user-friendly system for content creators and developers.  

---

## **2. Key Goals**  
- **For Content Creators:**  
  - Familiar WP backend experience with Blocksy child theme.  
  - Seamless content creation using ACF Pro, AIOSEO, and Gravity Forms.  
  - Custom capabilities (e.g., Glossary of Terms, Staff Directory, Timeline of Church) via plugins.  
- **For Developers:**  
  - Clean, scalable codebase with Next.js, TypeScript, and Tailwind CSS.  
  - Custom GraphQL API for efficient data fetching.  
  - Polished UI using Shadcn/UX patterns.  
- **For Users:**  
  - Fast, responsive, and engaging frontend experience.  
  - Optimized accessibility (WCAG, ARIA) and SEO.  
  - Support for multilingual content (e.g., Arabic).  

---

## **3. Technology Stack**  

### **WordPress Backend**  
- **Theme:**  
  - **Blocksy** (child theme) for production.  
  - **OllieWP** (development theme) for pattern extraction and conversion.  
- **Plugins:**  
  - **Core Functionality:**  
    - **ACF Pro:** Custom fields for structured content.  
    - **AIOSEO:** SEO optimization.  
    - **Gravity Forms:** Form management.  
    - **WP GraphQL:** GraphQL API for headless integration.  
    - **WP GraphQL for ACF:** Expose ACF fields via GraphQL.  
  - **Custom Capabilities:**  
    - **Glossary of Terms:** Custom plugin for managing and displaying glossary entries.  
    - **Staff Directory:** Custom plugin for managing staff profiles.  
    - **Timeline of Church:** Custom plugin for displaying historical events.  

### **Next.js Frontend**  
- **Core:**  
  - Next.js (App Router) for server-side rendering (SSR) and static site generation (SSG).  
  - TypeScript for type safety and scalability.  
- **Styling:**  
  - Tailwind CSS for utility-first styling.  
  - Shadcn for pre-built, accessible UI components.  
- **Data Fetching:**  
  - GraphQL (via WP GraphQL) for efficient data queries.  
- **Performance:**  
  - Image optimization, caching, and lazy loading.  

### **Infrastructure**  
- **CDN & Security:**  
  - CloudFlare for CDN, WAF, and other performance/security tools.  
- **Local Development:**  
  - Linux, Docker, and DDEV for local WP and Next.js development.  

---

## **4. Architecture Diagram**  
Here’s a high-level flow:  

```plaintext
WordPress Backend (Blocksy + Plugins)  
       ↓  
WP GraphQL API  
       ↓  
Next.js Frontend (Tailwind + Shadcn + TypeScript)  
       ↓  
User-Facing Website  
```

---

## **5. Development Workflow**  

### **Theme Conversion**  
1. Use OllieWP theme during development to extract patterns and components.  
2. Convert these patterns into reusable Blocksy child theme components.  
3. Ensure backend UI consistency for content creators.  

### **Frontend Development**  
1. Use Next.js App Router for routing and data fetching.  
2. Implement Tailwind CSS for styling, with Shadcn for UI components.  
3. Write GraphQL queries to fetch data from WP GraphQL API.  
4. Optimize for performance (e.g., image optimization, caching).  

---

## **6. Data Flow**  

### **Content Creation**  
1. Content creators use the WP backend with Blocksy child theme.  
2. ACF Pro fields are used to structure content.  
3. AIOSEO ensures SEO optimization.  
4. Gravity Forms handle user submissions.  
5. Custom plugins manage additional capabilities (e.g., Glossary, Staff Directory, Timeline).  

### **Data Fetching**  
1. Next.js frontend queries WP GraphQL API for content.  
2. WP GraphQL for ACF exposes custom fields.  
3. Custom plugin data is exposed via WP GraphQL.  
4. Data is rendered using Next.js components.  

---

## **7. Performance Optimization**  
- **Frontend:**  
  - Use Next.js Image component for optimized images.  
  - Implement lazy loading for non-critical resources.  
  - Use Tailwind’s PurgeCSS to remove unused styles.  
- **Backend:**  
  - Optimize WP GraphQL queries to reduce payload size.  
  - Use caching plugins or server-side caching.  

---

## **8. Scalability Considerations**  
- **Codebase:**  
  - Modularize components for reusability.  
  - Use TypeScript interfaces for consistent data structures.  
- **Infrastructure:**  
  - Consider a headless CMS hosting solution for WP (e.g., WP Engine).  
  - Use CloudFlare CDN for static assets.  

---

## **9. Additional Details**  

### **9.1 Content Migration**  
- Existing content will be refactored to align with new user stories and personas.  
- Focus on accessibility and SEO optimization.  

### **9.2 User Roles**  
- **Admin:** Full access to WP backend.  
- **Editor:** Limited to content creation and editing.  
- Only church administrative staff will interact with WP.  

### **9.3 Third-Party Integrations**  
- **Current:**  
  - Microsoft SharePoint  
  - BreezeCHMS (Church Management Software)  
- **Future:**  
  - Tithe.ly (donations)  
  - Venmo and Stripe (payment processing)  

### **9.4 Analytics**  
- Primary: Google Analytics.  
- Open to alternatives like Plausible for privacy-focused analytics.  

### **9.5 Local Development**  
- **Tools:** Linux, Docker, and DDEV.  
- **Workflow:**  
  - Use Docker containers for WP and Next.js.  
  - DDEV for local environment management.  

---

## **10. Accessibility (WCAG & ARIA)**  
- **Compliance:**  
  - Ensure the site meets **WCAG 2.1 AA** standards.  
  - Use ARIA roles and attributes for enhanced screen reader support.  
- **Testing:**  
  - Use tools like **axe DevTools**, **Lighthouse**, and **WAVE** for accessibility audits.  
  - Conduct manual testing with screen readers (e.g., NVDA, VoiceOver).  
- **Shadcn Components:**  
  - Leverage Shadcn’s built-in accessibility features for UI components.  

---

## **11. Multilingual Support (Arabic)**  
- **Implementation:**  
  - Use **WPML** or **Polylang** for multilingual content management in WordPress.  
  - Ensure RTL (right-to-left) support for Arabic language.  
- **Frontend:**  
  - Use **next-i18next** or **React Intl** for multilingual support in Next.js.  
  - Test RTL layouts with Tailwind CSS (e.g., `dir="rtl"`).  
- **SEO:**  
  - Implement hreflang tags for multilingual SEO.  

---

## **12. Custom Capabilities via Plugins**  
All custom functionalities will be implemented as WordPress plugins:  
1. **Glossary of Terms:**  
   - Manage and display glossary entries.  
   - Expose data via WP GraphQL for frontend rendering.  
2. **Staff Directory:**  
   - Manage staff profiles with ACF Pro fields.  
   - Expose data via WP GraphQL for frontend rendering.  
3. **Timeline of Church:**  
   - Manage historical events with ACF Pro fields.  
   - Expose data via WP GraphQL for frontend rendering.  

---

## **13. Next Steps**  
1. Finalize user stories and personas.  
2. Begin content refactoring and migration.  
3. Set up local development environment with Docker and DDEV.  
4. Start frontend development with Next.js and Tailwind CSS.  
5. Develop custom plugins for Glossary, Staff Directory, and Timeline.  
6. Integrate third-party services (SharePoint, BreezeCHMS).  
7. Implement accessibility and multilingual support.  

---