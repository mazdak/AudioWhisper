import Link from "next/link";

export function Hero() {
  return (
    <section className="relative py-20 px-4 sm:px-6 lg:px-8">
      <div className="absolute inset-0 bg-gradient-to-b from-blue-600/10 via-transparent to-transparent" />
      <div className="relative max-w-4xl mx-auto text-center">
        <div className="inline-flex items-center rounded-full border border-dark-700 bg-dark-800/50 px-4 py-1.5 text-sm text-dark-300 mb-6">
          Powered by Claude, GPT-4o, and Gemini Pro
        </div>
        <h1 className="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight text-white mb-6">
          Your AI-Powered{" "}
          <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-cyan-400">
            Coding Assistant
          </span>
        </h1>
        <p className="text-lg sm:text-xl text-dark-300 mb-10 max-w-2xl mx-auto leading-relaxed">
          Chat with multiple AI models, get syntax-highlighted code responses,
          and edit everything in an integrated Monaco editor. All in one place.
        </p>
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <Link
            href="/signup"
            className="w-full sm:w-auto inline-flex items-center justify-center rounded-xl bg-blue-600 px-8 py-3.5 text-base font-semibold text-white hover:bg-blue-700 transition-colors"
          >
            Get Started Free
          </Link>
          <Link
            href="/pricing"
            className="w-full sm:w-auto inline-flex items-center justify-center rounded-xl border border-dark-600 bg-dark-800 px-8 py-3.5 text-base font-semibold text-dark-200 hover:bg-dark-700 transition-colors"
          >
            See Pricing
          </Link>
        </div>
      </div>
    </section>
  );
}
