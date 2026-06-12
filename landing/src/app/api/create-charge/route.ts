import { NextResponse } from "next/server";

/**
 * POST /api/create-charge
 *
 * Creates a Coinbase Commerce charge for one of Rick's products.
 * Body: { product?: "cto-orchestrator" | "rick-ide" }
 * Returns the hosted checkout URL for the user to complete payment.
 *
 * Requires COINBASE_COMMERCE_API_KEY env variable.
 */

const COINBASE_API = "https://api.commerce.coinbase.com";

const PRODUCTS = {
  "cto-orchestrator": {
    name: "CTO Orchestrator — Rick Sanchez Skill",
    description:
      "The smartest CTO in the multiverse. Get Rick Sanchez as your AI CTO with an army of Morty sub-agents.",
    price_eth: "0.001",
    metadata: { product: "cto-orchestrator-skill", version: "1.0" },
    success_path: "/en/success?status=completed",
    cancel_path: "/en#install",
  },
  "rick-ide": {
    name: "Rick IDE — Desktop App",
    description:
      "Mission control for the Morty army. Native desktop IDE for AI coding agents — multi-session terminals, live Kanban, cost tracking. macOS, Linux, Windows.",
    price_eth: "0.002",
    metadata: { product: "rick-ide", version: "0.2.35" },
    success_path: "/en/success?status=completed&product=rick-ide",
    cancel_path: "/en#rick-ide",
  },
} as const;

type ProductKey = keyof typeof PRODUCTS;

export async function POST(request: Request) {
  const apiKey = process.env.COINBASE_COMMERCE_API_KEY;

  if (!apiKey) {
    return NextResponse.json(
      { error: "Payment system not configured. Set COINBASE_COMMERCE_API_KEY." },
      { status: 500 }
    );
  }

  try {
    const body = await request.json().catch(() => ({}));
    const productKey: ProductKey =
      body?.product && body.product in PRODUCTS
        ? (body.product as ProductKey)
        : "cto-orchestrator";
    const product = PRODUCTS[productKey];

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
        name: product.name,
        description: product.description,
        pricing_type: "fixed_price",
        local_price: {
          amount: product.price_eth,
          currency: "ETH",
        },
        metadata: product.metadata,
        redirect_url: `${origin}${product.success_path}`,
        cancel_url: `${origin}${product.cancel_path}`,
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
