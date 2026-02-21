"use client";

import Link from "next/link";
import { useAuth } from "@/contexts/AuthContext";
import { useSubscription } from "@/contexts/SubscriptionContext";
import { Avatar } from "@/components/ui/Avatar";
import { Badge } from "@/components/ui/Badge";
import { useState } from "react";

export function Navbar() {
  const { user, logout } = useAuth();
  const { isPro } = useSubscription();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <nav className="border-b border-dark-800 bg-dark-950/80 backdrop-blur-sm sticky top-0 z-40">
      <div className="max-w-7xl mx-auto flex items-center justify-between px-4 h-14">
        <Link href={user ? "/chat" : "/"} className="flex items-center gap-2">
          <div className="w-7 h-7 rounded-lg bg-blue-600 flex items-center justify-center">
            <svg className="w-4 h-4 text-white" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2}>
              <path d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
            </svg>
          </div>
          <span className="font-bold text-white">CodeAssist AI</span>
        </Link>

        <div className="flex items-center gap-4">
          {user ? (
            <div className="relative">
              <button
                onClick={() => setMenuOpen(!menuOpen)}
                className="flex items-center gap-2 hover:opacity-80 transition-opacity"
              >
                <Badge variant={isPro ? "success" : "default"}>
                  {isPro ? "Pro" : "Free"}
                </Badge>
                <Avatar name={user.name} />
              </button>
              {menuOpen && (
                <>
                  <div className="fixed inset-0 z-40" onClick={() => setMenuOpen(false)} />
                  <div className="absolute right-0 top-full mt-2 w-48 rounded-lg border border-dark-700 bg-dark-800 shadow-xl z-50 py-1">
                    <div className="px-4 py-2 border-b border-dark-700">
                      <p className="text-sm font-medium text-white truncate">{user.name}</p>
                      <p className="text-xs text-dark-400 truncate">{user.email}</p>
                    </div>
                    <Link
                      href="/chat"
                      onClick={() => setMenuOpen(false)}
                      className="block px-4 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 transition-colors"
                    >
                      Chat
                    </Link>
                    <Link
                      href="/pricing"
                      onClick={() => setMenuOpen(false)}
                      className="block px-4 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 transition-colors"
                    >
                      Pricing
                    </Link>
                    <Link
                      href="/settings"
                      onClick={() => setMenuOpen(false)}
                      className="block px-4 py-2 text-sm text-dark-300 hover:text-white hover:bg-dark-700 transition-colors"
                    >
                      Settings
                    </Link>
                    <button
                      onClick={() => {
                        setMenuOpen(false);
                        logout();
                      }}
                      className="w-full text-left px-4 py-2 text-sm text-red-400 hover:bg-dark-700 transition-colors"
                    >
                      Sign Out
                    </button>
                  </div>
                </>
              )}
            </div>
          ) : (
            <div className="flex items-center gap-3">
              <Link
                href="/login"
                className="text-sm text-dark-300 hover:text-white transition-colors"
              >
                Sign In
              </Link>
              <Link
                href="/signup"
                className="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 transition-colors"
              >
                Get Started
              </Link>
            </div>
          )}
        </div>
      </div>
    </nav>
  );
}
