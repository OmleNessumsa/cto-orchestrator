export const locales = ["en", "nl", "de", "es", "fr"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "en";

export const localeNames: Record<Locale, string> = {
  en: "English",
  nl: "Nederlands",
  de: "Deutsch",
  es: "Español",
  fr: "Français",
};

export const localeFlags: Record<Locale, string> = {
  en: "🇬🇧",
  nl: "🇳🇱",
  de: "🇩🇪",
  es: "🇪🇸",
  fr: "🇫🇷",
};
