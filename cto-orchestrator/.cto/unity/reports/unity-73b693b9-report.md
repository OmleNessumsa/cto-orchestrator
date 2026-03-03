# Unity Security Report

**Workflow ID:** unity-73b693b9
**Mode:** static
**Target:** /Users/elmo.asmussen/Projects/HelmLog
**Scope:** quick
**Completed:** 2026-02-12T14:18:10.726409+00:00

## Summary

| Severity | Count |
|----------|-------|
| 🔴 Critical | 0 |
| 🟠 High | 1 |
| 🟡 Medium | 3 |
| 🟢 Low | 3 |
| ℹ️ Info | 3 |

## Findings

### 1. 🟠 Hardcoded API Key in Source Code

**Severity:** high
**Category:** A02:2021 - Cryptographic Failures / Sensitive Data Exposure
**File:** src/services/tidesService.ts:13

The WorldTides API key is hardcoded directly in the source code: 'f8cabccd-bf75-49bb-bec1-3fc2abc2745d'. This key is exposed in version control and could be extracted from the compiled application.

**Recommendation:** Move API keys to environment variables or a secure configuration service. Use react-native-config or similar to load secrets at build time. For production, consider a backend proxy to hide API keys from the client.

---

### 2. 🟡 Placeholder API Keys in Code

**Severity:** medium
**Category:** A02:2021 - Cryptographic Failures / Sensitive Data Exposure
**File:** src/services/purchaseService.ts:16

RevenueCat API key placeholders ('appl_YOUR_IOS_API_KEY_HERE', 'goog_YOUR_ANDROID_API_KEY_HERE') are stored in source code. When real keys are added, they will be exposed in version control.

**Recommendation:** Use environment variables or a secrets management solution to inject API keys at build time rather than hardcoding them in source files.

---

### 3. 🟡 Insecure Local Storage for Sensitive Settings

**Severity:** medium
**Category:** A05:2021 - Security Misconfiguration
**File:** src/services/settingsService.ts:35

User settings and application state are stored in AsyncStorage, which is not encrypted. Sensitive data like user preferences and cached location data could be accessed by other apps or through device compromise.

**Recommendation:** Consider using react-native-keychain or expo-secure-store for sensitive data. Implement encryption for data stored in AsyncStorage if it contains PII or sensitive information.

---

### 4. 🟡 Dynamic Table Name in SQL PRAGMA

**Severity:** medium
**Category:** A03:2021 - Injection
**File:** src/services/database.ts:370

The runMigrations function interpolates a table name directly into a SQL PRAGMA statement without parameterization. While table names are controlled internally, this pattern could lead to SQL injection if the source of table names changes.

**Recommendation:** Use a whitelist of allowed table names and validate against it, or use parameterized queries where possible. Avoid string interpolation for SQL statements.

---

### 5. 🟢 Weak Share Code Generation

**Severity:** low
**Category:** A04:2021 - Insecure Design
**File:** src/services/tripSharingService.ts:53

The trip sharing feature uses Math.random() for generating share codes, which is not cryptographically secure. This could potentially allow an attacker to predict share codes.

**Recommendation:** When implementing the backend, use a cryptographically secure random number generator (crypto.getRandomValues or backend equivalent) for share code generation.

---

### 6. 🟢 Excessive Console Logging in Production

**Severity:** low
**Category:** A09:2021 - Security Logging and Monitoring Failures
**File:** src/services/locationService.ts:135

Multiple files contain console.log, console.warn, and console.error statements that will execute in production builds. This could leak sensitive information to device logs.

**Recommendation:** Implement a logging wrapper that suppresses logs in production builds, or use babel-plugin-transform-remove-console to strip console statements in release builds.

---

### 7. 🟢 React Native Version Potentially Outdated

**Severity:** low
**Category:** A06:2021 - Vulnerable and Outdated Components
**File:** package.json:24

The app uses React Native 0.72.17 which may have known security vulnerabilities. Newer versions often contain security patches.

**Recommendation:** Regularly update React Native and its dependencies to the latest stable versions. Review release notes for security-related fixes.

---

### 8. ℹ️ Debug Mode Settings Visible

**Severity:** info
**Category:** A05:2021 - Security Misconfiguration
**File:** src/services/purchaseService.ts:39

The purchaseService enables DEBUG log level when __DEV__ is true. Ensure this is properly stripped in production builds.

**Recommendation:** Verify that __DEV__ checks properly disable debug features in production builds.

---

### 9. ℹ️ XML Schema References Use HTTP

**Severity:** info
**Category:** Best Practice
**File:** src/services/exportService.ts:121

GPX export uses HTTP (not HTTPS) URLs for XML schema references. While this is standard for GPX format and doesn't transmit data, it's noted for completeness.

**Recommendation:** This is standard GPX format and not a security concern for data in transit, but note that GPX schemas use HTTP URLs by convention.

---

### 10. ℹ️ Proper SQL Parameterization Used

**Severity:** info
**Category:** Best Practice
**File:** src/services/database.ts:454

The database layer correctly uses parameterized queries (executeQuery, executeStatement) with params arrays, preventing SQL injection in most operations.

**Recommendation:** Continue using parameterized queries for all database operations.

---


---
*Generated by Unity — Rick's security specialist (Shannon pentest framework wrapper)*
