// Mobile-first column for the public portal (designed at 390 × 844).
export default function PortalLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <main className="mx-auto flex min-h-dvh w-full max-w-md flex-col px-5 py-8">
      {children}
    </main>
  );
}
