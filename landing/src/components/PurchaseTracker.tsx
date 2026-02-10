"use client";

import { useEffect, useRef } from "react";
import { GA_EVENTS } from "./GoogleAnalytics";

/**
 * Tracks a successful purchase when this component mounts.
 * Place on the success/confirmation page.
 */
export default function PurchaseTracker() {
  const tracked = useRef(false);

  useEffect(() => {
    // Only track once per mount
    if (!tracked.current) {
      tracked.current = true;
      GA_EVENTS.paymentCompleted();
    }
  }, []);

  return null;
}
