import { NextResponse } from "next/server";
import { cookies } from "next/headers";

export async function GET() {
  const cookieStore = await cookies();
  const tier = cookieStore.get("subscription-tier")?.value ?? "free";
  return NextResponse.json({ tier });
}
