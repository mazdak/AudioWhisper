export function Footer() {
  return (
    <footer className="border-t border-dark-800 py-8 px-4 sm:px-6 lg:px-8">
      <div className="max-w-6xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
        <div className="flex items-center gap-2">
          <span className="text-lg font-bold text-white">CodeAssist AI</span>
        </div>
        <p className="text-sm text-dark-500">
          Built with Next.js, Tailwind CSS, and Monaco Editor
        </p>
      </div>
    </footer>
  );
}
