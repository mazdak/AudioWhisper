"use client";

import { createContext, useContext, useState, useEffect, useCallback, ReactNode } from "react";
import { Tier } from "@/types/subscription";

interface SubscriptionContextValue {
  tier: Tier;
  isLoading: boolean;
  checkout: () => Promise<void>;
  isPro: boolean;
}

const SubscriptionContext = createContext<SubscriptionContextValue | null>(null);

export function SubscriptionProvider({ children }: { children: ReactNode }) {
  const [tier, setTier] = useState<Tier>("free");
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetch("/api/subscription/status")
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (data?.tier) setTier(data.tier);
      })
      .catch(() => {})
      .finally(() => setIsLoading(false));
  }, []);

  const checkout = useCallback(async () => {
    setIsLoading(true);
    try {
      const res = await fetch("/api/subscription/checkout", { method: "POST" });
      if (res.ok) {
        const data = await res.json();
        setTier(data.tier);
      }
    } finally {
      setIsLoading(false);
    }
  }, []);

  return (
    <SubscriptionContext.Provider value={{ tier, isLoading, checkout, isPro: tier === "pro" }}>
      {children}
    </SubscriptionContext.Provider>
  );
}

export function useSubscription() {
  const context = useContext(SubscriptionContext);
  if (!context) throw new Error("useSubscription must be used within SubscriptionProvider");
  return context;
}
