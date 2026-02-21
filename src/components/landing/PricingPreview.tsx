import Link from "next/link";

export function PricingPreview() {
  return (
    <section className="py-20 px-4 sm:px-6 lg:px-8 bg-dark-900/50">
      <div className="max-w-4xl mx-auto text-center">
        <h2 className="text-3xl font-bold text-white mb-4">
          Simple, transparent pricing
        </h2>
        <p className="text-dark-400 mb-12 max-w-xl mx-auto">
          Start free and upgrade when you need more. No hidden fees.
        </p>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8 max-w-2xl mx-auto">
          <div className="rounded-xl border border-dark-700 bg-dark-800 p-8">
            <h3 className="text-lg font-semibold text-white mb-2">Free</h3>
            <div className="text-3xl font-bold text-white mb-1">$0</div>
            <p className="text-sm text-dark-400 mb-6">Forever free</p>
            <ul className="text-sm text-dark-300 space-y-3 text-left">
              <li className="flex items-center gap-2">
                <svg className="w-4 h-4 text-green-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                10 messages per conversation
              </li>
              <li className="flex items-center gap-2">
                <svg className="w-4 h-4 text-green-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                3 conversations
              </li>
              <li className="flex items-center gap-2">
                <svg className="w-4 h-4 text-green-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                All AI models
              </li>
            </ul>
          </div>
          <div className="rounded-xl border-2 border-blue-500 bg-dark-800 p-8 relative">
            <div className="absolute -top-3 left-1/2 -translate-x-1/2 bg-blue-600 text-white text-xs font-semibold px-3 py-1 rounded-full">
              Popular
            </div>
            <h3 className="text-lg font-semibold text-white mb-2">Pro</h3>
            <div className="text-3xl font-bold text-white mb-1">$5</div>
            <p className="text-sm text-dark-400 mb-6">per month</p>
            <ul className="text-sm text-dark-300 space-y-3 text-left">
              <li className="flex items-center gap-2">
                <svg className="w-4 h-4 text-green-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                Unlimited messages
              </li>
              <li className="flex items-center gap-2">
                <svg className="w-4 h-4 text-green-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                Unlimited conversations
              </li>
              <li className="flex items-center gap-2">
                <svg className="w-4 h-4 text-green-400 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                  <path strokeLinecap="round" strokeLinejoin="round" d="M5 13l4 4L19 7" />
                </svg>
                Priority response speed
              </li>
            </ul>
          </div>
        </div>
        <Link
          href="/signup"
          className="inline-flex items-center justify-center mt-10 rounded-xl bg-blue-600 px-8 py-3 text-sm font-semibold text-white hover:bg-blue-700 transition-colors"
        >
          Get Started Free
        </Link>
      </div>
    </section>
  );
}
