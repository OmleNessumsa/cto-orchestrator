import { NextResponse } from "next/server";

/**
 * POST /api/create-charge
 *
 * Creates a Coinbase Commerce charge for 0.00058 ETH.
 * Returns the hosted checkout URL for the user to complete payment.
 *
 * Requires COINBASE_COMMERCE_API_KEY env variable.
 */

const COINBASE_API = "https://api.commerce.coinbase.com";
const PRICE_ETH = "0.00058";

export async function POST(request: Request) {
  const apiKey = process.env.COINBASE_COMMERCE_API_KEY;

  if (!apiKey) {
    return NextResponse.json(
      { error: "Payment system not configured. Set COINBASE_COMMERCE_API_KEY." },
      { status: 500 }
    );
  }

  try {
    // Get the origin for redirect URLs
    const origin = new URL(request.url).origin;

    const res = await fetch(`${COINBASE_API}/charges`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CC-Api-Key": apiKey,
        "X-CC-Version": "2018-03-22",
      },
      body: JSON.stringify({
        name: "CTO Orchestrator — Rick Sanchez Skill",
        description:
          "The smartest CTO in the multiverse. Get Rick Sanchez as your AI CTO with an army of Morty sub-agents.",
        pricing_type: "fixed_price",
        local_price: {
          amount: PRICE_ETH,
          currency: "ETH",
        },
        metadata: {
          product: "cto-orchestrator-skill",
          version: "1.0",
        },
        redirect_url: `${origin}/en/success?status=completed`,
        cancel_url: `${origin}/en#install`,
      }),
    });

    if (!res.ok) {
      const errorBody = await res.text();
      console.error("Coinbase Commerce API error:", errorBody);
      return NextResponse.json(
        { error: "Failed to create charge" },
        { status: 502 }
      );
    }

    const data = await res.json();
    const charge = data.data;

    return NextResponse.json({
      charge_id: charge.id,
      hosted_url: charge.hosted_url,
      expires_at: charge.expires_at,
    });
  } catch (err) {
    console.error("Error creating charge:", err);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
