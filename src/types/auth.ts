export interface User {
  id: string;
  name: string;
  email: string;
  avatar?: string;
  provider: "email" | "google" | "apple" | "microsoft";
}

export interface AuthState {
  user: User | null;
  isLoading: boolean;
}
