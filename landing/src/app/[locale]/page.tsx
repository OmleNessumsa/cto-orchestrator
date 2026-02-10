import Image from "next/image";
import { type Locale } from "@/i18n/config";
import { getDictionary } from "@/i18n/getDictionary";
import LanguageSwitcher from "@/components/LanguageSwitcher";
import PaymentGate from "@/components/PaymentGate";
import StarField from "@/components/StarField";
import TrackedLink from "@/components/TrackedLink";

/* ─── tiny reusable sub-components (server-safe) ─── */

function WorkflowStep({
  number,
  title,
  description,
  command,
}: {
  number: number;
  title: string;
  description: string;
  command: string;
}) {
  return (
    <div className="flex gap-6 items-start">
      <div className="flex-shrink-0 w-12 h-12 rounded-full bg-[var(--portal-green)] text-black font-bold text-xl flex items-center justify-center portal-glow">
        {number}
      </div>
      <div className="flex-1">
        <h3 className="text-xl font-bold text-white mb-2">{title}</h3>
        <p className="text-gray-400 mb-3">{description}</p>
        <div className="code-block rounded-lg p-3 font-mono text-sm text-[var(--portal-green)] overflow-x-auto">
          <code>{command}</code>
        </div>
      </div>
    </div>
  );
}

function MortyCard({
  name,
  emoji,
  description,
  expertise,
}: {
  name: string;
  emoji: string;
  description: string;
  expertise: string[];
}) {
  return (
    <div className="morty-card rounded-xl p-6 h-full">
      <div className="text-4xl mb-3">{emoji}</div>
      <h3 className="text-xl font-bold text-[var(--portal-green)] mb-2">
        {name}
      </h3>
      <p className="text-gray-300 text-sm mb-4">{description}</p>
      <div className="flex flex-wrap gap-2">
        {expertise.map((skill) => (
          <span
            key={skill}
            className="text-xs px-2 py-1 rounded-full bg-[var(--space-purple)] text-[var(--rick-blue)] border border-[var(--rick-blue)]/20"
          >
            {skill}
          </span>
        ))}
      </div>
    </div>
  );
}

/* ─── page ─── */

