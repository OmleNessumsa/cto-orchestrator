"use client";

import Script from "next/script";
import { usePathname, useSearchParams } from "next/navigation";
import { useEffect, Suspense } from "react";

// Your GA4 Measurement ID - replace with actual ID
const GA_MEASUREMENT_ID = process.env.NEXT_PUBLIC_GA_MEASUREMENT_ID;

// Declare gtag on window
declare global {
  interface Window {
    gtag: (
      command: string,
      targetId: string,
      config?: Record<string, unknown>
    ) => void;
    dataLayer: unknown[];
  }
}

// Custom event helper
export const trackEvent = (
  eventName: string,
  parameters?: Record<string, unknown>
) => {
  if (typeof window !== "undefined" && window.gtag && GA_MEASUREMENT_ID) {
    window.gtag("event", eventName, parameters);
  }
};

// Pre-defined events for CTO Orchestrator
export const GA_EVENTS = {
  // CTA clicks
  ctaInstallClick: () =>
    trackEvent("cta_click", {
      button_name: "install_now",
      section: "hero",
    }),
  ctaHowItWorksClick: () =>
    trackEvent("cta_click", {
      button_name: "how_it_works",
      section: "hero",
    }),
  ctaFooterInstall: () =>
    trackEvent("cta_click", {
      button_name: "install",
      section: "footer_cta",
    }),

  // Payment flow
  paymentInitiated: () =>
    trackEvent("begin_checkout", {
      currency: "ETH",
      value: 0.001,
      items: [{ item_name: "CTO Orchestrator" }],
    }),
  paymentCompleted: () =>
    trackEvent("purchase", {
      currency: "ETH",
      value: 0.001,
      transaction_id: Date.now().toString(),
      items: [{ item_name: "CTO Orchestrator" }],
    }),
  paymentFailed: (error?: string) =>
    trackEvent("payment_error", {
      error_message: error,
    }),

  // Navigation
  languageSwitch: (from: string, to: string) =>
    trackEvent("language_switch", {
      from_language: from,
      to_language: to,
    }),
  sectionView: (sectionName: string) =>
    trackEvent("section_view", {
      section_name: sectionName,
    }),

  // Engagement
  commandCopied: (command: string) =>
    trackEvent("copy_command", {
      command_type: command,
    }),
  externalLinkClick: (url: string, linkName: string) =>
    trackEvent("external_link_click", {
      link_url: url,
      link_name: linkName,
    }),
};

// Page view tracker component
function PageViewTracker() {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    if (!GA_MEASUREMENT_ID) return;

    const url = pathname + (searchParams?.toString() ? `?${searchParams.toString()}` : "");

    // Track page view
    window.gtag("config", GA_MEASUREMENT_ID, {
      page_path: url,
    });
  }, [pathname, searchParams]);

  return null;
}

// Main GA component
export default function GoogleAnalytics() {
  if (!GA_MEASUREMENT_ID) {
    return null;
  }

  return (
    <>
      {/* Google Analytics Script */}
      <Script
        src={`https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`}
        strategy="afterInteractive"
      />
      <Script id="google-analytics" strategy="afterInteractive">
        {`
          window.dataLayer = window.dataLayer || [];
          function gtag(){dataLayer.push(arguments);}
          gtag('js', new Date());
          gtag('config', '${GA_MEASUREMENT_ID}', {
            page_path: window.location.pathname,
            send_page_view: true
          });
        `}
      </Script>

      {/* Track page views on route change */}
      <Suspense fallback={null}>
        <PageViewTracker />
      </Suspense>
    </>
  );
}
