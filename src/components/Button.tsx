export function Button({ children, onClick }: { children: React.ReactNode; onClick?: () => void }) {
  return (
    <button
      onClick={onClick}
      className="inline-flex items-center px-4 py-2 rounded bg-sky-600 text-white hover:bg-sky-700 transition"
    >
      {children}
    </button>
  );
}
