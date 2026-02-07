"use client";

import { useState } from "react";

export default function CopyButton({ text }: { text: string }) {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <button
      onClick={handleCopy}
      className="flex-shrink-0 px-4 py-2 bg-[var(--portal-green)] text-black rounded-lg hover:bg-[var(--portal-green-dim)] transition-colors font-medium text-sm"
    >
      {copied ? "Copied! ✓" : "Copy"}
    </button>
  );
}
