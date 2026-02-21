import { NextResponse } from "next/server";
import { cookies } from "next/headers";

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { email, password, provider } = body;

    let user;
    if (provider) {
      const providerUsers: Record<string, { id: string; name: string; email: string; provider: string }> = {
        google: { id: "g-1", name: "Alex Developer", email: "alex@gmail.com", provider: "google" },
        apple: { id: "a-1", name: "Sam Coder", email: "sam@icloud.com", provider: "apple" },
        microsoft: { id: "m-1", name: "Jordan Engineer", email: "jordan@outlook.com", provider: "microsoft" },
      };
      user = providerUsers[provider];
      if (!user) {
        return NextResponse.json({ error: "Unknown provider" }, { status: 400 });
      }
    } else {
      if (!email) {
        return NextResponse.json({ error: "Email is required" }, { status: 400 });
      }
      user = {
        id: "u-" + Math.random().toString(36).substring(2, 9),
        name: email.split("@")[0],
        email,
        provider: "email",
      };
    }

    const cookieStore = await cookies();
    cookieStore.set("auth-token", btoa(JSON.stringify(user)), {
      httpOnly: true,
      secure: process.env.NODE_ENV === "production",
      sameSite: "lax",
      maxAge: 60 * 60 * 24 * 7,
      path: "/",
    });

    return NextResponse.json({ user });
  } catch {
    return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  }
}