export default async function Home({
  params,
}: {
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  const t = await getDictionary(locale as Locale);

  const installCommand =
    "curl -fsSL https://raw.githubusercontent.com/OmleNessumsa/cto-orchestrator/main/install.sh | bash";

  const mortys = [
    {
      ...t.mortys.architect,
      emoji: "🏗️",
      expertise: ["System Design", "API Design", "ADRs", "Architecture"],
    },
    {
      ...t.mortys.backend,
      emoji: "⚙️",
      expertise: ["APIs", "Databases", "Business Logic", "Unit Tests"],
    },
    {
      ...t.mortys.frontend,
      emoji: "🎨",
      expertise: ["React", "UI/UX", "Components", "Responsive"],
    },
    {
      ...t.mortys.tester,
      emoji: "🔍",
      expertise: ["E2E Tests", "QA", "Edge Cases", "Regression"],
    },
    {
      ...t.mortys.security,
      emoji: "🔐",
      expertise: ["OWASP", "Auth", "Penetration Testing", "Data Protection"],
    },
    {
      ...t.mortys.devops,
      emoji: "🚀",
      expertise: ["CI/CD", "Docker", "Deployment", "Monitoring"],
    },
  ];

  const features = [
    {
      icon: "🎫",
      title: t.features.ticket_title,
      description: t.features.ticket_description,
    },
    {
      icon: "🤖",
      title: t.features.autopilot_title,
      description: t.features.autopilot_description,
    },
    {
      icon: "🧠",
      title: t.features.smart_title,
      description: t.features.smart_description,
    },
    {
      icon: "📊",
      title: t.features.progress_title,
      description: t.features.progress_description,
    },
    {
      icon: "🔄",
      title: t.features.recovery_title,
      description: t.features.recovery_description,
    },
    {
      icon: "📝",
      title: t.features.docs_title,
      description: t.features.docs_description,
    },
  ];

  return (
    <div className="min-h-screen bg-[var(--background)] relative">
      <StarField />

      {/* Navigation bar with language switcher */}
      <nav className="fixed top-0 left-0 right-0 z-40 backdrop-blur-md bg-[var(--background)]/80 border-b border-[var(--portal-green)]/10">
        <div className="max-w-6xl mx-auto flex items-center justify-between px-4 py-3">
          <div className="flex items-center gap-2">
            <span className="text-xl">🧪</span>
            <span className="font-bold text-[var(--portal-green)] text-sm sm:text-base">
              CTO Orchestrator
            </span>
          </div>
          <LanguageSwitcher currentLocale={locale as Locale} />
        </div>
      </nav>

      {/* Hero Section */}
      <section className="relative min-h-screen flex items-center justify-center px-4 pt-28 pb-20">
        <div className="max-w-6xl mx-auto text-center relative z-10">
          {/* Hero Image */}
          <div className="relative w-72 h-72 md:w-96 md:h-96 mx-auto mb-8">
            <div className="absolute inset-0 rounded-full portal-glow opacity-50" />
            <Image
              src="/hero-portal.png"
              alt="Rick Sanchez in front of a green portal with Morty's emerging"
              width={400}
              height={400}
              priority
              className="relative z-10 object-contain drop-shadow-[0_0_30px_rgba(57,255,20,0.4)]"
            />
          </div>

          <h1 className="text-5xl md:text-7xl font-bold mb-6">
            <span className="text-[var(--portal-green)] portal-glow-text">
              {t.hero.title1}
            </span>
            <br />
            <span className="text-white">{t.hero.title2}</span>
          </h1>

          <p className="text-xl md:text-2xl text-gray-300 max-w-3xl mx-auto mb-4 leading-relaxed">
            <em>{t.hero.subtitle.split(" — ")[0]} —</em>{" "}
            {t.hero.subtitle.split(" — ")[1]}
          </p>

          <p className="text-lg text-gray-400 max-w-2xl mx-auto mb-8">
            {t.hero.description.split("{codeTag}")[0]}
            <code className="text-[var(--portal-green)] bg-[var(--space-blue)] px-2 py-1 rounded">
              claude -p
            </code>
            {t.hero.description.split("{codeTag}")[1]}
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center items-center mb-12">
            <TrackedLink
              href="#install"
              trackingName="install_now"
              trackingSection="hero"
              className="px-8 py-4 bg-[var(--portal-green)] text-black font-bold rounded-full hover:bg-[var(--portal-green-dim)] transition-all hover:scale-105 portal-glow"
            >
              {t.hero.cta_primary}
            </TrackedLink>
            <TrackedLink
              href="#how-it-works"
              trackingName="how_it_works"
              trackingSection="hero"
              className="px-8 py-4 border border-[var(--portal-green)] text-[var(--portal-green)] font-bold rounded-full hover:bg-[var(--portal-green)]/10 transition-all"
            >
              {t.hero.cta_secondary}
            </TrackedLink>
          </div>

          <div className="text-[var(--morty-yellow)] text-lg font-bold">
            {t.hero.tagline}
          </div>
        </div>

        {/* Scroll indicator */}
        <div className="absolute bottom-8 left-1/2 transform -translate-x-1/2 animate-bounce">
          <svg
            className="w-6 h-6 text-[var(--portal-green)]"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M19 14l-7 7m0 0l-7-7m7 7V3"
            />
          </svg>
        </div>
      </section>

      {/* How It Works Section */}
      <section id="how-it-works" className="py-20 px-4 relative">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-4xl font-bold text-center mb-4">
            <span className="gradient-text">{t.howItWorks.title}</span>
          </h2>
          <p className="text-gray-400 text-center mb-8 text-lg">
            {t.howItWorks.subtitle}
          </p>

          <div className="mb-12 p-4 rounded-xl bg-[var(--portal-green)]/5 border border-[var(--portal-green)]/20 text-center">
            <p className="text-[var(--portal-green)] text-sm font-medium">
              {t.howItWorks.usage_tip}
            </p>
          </div>

          <div className="space-y-12">
            <WorkflowStep
              number={1}
              title={t.howItWorks.step1_title}
              description={t.howItWorks.step1_description}
              command={t.howItWorks.step1_command}
            />
            <div className="h-8 border-l-2 border-dashed border-[var(--portal-green)]/30 ml-6" />
            <WorkflowStep
              number={2}
              title={t.howItWorks.step2_title}
              description={t.howItWorks.step2_description}
              command={t.howItWorks.step2_command}
            />
            <div className="h-8 border-l-2 border-dashed border-[var(--portal-green)]/30 ml-6" />
            <WorkflowStep
              number={3}
              title={t.howItWorks.step3_title}
              description={t.howItWorks.step3_description}
              command={t.howItWorks.step3_command}
            />
            <div className="h-8 border-l-2 border-dashed border-[var(--portal-green)]/30 ml-6" />
            <WorkflowStep
              number={4}
              title={t.howItWorks.step4_title}
              description={t.howItWorks.step4_description}
              command={t.howItWorks.step4_command}
            />
          </div>
        </div>
      </section>

      {/* The Morty's Section */}
      <section className="py-20 px-4 bg-[var(--space-blue)]/50 relative">
        <div className="max-w-6xl mx-auto">
          <h2 className="text-4xl font-bold text-center mb-4">
            <span className="text-[var(--morty-yellow)]">
              {t.mortys.title_highlight}
            </span>
            <span className="text-white">{t.mortys.title_suffix}</span>
          </h2>
          <p className="text-gray-400 text-center mb-16 text-lg max-w-2xl mx-auto">
            {t.mortys.subtitle}
          </p>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            {mortys.map((morty) => (
              <MortyCard key={morty.name} {...morty} />
            ))}
          </div>

          <div className="mt-12 text-center">
            <p className="text-gray-400 italic">
              {t.mortys.plus_text
                .split("{fullstack}")[0]}
              <span className="text-[var(--rick-blue)]">Fullstack-Morty</span>
              {t.mortys.plus_text
                .split("{fullstack}")[1]
                ?.split("{reviewer}")[0]}
              <span className="text-[var(--rick-blue)]">Reviewer-Morty</span>
              {t.mortys.plus_text
                .split("{reviewer}")[1]}
            </p>
          </div>
        </div>
      </section>

      {/* Mr. Meeseeks Section */}
      <section className="py-20 px-4 relative">
        <div className="max-w-4xl mx-auto">
          <div className="meeseeks-card rounded-2xl p-8 md:p-12 relative overflow-hidden">
            {/* Background decoration */}
            <div className="absolute -top-4 -right-4 w-48 h-48 opacity-10 select-none pointer-events-none">
              <Image
                src="/mr-meeseeks.png"
                alt=""
                width={192}
                height={192}
                className="object-contain"
              />
            </div>

            <div className="relative z-10">
              <div className="flex items-center gap-4 mb-6">
                <div className="w-16 h-16 flex-shrink-0 relative">
                  <Image
                    src="/mr-meeseeks.png"
                    alt="Mr. Meeseeks"
                    width={64}
                    height={64}
                    className="object-contain drop-shadow-[0_0_12px_rgba(91,206,250,0.5)]"
                  />
                </div>
                <div>
                  <h2 className="text-3xl md:text-4xl font-bold">
                    <span className="text-[#5bcefa]">
                      {t.meeseeks.title}
                    </span>
                  </h2>
                  <p className="text-[#5bcefa]/60 font-mono text-sm mt-1">
                    {t.meeseeks.tagline}
                  </p>
                </div>
              </div>

              <p className="text-gray-300 text-lg mb-8 max-w-2xl">
                {t.meeseeks.description}
              </p>

              {/* Usage examples */}
              <div className="space-y-4 mb-8">
                <div className="code-block rounded-lg p-4">
                  <p className="text-gray-500 text-xs mb-1">{t.meeseeks.example1_label}</p>
                  <code className="text-[#5bcefa] text-sm">
                    python scripts/meeseeks.py &quot;{t.meeseeks.example1_task}&quot;
                  </code>
                </div>
                <div className="code-block rounded-lg p-4">
                  <p className="text-gray-500 text-xs mb-1">{t.meeseeks.example2_label}</p>
                  <code className="text-[#5bcefa] text-sm">
                    python scripts/meeseeks.py &quot;{t.meeseeks.example2_task}&quot; --files src/auth.py
                  </code>
                </div>
              </div>

              {/* How it works */}
              <div className="grid md:grid-cols-3 gap-4">
                <div className="bg-[#5bcefa]/5 border border-[#5bcefa]/20 rounded-xl p-4 text-center">
                  <div className="text-2xl mb-2">📦</div>
                  <h4 className="font-bold text-[#5bcefa] text-sm">{t.meeseeks.step1_title}</h4>
                  <p className="text-gray-400 text-xs mt-1">{t.meeseeks.step1_desc}</p>
                </div>
                <div className="bg-[#5bcefa]/5 border border-[#5bcefa]/20 rounded-xl p-4 text-center">
                  <div className="text-2xl mb-2">⚡</div>
                  <h4 className="font-bold text-[#5bcefa] text-sm">{t.meeseeks.step2_title}</h4>
                  <p className="text-gray-400 text-xs mt-1">{t.meeseeks.step2_desc}</p>
                </div>
                <div className="bg-[#5bcefa]/5 border border-[#5bcefa]/20 rounded-xl p-4 text-center">
                  <div className="text-2xl mb-2">💨</div>
                  <h4 className="font-bold text-[#5bcefa] text-sm">{t.meeseeks.step3_title}</h4>
                  <p className="text-gray-400 text-xs mt-1">{t.meeseeks.step3_desc}</p>
                </div>
              </div>

              <div className="mt-6 p-3 rounded-lg bg-[#5bcefa]/5 border border-[#5bcefa]/20">
                <p className="text-[#5bcefa] text-sm font-medium">
                  {t.meeseeks.mention_tip}
                </p>
              </div>

              <p className="mt-4 text-gray-500 text-sm italic">
                {t.meeseeks.warning}
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Team Collaboration Section */}
      <section className="py-20 px-4 bg-[var(--space-blue)]/30 relative">
        <div className="max-w-6xl mx-auto">
          <h2 className="text-4xl font-bold text-center mb-4">
            <span className="text-[var(--portal-green)]">🤝 {t.teams.title}</span>
          </h2>
          <p className="text-gray-400 text-center mb-4 text-lg max-w-2xl mx-auto">
            {t.teams.subtitle}
          </p>
          <p className="text-gray-500 text-center mb-12 max-w-2xl mx-auto">
            {t.teams.description}
          </p>

          {/* Team Templates */}
          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4 mb-12">
            <div className="morty-card rounded-xl p-5 text-center">
              <div className="text-3xl mb-2">🏗️</div>
              <h4 className="font-bold text-[var(--portal-green)] mb-1">{t.teams.template1_name}</h4>
              <p className="text-gray-400 text-sm">{t.teams.template1_desc}</p>
            </div>
            <div className="morty-card rounded-xl p-5 text-center">
              <div className="text-3xl mb-2">⚙️</div>
              <h4 className="font-bold text-[var(--portal-green)] mb-1">{t.teams.template2_name}</h4>
              <p className="text-gray-400 text-sm">{t.teams.template2_desc}</p>
            </div>
            <div className="morty-card rounded-xl p-5 text-center">
              <div className="text-3xl mb-2">🔐</div>
              <h4 className="font-bold text-[var(--portal-green)] mb-1">{t.teams.template3_name}</h4>
              <p className="text-gray-400 text-sm">{t.teams.template3_desc}</p>
            </div>
            <div className="morty-card rounded-xl p-5 text-center">
              <div className="text-3xl mb-2">🚀</div>
              <h4 className="font-bold text-[var(--portal-green)] mb-1">{t.teams.template4_name}</h4>
              <p className="text-gray-400 text-sm">{t.teams.template4_desc}</p>
            </div>
          </div>

          {/* Team Features */}
          <div className="grid md:grid-cols-3 gap-6 mb-8">
            <div className="bg-[var(--portal-green)]/5 border border-[var(--portal-green)]/20 rounded-xl p-5 text-center">
              <div className="text-2xl mb-2">⚡</div>
              <h4 className="font-bold text-[var(--portal-green)] text-sm">{t.teams.feature1_title}</h4>
              <p className="text-gray-400 text-xs mt-1">{t.teams.feature1_desc}</p>
            </div>
            <div className="bg-[var(--portal-green)]/5 border border-[var(--portal-green)]/20 rounded-xl p-5 text-center">
              <div className="text-2xl mb-2">🧠</div>
              <h4 className="font-bold text-[var(--portal-green)] text-sm">{t.teams.feature2_title}</h4>
              <p className="text-gray-400 text-xs mt-1">{t.teams.feature2_desc}</p>
            </div>
            <div className="bg-[var(--portal-green)]/5 border border-[var(--portal-green)]/20 rounded-xl p-5 text-center">
              <div className="text-2xl mb-2">💬</div>
              <h4 className="font-bold text-[var(--portal-green)] text-sm">{t.teams.feature3_title}</h4>
              <p className="text-gray-400 text-xs mt-1">{t.teams.feature3_desc}</p>
            </div>
          </div>

          {/* Example command */}
          <div className="code-block rounded-lg p-4 max-w-3xl mx-auto">
            <code className="text-[var(--portal-green)] text-sm break-all">
              {t.teams.example_command}
            </code>
          </div>
        </div>
      </section>

      {/* Unity Section */}
      <section className="py-20 px-4 relative">
        <div className="max-w-4xl mx-auto">
          <div className="morty-card rounded-2xl p-8 md:p-12 relative overflow-hidden border-2 border-[var(--portal-green)]/30">
            <div className="relative z-10">
              <div className="flex items-center gap-4 mb-6">
                <div className="w-16 h-16 rounded-full bg-[var(--portal-green)]/20 flex items-center justify-center text-4xl">
                  🛡️
                </div>
                <div>
                  <h2 className="text-3xl md:text-4xl font-bold">
                    <span className="text-[var(--portal-green)]">{t.unity.title}</span>
                  </h2>
                  <p className="text-[var(--portal-green)]/60 font-mono text-sm mt-1">
                    {t.unity.tagline}
                  </p>
                </div>
              </div>

              <p className="text-gray-300 text-lg mb-4 max-w-2xl">
                {t.unity.description}
              </p>
              <p className="text-gray-500 mb-8 max-w-2xl">
                {t.unity.vs_morty}
              </p>

              {/* Unity Features */}
              <div className="grid md:grid-cols-3 gap-4 mb-8">
                <div className="bg-[var(--portal-green)]/5 border border-[var(--portal-green)]/20 rounded-xl p-4 text-center">
                  <div className="text-2xl mb-2">🎯</div>
                  <h4 className="font-bold text-[var(--portal-green)] text-sm">{t.unity.feature1_title}</h4>
                  <p className="text-gray-400 text-xs mt-1">{t.unity.feature1_desc}</p>
                </div>
                <div className="bg-[var(--portal-green)]/5 border border-[var(--portal-green)]/20 rounded-xl p-4 text-center">
                  <div className="text-2xl mb-2">📋</div>
                  <h4 className="font-bold text-[var(--portal-green)] text-sm">{t.unity.feature2_title}</h4>
                  <p className="text-gray-400 text-xs mt-1">{t.unity.feature2_desc}</p>
                </div>
                <div className="bg-[var(--portal-green)]/5 border border-[var(--portal-green)]/20 rounded-xl p-4 text-center">
                  <div className="text-2xl mb-2">🔄</div>
                  <h4 className="font-bold text-[var(--portal-green)] text-sm">{t.unity.feature3_title}</h4>
                  <p className="text-gray-400 text-xs mt-1">{t.unity.feature3_desc}</p>
                </div>
              </div>

              {/* Example command */}
              <div className="code-block rounded-lg p-4">
                <code className="text-[var(--portal-green)] text-sm">
                  {t.unity.example_command}
                </code>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="py-20 px-4 relative">
        <div className="max-w-6xl mx-auto">
          <h2 className="text-4xl font-bold text-center mb-16">
            <span className="gradient-text">{t.features.title}</span>
          </h2>

          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-8">
            {features.map((feature) => (
              <div key={feature.title} className="morty-card rounded-xl p-6">
                <div className="text-4xl mb-4">{feature.icon}</div>
                <h3 className="text-xl font-bold text-white mb-2">
                  {feature.title}
                </h3>
                <p className="text-gray-400">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* Installation / Payment Section */}
      <section
        id="install"
        className="py-20 px-4 bg-[var(--space-purple)]/50 relative"
      >
        <div className="max-w-4xl mx-auto text-center">
          <h2 className="text-4xl font-bold mb-4">
            <span className="text-[var(--portal-green)]">
              {t.install.title}
            </span>
          </h2>
          <p className="text-gray-400 mb-8 text-lg">{t.install.buy_subtitle}</p>

          <PaymentGate
            t={{
              buy_title: t.install.buy_title,
              buy_subtitle: t.install.buy_locked_label,
              buy_button: t.install.buy_button,
              buy_price: t.install.buy_price,
              buy_processing: t.install.buy_processing,
              buy_error: t.install.buy_error,
              buy_powered_by: t.install.buy_powered_by,
            }}
            installCommand={installCommand}
          />

          <div className="mt-12 p-6 border border-[var(--morty-yellow)]/30 rounded-xl bg-[var(--morty-yellow)]/5">
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
        </div>
      </section>

      {/* Commands Reference Section */}
      <section className="py-20 px-4 relative">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-4xl font-bold text-center mb-16">
            <span className="gradient-text">{t.commands.title}</span>
          </h2>

          <div className="space-y-8">
            <div className="morty-card rounded-xl p-6">
              <h3 className="text-xl font-bold text-[var(--portal-green)] mb-4">
                {t.commands.orch_title}
              </h3>
              <div className="space-y-3 font-mono text-sm">
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    orchestrate.py plan &quot;...&quot;
                  </code>
                  <span className="text-gray-400">{t.commands.orch_plan}</span>
                </div>
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    orchestrate.py sprint
                  </code>
                  <span className="text-gray-400">
                    {t.commands.orch_sprint}
                  </span>
                </div>
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    orchestrate.py review
                  </code>
                  <span className="text-gray-400">
                    {t.commands.orch_review}
                  </span>
                </div>
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    orchestrate.py status
                  </code>
                  <span className="text-gray-400">
                    {t.commands.orch_status}
                  </span>
                </div>
              </div>
            </div>

            <div className="morty-card rounded-xl p-6">
              <h3 className="text-xl font-bold text-[var(--portal-green)] mb-4">
                {t.commands.ticket_title}
              </h3>
              <div className="space-y-3 font-mono text-sm">
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    ticket.py create --title &quot;...&quot;
                  </code>
                  <span className="text-gray-400">
                    {t.commands.ticket_create}
                  </span>
                </div>
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    ticket.py list
                  </code>
                  <span className="text-gray-400">
                    {t.commands.ticket_list}
                  </span>
                </div>
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    ticket.py board
                  </code>
                  <span className="text-gray-400">
                    {t.commands.ticket_board}
                  </span>
                </div>
              </div>
            </div>

            <div className="morty-card rounded-xl p-6">
              <h3 className="text-xl font-bold text-[var(--portal-green)] mb-4">
                {t.commands.delegate_title}
              </h3>
              <div className="space-y-3 font-mono text-sm">
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    delegate.py ID --agent backend-morty
                  </code>
                  <span className="text-gray-400">
                    {t.commands.delegate_send}
                  </span>
                </div>
                <div className="flex flex-col md:flex-row md:items-center gap-2">
                  <code className="text-[var(--portal-green)]">
                    delegate.py ID --dry-run
                  </code>
                  <span className="text-gray-400">
                    {t.commands.delegate_dry}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4 relative">
        <div className="max-w-4xl mx-auto text-center">
          <div className="portal-glow rounded-3xl p-12 bg-gradient-to-br from-[var(--space-blue)] to-[var(--space-purple)] border border-[var(--portal-green)]/20">
            <h2 className="text-4xl font-bold text-white mb-4">
              {t.cta.title}
            </h2>
            <p className="text-xl text-gray-300 mb-8">{t.cta.subtitle}</p>
            <TrackedLink
              href="#install"
              trackingName="install_cta"
              trackingSection="bottom_cta"
              className="inline-block px-10 py-4 bg-[var(--portal-green)] text-black font-bold text-lg rounded-full hover:bg-[var(--portal-green-dim)] transition-all hover:scale-105 portal-glow"
            >
              {t.cta.button}
            </TrackedLink>
            <p className="mt-6 text-[var(--morty-yellow)] text-sm">
              {t.cta.quote}
            </p>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="py-12 px-4 border-t border-[var(--portal-green)]/10">
        <div className="max-w-6xl mx-auto">
          <div className="flex flex-col md:flex-row justify-between items-center gap-6">
            <div className="flex items-center gap-3">
              <span className="text-2xl">🧪</span>
              <span className="font-bold text-[var(--portal-green)]">
                CTO Orchestrator
              </span>
            </div>
            <div className="flex gap-6 text-gray-400">
              <TrackedLink
                href="#how-it-works"
                trackingName="how_it_works"
                trackingSection="footer"
                className="hover:text-[var(--portal-green)] transition-colors"
              >
                {t.footer.how_it_works}
              </TrackedLink>
              <TrackedLink
                href="#install"
                trackingName="install"
                trackingSection="footer"
                className="hover:text-[var(--portal-green)] transition-colors"
              >
                {t.footer.install}
              </TrackedLink>
              <TrackedLink
                href="https://x.com/CtoSanchez40525"
                trackingName="support_twitter"
                trackingSection="footer"
                external
                className="hover:text-[var(--portal-green)] transition-colors"
              >
                {t.footer.support}
              </TrackedLink>
            </div>
            <div className="text-gray-500 text-sm">
              Built by Rick Sanchez (C-137) &bull; Dimension C-137
            </div>
          </div>
          <div className="mt-8 text-center text-gray-600 text-sm">
            <p>{t.footer.disclaimer}</p>
          </div>
        </div>
      </footer>
    </div>
  );
}
