"use client";

import { useEffect, useRef } from "react";

declare global {
  interface Window {
    PayPal?: {
      Donation: {
        Button: (config: {
          env: string;
          hosted_button_id: string;
          image: {
            src: string;
            alt: string;
            title: string;
          };
        }) => {
          render: (selector: string) => void;
        };
      };
    };
  }
}

export default function PayPalButton() {
  const containerRef = useRef<HTMLDivElement>(null);
  const scriptLoaded = useRef(false);

  useEffect(() => {
    if (scriptLoaded.current) return;
    scriptLoaded.current = true;

    const script = document.createElement("script");
    script.src = "https://www.paypalobjects.com/donate/sdk/donate-sdk.js";
    script.charset = "UTF-8";
    script.async = true;

    script.onload = () => {
      if (window.PayPal && containerRef.current) {
        window.PayPal.Donation.Button({
          env: "production",
          hosted_button_id: "RX48PSTKCNCP2",
          image: {
            src: "https://pics.paypal.com/00/s/ZjVjODM5ODYtOTA0Zi00ZjYzLWE4YzAtNGEzNWRiYWNhYzZk/file.PNG",
            alt: "Donate with PayPal button",
            title: "PayPal - The safer, easier way to pay online!",
          },
        }).render("#paypal-donate-button");
      }
    };

    document.body.appendChild(script);

    return () => {
      // Cleanup on unmount
      if (script.parentNode) {
        script.parentNode.removeChild(script);
      }
    };
  }, []);

  return (
    <div ref={containerRef} className="flex justify-center">
      <div id="paypal-donate-button"></div>
    </div>
  );
}
