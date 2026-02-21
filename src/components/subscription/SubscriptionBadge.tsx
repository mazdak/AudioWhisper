"use client";

import { useSubscription } from "@/contexts/SubscriptionContext";
import { Badge } from "@/components/ui/Badge";

export function SubscriptionBadge() {
  const { isPro } = useSubscription();

  return (
    <Badge variant={isPro ? "success" : "default"}>
      {isPro ? "Pro" : "Free"}
    </Badge>
  );
}
