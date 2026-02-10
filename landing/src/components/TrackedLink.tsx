"use client";

import { trackEvent } from "./GoogleAnalytics";

interface TrackedLinkProps {
  href: string;
  children: React.ReactNode;
  className?: string;
  trackingName: string;
  trackingSection: string;
  external?: boolean;
}

/**
 * A link that tracks clicks to Google Analytics before navigating.
 * Use for CTAs and important navigation elements.
 */
export default function TrackedLink({
  href,
  children,
  className,
  trackingName,
  trackingSection,
  external = false,
}: TrackedLinkProps) {
  const handleClick = () => {
    trackEvent("cta_click", {
      button_name: trackingName,
      section: trackingSection,
      destination: href,
    });
  };

  return (
    <a
      href={href}
      onClick={handleClick}
      className={className}
      {...(external && {
        target: "_blank",
        rel: "noopener noreferrer",
      })}
    >
      {children}
    </a>
  );
}
