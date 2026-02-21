import { User } from "@/types/auth";

export const MOCK_RESPONSES: Record<string, string> = {
  default: `Here's an example of how to solve that:

\`\`\`typescript
function greet(name: string): string {
  return \`Hello, \${name}!\`;
}

console.log(greet("World"));
\`\`\`

This function takes a name parameter and returns a greeting string. You can modify it to suit your specific needs.`,

  react: `Here's a React component example:

\`\`\`tsx
import { useState } from 'react';

export function Counter() {
  const [count, setCount] = useState(0);

  return (
    <div className="flex flex-col items-center gap-4 p-6">
      <h2 className="text-2xl font-bold">Count: {count}</h2>
      <div className="flex gap-2">
        <button
          onClick={() => setCount(c => c - 1)}
          className="px-4 py-2 bg-red-500 text-white rounded"
        >
          Decrement
        </button>
        <button
          onClick={() => setCount(c => c + 1)}
          className="px-4 py-2 bg-blue-500 text-white rounded"
        >
          Increment
        </button>
      </div>
    </div>
  );
}
\`\`\`

This component uses the \`useState\` hook to manage a simple counter with increment and decrement buttons.`,

  python: `Here's a Python solution:

\`\`\`python
def fibonacci(n: int) -> list[int]:
    """Generate the first N Fibonacci numbers."""
    if n <= 0:
        return []
    if n == 1:
        return [0]

    fib = [0, 1]
    for i in range(2, n):
        fib.append(fib[i-1] + fib[i-2])
    return fib

# Example usage
result = fibonacci(10)
print(f"First 10 Fibonacci numbers: {result}")
\`\`\`

This generates the first N Fibonacci numbers using dynamic programming for efficient computation.`,

  api: `Here's how to create a Next.js API route:

\`\`\`typescript
import { NextResponse } from 'next/server';

interface RequestBody {
  name: string;
  email: string;
}

export async function POST(request: Request) {
  const body: RequestBody = await request.json();

  // Validate input
  if (!body.name || !body.email) {
    return NextResponse.json(
      { error: 'Name and email are required' },
      { status: 400 }
    );
  }

  // Process the data
  const user = {
    id: crypto.randomUUID(),
    ...body,
    createdAt: new Date().toISOString(),
  };

  return NextResponse.json({ user }, { status: 201 });
}
\`\`\`

This route handler validates the request body and returns a JSON response with proper status codes.`,

  sort: `Here's an efficient sorting implementation:

\`\`\`typescript
function quickSort<T>(arr: T[], compareFn?: (a: T, b: T) => number): T[] {
  if (arr.length <= 1) return arr;

  const compare = compareFn ?? ((a: T, b: T) => (a > b ? 1 : -1));
  const pivot = arr[Math.floor(arr.length / 2)];
  const left = arr.filter(x => compare(x, pivot) < 0);
  const middle = arr.filter(x => compare(x, pivot) === 0);
  const right = arr.filter(x => compare(x, pivot) > 0);

  return [...quickSort(left, compareFn), ...middle, ...quickSort(right, compareFn)];
}

// Usage
const numbers = [38, 27, 43, 3, 9, 82, 10];
console.log(quickSort(numbers)); // [3, 9, 10, 27, 38, 43, 82]
\`\`\`

This generic QuickSort implementation works with any comparable type and accepts an optional comparison function.`,

  css: `Here's a modern CSS layout technique:

\`\`\`css
/* Modern responsive grid layout */
.container {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 1.5rem;
  padding: 2rem;
}

.card {
  background: var(--card-bg, #1e293b);
  border-radius: 0.75rem;
  padding: 1.5rem;
  border: 1px solid var(--border, #334155);
  transition: transform 0.2s, box-shadow 0.2s;
}

.card:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
}
\`\`\`

This creates a responsive grid that automatically adjusts columns based on available width, with hover animations.`,

  sql: `Here's a SQL query example:

\`\`\`sql
-- Find top customers by total order value
SELECT
    c.id,
    c.name,
    c.email,
    COUNT(o.id) AS total_orders,
    SUM(o.amount) AS total_spent,
    AVG(o.amount) AS avg_order_value
FROM customers c
INNER JOIN orders o ON o.customer_id = c.id
WHERE o.created_at >= DATE_SUB(NOW(), INTERVAL 12 MONTH)
GROUP BY c.id, c.name, c.email
HAVING total_spent > 1000
ORDER BY total_spent DESC
LIMIT 20;
\`\`\`

This query joins customers with their orders from the last 12 months and ranks them by total spending.`,

  docker: `Here's a Dockerfile for a Node.js application:

\`\`\`dockerfile
# Multi-stage build for optimal image size
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:20-alpine AS runner
WORKDIR /app
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 appuser

COPY --from=builder /app/node_modules ./node_modules
COPY . .

USER appuser
EXPOSE 3000
ENV NODE_ENV=production

CMD ["node", "server.js"]
\`\`\`

This multi-stage build creates a minimal production image with a non-root user for security.`,

  git: `Here's a useful Git workflow:

\`\`\`bash
# Create a feature branch
git checkout -b feature/add-auth

# Make changes and stage them
git add -p  # Interactive staging

# Commit with a conventional message
git commit -m "feat: add user authentication with JWT"

# Rebase onto latest main before pushing
git fetch origin main
git rebase origin/main

# Push and create PR
git push -u origin feature/add-auth
\`\`\`

This workflow keeps your feature branch up-to-date with main using rebase for a clean linear history.`,
};

export const MOCK_USERS: Record<string, User> = {
  google: {
    id: "g-1",
    name: "Alex Developer",
    email: "alex@gmail.com",
    provider: "google",
  },
  apple: {
    id: "a-1",
    name: "Sam Coder",
    email: "sam@icloud.com",
    provider: "apple",
  },
  microsoft: {
    id: "m-1",
    name: "Jordan Engineer",
    email: "jordan@outlook.com",
    provider: "microsoft",
  },
};

export const KEYWORD_PRIORITIES = [
  "react",
  "python",
  "api",
  "sort",
  "css",
  "sql",
  "docker",
  "git",
] as const;
