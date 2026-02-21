import { NextResponse } from "next/server";
import { cookies } from "next/headers";

export async function POST() {
  // Simulate payment processing delay
  await new Promise((resolve) => setTimeout(resolve, 1000));

  const cookieStore = await cookies();
  cookieStore.set("subscription-tier", "pro", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    maxAge: 60 * 60 * 24 * 30,
    path: "/",
  });

  return NextResponse.json({ success: true, tier: "pro" });
}
