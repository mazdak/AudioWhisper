import { NextResponse } from "next/server";
import { cookies } from "next/headers";

export async function POST() {
  const cookieStore = await cookies();
  cookieStore.delete("auth-token");
  cookieStore.delete("subscription-tier");
  return NextResponse.json({ success: true });
}
