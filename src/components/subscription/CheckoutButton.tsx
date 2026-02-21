"use client";

import { useState } from "react";
import { useSubscription } from "@/contexts/SubscriptionContext";
import { Button } from "@/components/ui/Button";

export function CheckoutButton() {
  const { checkout } = useSubscription();
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState(false);

  const handleCheckout = async () => {
    setLoading(true);
    try {
      await checkout();
      setSuccess(true);
    } finally {
      setLoading(false);
    }
  };

  if (success) {
    return (
      <Button className="w-full" disabled>
        Upgraded!
      </Button>
    );
  }

  return (
    <Button className="w-full" onClick={handleCheckout} disabled={loading}>
      {loading ? "Processing..." : "Upgrade to Pro"}
    </Button>
  );
}
