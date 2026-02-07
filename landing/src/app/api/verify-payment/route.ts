import { NextResponse } from "next/server";

/**
 * GET /api/verify-payment?charge_id=xxx
 *
 * Verifies a Coinbase Commerce charge status.
 * Returns whether the payment has been confirmed.
 */

const COINBASE_API = "https://api.commerce.coinbase.com";

export async function GET(request: Request) {
  const apiKey = process.env.COINBASE_COMMERCE_API_KEY;

  if (!apiKey) {
    return NextResponse.json(
      { error: "Payment system not configured" },
      { status: 500 }
    );
  }

  const { searchParams } = new URL(request.url);
  const chargeId = searchParams.get("charge_id");

  if (!chargeId) {
    return NextResponse.json(
      { error: "Missing charge_id parameter" },
      { status: 400 }
    );
  }

  try {
    const res = await fetch(`${COINBASE_API}/charges/${chargeId}`, {
      headers: {
        "X-CC-Api-Key": apiKey,
        "X-CC-Version": "2018-03-22",
      },
    });

    if (!res.ok) {
      return NextResponse.json(
        { error: "Failed to verify charge" },
        { status: 502 }
      );
    }

    const data = await res.json();
    const charge = data.data;

    // Check timeline for confirmed payment
    const timeline = charge.timeline || [];
    const isConfirmed = timeline.some(
      (event: { status: string }) =>
        event.status === "COMPLETED" || event.status === "RESOLVED"
    );
    const isPending = timeline.some(
      (event: { status: string }) =>
        event.status === "PENDING"
    );

    return NextResponse.json({
      charge_id: charge.id,
      status: isConfirmed ? "confirmed" : isPending ? "pending" : "unresolved",
      confirmed: isConfirmed,
      payments: charge.payments || [],
    });
  } catch (err) {
    console.error("Error verifying payment:", err);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
