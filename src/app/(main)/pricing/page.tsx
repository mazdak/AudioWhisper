"use client";

import { useSubscription } from "@/contexts/SubscriptionContext";
import { PricingCard } from "@/components/subscription/PricingCard";
import { CheckoutButton } from "@/components/subscription/CheckoutButton";
import { Button } from "@/components/ui/Button";

export default function PricingPage() {
  const { tier, isPro } = useSubscription();

  return (
    <div className="max-w-4xl mx-auto px-4 py-12">
      <div className="text-center mb-12">
        <h1 className="text-3xl font-bold text-white mb-3">Choose your plan</h1>
        <p className="text-dark-400">
          Start free and upgrade when you need more power.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-2xl mx-auto">
        <PricingCard
          name="Free"
          price="$0"
          isCurrent={tier === "free"}
          features={[
            "10 messages per conversation",
            "3 conversations",
            "All AI models",
            "Syntax highlighting",
            "Code editor",
          ]}
          action={
            tier === "free" ? (
              <Button variant="secondary" className="w-full" disabled>
                Current Plan
              </Button>
            ) : null
          }
        />
        <PricingCard
          name="Pro"
          price="$5"
          period="/month"
          isPopular={!isPro}
          isCurrent={isPro}
          features={[
            "Unlimited messages",
            "Unlimited conversations",
            "All AI models",
            "Priority response speed",
            "Full Monaco editor",
          ]}
          action={
            isPro ? (
              <Button variant="secondary" className="w-full" disabled>
                Current Plan
              </Button>
            ) : (
              <CheckoutButton />
            )
          }
        />
      </div>
    </div>
  );
}
