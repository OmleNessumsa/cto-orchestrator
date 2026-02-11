"use client";

import { useState } from "react";
import { GA_EVENTS } from "./GoogleAnalytics";
import PayPalButton from "./PayPalButton";

interface PaymentGateProps {
  /** Translated strings */
  t: {
    buy_title: string;
    buy_subtitle: string;
    buy_button: string;
    buy_price: string;
    buy_processing: string;
    buy_error: string;
    buy_powered_by: string;
  };
  installCommand: string;
}

export default function PaymentGate({ t, installCommand }: PaymentGateProps) {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handlePayment = async () => {
    setLoading(true);
    setError(null);

    // Track payment initiation
    GA_EVENTS.paymentInitiated();

    try {
      const res = await fetch("/api/create-charge", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
      });

      if (!res.ok) {
        throw new Error("Failed to create charge");
      }

      const data = await res.json();

      if (data.hosted_url) {
        // Redirect to Coinbase Commerce hosted checkout
        window.location.href = data.hosted_url;
      } else {
        throw new Error("No checkout URL received");
      }
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : "Unknown error";
      GA_EVENTS.paymentFailed(errorMsg);
      setError(t.buy_error);
      setLoading(false);
    }
  };

  return (
    <div className="text-center">
      {/* Price display */}
      <div className="mb-8">
        <div className="inline-flex items-center gap-3 px-6 py-3 rounded-full bg-[var(--space-purple)] border border-[var(--portal-green)]/30">
          <span className="text-3xl">⟠</span>
          <div className="text-left">
            <div className="text-2xl font-bold text-[var(--portal-green)]">
              {t.buy_price}
            </div>
            <div className="text-xs text-gray-400">Ethereum (ETH)</div>
          </div>
        </div>
      </div>

      {/* Install command preview (blurred) */}
      <div className="code-block rounded-xl p-6 mb-8 relative overflow-hidden">
        <div className="blur-sm select-none pointer-events-none">
          <code className="text-[var(--portal-green)] text-sm md:text-base break-all">
            {installCommand}
          </code>
        </div>
        <div className="absolute inset-0 flex items-center justify-center bg-black/40 backdrop-blur-[2px]">
          <div className="flex items-center gap-2 text-[var(--morty-yellow)] font-bold">
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
              <path
                fillRule="evenodd"
                d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z"
                clipRule="evenodd"
              />
            </svg>
            <span>{t.buy_subtitle}</span>
          </div>
        </div>
      </div>

      {/* Pay button */}
      <button
        onClick={handlePayment}
        disabled={loading}
        className="px-10 py-4 bg-[var(--portal-green)] text-black font-bold text-lg rounded-full 
                   hover:bg-[var(--portal-green-dim)] transition-all hover:scale-105 portal-glow
                   disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:scale-100
                   flex items-center gap-3 mx-auto"
      >
        {loading ? (
          <>
            <svg
              className="animate-spin h-5 w-5"
              viewBox="0 0 24 24"
              fill="none"
            >
              <circle
                className="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                strokeWidth="4"
              />
              <path
                className="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
              />
            </svg>
            {t.buy_processing}
          </>
        ) : (
          <>
            <span className="text-xl">⟠</span>
            {t.buy_button}
          </>
        )}
      </button>

      {/* Error message */}
      {error && (
        <p className="mt-4 text-red-400 text-sm">{error}</p>
      )}

      {/* Powered by Coinbase */}
      <p className="mt-6 text-gray-500 text-xs">
        {t.buy_powered_by}
      </p>

      {/* Divider */}
      <div className="flex items-center gap-4 my-8">
        <div className="flex-1 h-px bg-gray-700"></div>
        <span className="text-gray-500 text-sm">or</span>
        <div className="flex-1 h-px bg-gray-700"></div>
      </div>

      {/* PayPal option */}
      <div className="text-center">
        <p className="text-gray-400 text-sm mb-4">No crypto? No problem!</p>
        <PayPalButton />
      </div>
    </div>
  );
}
