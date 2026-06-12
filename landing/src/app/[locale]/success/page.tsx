import { type Locale } from "@/i18n/config";
import { getDictionary } from "@/i18n/getDictionary";
import CopyButton from "@/components/CopyButton";
import StarField from "@/components/StarField";
import PurchaseTracker from "@/components/PurchaseTracker";
import TrackedLink from "@/components/TrackedLink";
import Link from "next/link";

/**
 * Rick IDE download URLs. Configure via env (e.g. Vercel Blob URLs) —
 * fall back to GitHub Releases asset paths once the repo goes public.
 */
const IDE_DOWNLOADS = {
  mac:
    process.env.RICK_IDE_DOWNLOAD_URL_MAC ||
    "https://github.com/OmleNessumsa/rick-ide/releases/latest",
  linux:
    process.env.RICK_IDE_DOWNLOAD_URL_LINUX ||
    "https://github.com/OmleNessumsa/rick-ide/releases/latest",
  windows:
    process.env.RICK_IDE_DOWNLOAD_URL_WIN ||
    "https://github.com/OmleNessumsa/rick-ide/releases/latest",
};

export default async function SuccessPage({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ product?: string }>;
}) {
  const { locale } = await params;
  const { product } = await searchParams;
  const t = await getDictionary(locale as Locale);
  const isRickIde = product === "rick-ide";

  const installCommand =
    "curl -fsSL https://raw.githubusercontent.com/OmleNessumsa/cto-orchestrator/main/install.sh | bash";

  return (
    <div className="min-h-screen bg-[var(--background)] relative flex items-center justify-center px-4">
      <StarField />
      <PurchaseTracker />

      <div className="max-w-2xl mx-auto text-center relative z-10 py-16">
        {/* Success animation */}
        <div className="text-8xl mb-6 animate-bounce">{isRickIde ? "🖥️" : "🧪"}</div>

        <h1 className="text-4xl md:text-5xl font-bold mb-4">
          <span className="text-[var(--portal-green)] portal-glow-text">
            {t.success.title}
          </span>
        </h1>

        <p className="text-xl text-gray-300 mb-8">
          {isRickIde ? t.success.ide_subtitle : t.success.subtitle}
        </p>

        {isRickIde ? (
          <>
            {/* Rick IDE download buttons (unlocked!) */}
            <div className="code-block rounded-xl p-6 mb-6">
              <h2 className="text-[var(--portal-green)] font-bold mb-4">
                {t.success.ide_download_title}
              </h2>
              <div className="grid sm:grid-cols-3 gap-3">
                <TrackedLink
                  href={IDE_DOWNLOADS.mac}
                  trackingName="download_ide_mac"
                  trackingSection="success"
                  external
                  className="px-4 py-3 bg-[var(--portal-green)] text-black font-bold rounded-xl hover:bg-[var(--portal-green-dim)] transition-all hover:scale-105"
                >
                   {t.success.ide_mac}
                </TrackedLink>
                <TrackedLink
                  href={IDE_DOWNLOADS.linux}
                  trackingName="download_ide_linux"
                  trackingSection="success"
                  external
                  className="px-4 py-3 border border-[var(--portal-green)] text-[var(--portal-green)] font-bold rounded-xl hover:bg-[var(--portal-green)]/10 transition-all"
                >
                  🐧 {t.success.ide_linux}
                </TrackedLink>
                <TrackedLink
                  href={IDE_DOWNLOADS.windows}
                  trackingName="download_ide_windows"
                  trackingSection="success"
                  external
                  className="px-4 py-3 border border-[var(--portal-green)] text-[var(--portal-green)] font-bold rounded-xl hover:bg-[var(--portal-green)]/10 transition-all"
                >
                  🪟 {t.success.ide_windows}
                </TrackedLink>
              </div>
            </div>

            {/* Post-download tip */}
            <div className="text-left code-block rounded-xl p-6 mb-8">
              <p className="text-gray-400 text-sm">{t.success.ide_tip}</p>
            </div>
          </>
        ) : (
          <>
            {/* Install command (unlocked!) */}
            <div className="code-block rounded-xl p-6 mb-6">
              <div className="flex items-center justify-between gap-4">
                <code className="text-[var(--portal-green)] text-sm md:text-base break-all text-left">
                  {installCommand}
                </code>
                <CopyButton text={installCommand} />
              </div>
            </div>

            {/* Post-install tip */}
            <div className="text-left code-block rounded-xl p-6 mb-8 space-y-3">
              <p className="text-gray-400 text-sm">{t.success.tip_title}</p>
              <div className="space-y-2 font-mono text-sm">
                <p className="text-[var(--portal-green)]">&gt; {t.success.tip_rick}</p>
                <p className="text-[#5bcefa]">&gt; {t.success.tip_meeseeks}</p>
              </div>
              <p className="text-gray-500 text-xs mt-2">{t.success.tip_description}</p>
            </div>

            {/* Requirements */}
            <div className="p-6 border border-[var(--morty-yellow)]/30 rounded-xl bg-[var(--morty-yellow)]/5 mb-8">
              <h3 className="text-[var(--morty-yellow)] font-bold mb-2">
                {t.install.requirements_title}
              </h3>
              <ul className="text-gray-400 space-y-1 text-left">
                <li>
                  •{" "}
                  {t.install.req1.split("{code}")[0]}
                  <code className="text-[var(--portal-green)]">claude</code>
                  {t.install.req1.split("{code}")[1]}
                </li>
                <li>• {t.install.req2}</li>
                <li>• {t.install.req3}</li>
              </ul>
            </div>
          </>
        )}

        <Link
          href={`/${locale}`}
          className="inline-block px-8 py-3 border border-[var(--portal-green)] text-[var(--portal-green)] font-bold rounded-full hover:bg-[var(--portal-green)]/10 transition-all"
        >
          {t.success.back_button}
        </Link>

        <p className="mt-8 text-[var(--morty-yellow)] text-sm italic">
          {isRickIde ? t.success.ide_quote : t.success.quote}
        </p>
      </div>
    </div>
  );
}
