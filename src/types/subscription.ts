export type Tier = "free" | "pro";

export interface SubscriptionState {
  tier: Tier;
  isLoading: boolean;
}
