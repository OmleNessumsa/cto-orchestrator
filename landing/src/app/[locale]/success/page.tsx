import { type Locale } from "@/i18n/config";
import { getDictionary } from "@/i18n/getDictionary";
import CopyButton from "@/components/CopyButton";
import StarField from "@/components/StarField";
import Link from "next/link";

export default async function SuccessPage({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getDictionary(locale as Locale);

  const installCommand =
    "curl -fsSL https://raw.githubusercontent.com/OmleNessumsa/cto-orchestrator/main/install.sh | bash";

  return (
    <div className="min-h-screen bg-[var(--background)] relative flex items-center justify-center px-4">
      <StarField />

      <div className="max-w-2xl mx-auto text-center relative z-10">
        {/* Success animation */}
        <div className="text-8xl mb-6 animate-bounce">🧪</div>

        <h1 className="text-4xl md:text-5xl font-bold mb-4">
          <span className="text-[var(--portal-green)] portal-glow-text">
            {t.success.title}
          </span>
        </h1>

        <p className="text-xl text-gray-300 mb-8">
          {t.success.subtitle}
        </p>

        {/* Install command (unlocked!) */}
        <div className="code-block rounded-xl p-6 mb-6">
          <div className="flex items-center justify-between gap-4">
            <code className="text-[var(--portal-green)] text-sm md:text-base break-all text-left">
              {installCommand}
            </code>
            <CopyButton text={installCommand} />
          </div>
        </div>

        {/* Manual install */}
        <div className="text-left code-block rounded-xl p-6 mb-8 space-y-2 font-mono text-sm">
          <p className="text-gray-500">{t.install.manual_comment1}</p>
          <p className="text-[var(--portal-green)]">
            git clone https://github.com/OmleNessumsa/cto-orchestrator.git
          </p>
          <p className="text-[var(--portal-green)]">cd cto-orchestrator</p>
          <p className="text-gray-500 mt-4">{t.install.manual_comment2}</p>
          <p className="text-[var(--portal-green)]">
            cp -r cto-orchestrator ~/.claude/skills/
          </p>
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

        <Link
          href={`/${locale}`}
          className="inline-block px-8 py-3 border border-[var(--portal-green)] text-[var(--portal-green)] font-bold rounded-full hover:bg-[var(--portal-green)]/10 transition-all"
        >
          {t.success.back_button}
        </Link>

        <p className="mt-8 text-[var(--morty-yellow)] text-sm italic">
          {t.success.quote}
        </p>
      </div>
    </div>
  );
}
