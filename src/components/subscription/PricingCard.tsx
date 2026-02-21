import { cn } from "@/lib/utils";

interface PricingCardProps {
  name: string;
  price: string;
  period?: string;
  features: string[];
  isPopular?: boolean;
  isCurrent?: boolean;
  action?: React.ReactNode;
}

export function PricingCard({
  name,
  price,
  period,
  features,
  isPopular,
  isCurrent,
  action,
}: PricingCardProps) {
  return (
    <div
      className={cn(
        "rounded-xl p-8 relative",
        isPopular
          ? "border-2 border-blue-500 bg-dark-800"
          : "border border-dark-700 bg-dark-800"
      )}
    >
      {isPopular && (
        <div className="absolute -top-3 left-1/2 -translate-x-1/2 bg-blue-600 text-white text-xs font-semibold px-3 py-1 rounded-full">
          Popular
        </div>
      )}
      {isCurrent && (
        <div className="absolute -top-3 left-1/2 -translate-x-1/2 bg-green-600 text-white text-xs font-semibold px-3 py-1 rounded-full">
          Current Plan
        </div>
      )}
      <h3 className="text-lg font-semibold text-white mb-2">{name}</h3>
      <div className="flex items-baseline gap-1 mb-1">
        <span className="text-4xl font-bold text-white">{price}</span>
        {period && <span className="text-dark-400 text-sm">{period}</span>}
      </div>
      <ul className="text-sm text-dark-300 space-y-3 mt-6 mb-8">
        {features.map((feature) => (
          <li key={feature} className="flex items-center gap-2">
            <svg
              className="w-4 h-4 text-green-400 shrink-0"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={2}
            >
              <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
            </svg>
            {feature}
          </li>
        ))}
      </ul>
      {action}
    </div>
  );
}
