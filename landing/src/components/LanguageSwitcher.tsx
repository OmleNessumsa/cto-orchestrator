"use client";

import { useState, useRef, useEffect } from "react";
import { usePathname } from "next/navigation";
import { locales, localeNames, localeFlags, type Locale } from "@/i18n/config";
import { GA_EVENTS } from "./GoogleAnalytics";

export default function LanguageSwitcher({
  currentLocale,
}: {
  currentLocale: Locale;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const pathname = usePathname();

  useEffect(() => {
    function handleClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClick);
    return () => document.removeEventListener("mousedown", handleClick);
  }, []);

  function switchLocale(newLocale: Locale) {
    // Track language switch
    GA_EVENTS.languageSwitch(currentLocale, newLocale);

    // Replace the current locale in the path
    const segments = pathname.split("/");
    segments[1] = newLocale;
    window.location.href = segments.join("/");
  }

  return (
    <div ref={ref} className="relative z-50">
      <button
        onClick={() => setOpen(!open)}
        className="flex items-center gap-2 px-3 py-2 rounded-lg border border-[var(--portal-green)]/30 bg-[var(--space-blue)]/80 hover:border-[var(--portal-green)]/60 transition-colors text-sm backdrop-blur-sm"
        aria-label="Select language"
      >
        <span>{localeFlags[currentLocale]}</span>
        <span className="text-gray-300 hidden sm:inline">
          {localeNames[currentLocale]}
        </span>
        <svg
          className={`w-4 h-4 text-gray-400 transition-transform ${open ? "rotate-180" : ""}`}
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M19 9l-7 7-7-7"
          />
        </svg>
      </button>

      {open && (
        <div className="absolute right-0 top-full mt-2 min-w-[160px] rounded-lg border border-[var(--portal-green)]/20 bg-[var(--space-blue)] shadow-xl shadow-black/50 overflow-hidden backdrop-blur-sm">
          {locales.map((locale) => (
            <button
              key={locale}
              onClick={() => {
                switchLocale(locale);
                setOpen(false);
              }}
              className={`w-full flex items-center gap-3 px-4 py-3 text-sm hover:bg-[var(--portal-green)]/10 transition-colors ${
                locale === currentLocale
                  ? "text-[var(--portal-green)] bg-[var(--portal-green)]/5"
                  : "text-gray-300"
              }`}
            >
              <span>{localeFlags[locale]}</span>
              <span>{localeNames[locale]}</span>
              {locale === currentLocale && (
                <span className="ml-auto text-[var(--portal-green)]">✓</span>
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
