import { qrSvg } from "@/lib/qr";

/** Server-rendered QR code, ink on white, sized by its container. */
export async function QrCode({
  value,
  label,
}: {
  value: string;
  label: string;
}) {
  const svg = await qrSvg(value);
  return (
    <div
      role="img"
      aria-label={label}
      className="aspect-square w-full [&_path[fill]]:fill-surface [&_path[stroke]]:stroke-ink [&_svg]:block [&_svg]:size-full"
      dangerouslySetInnerHTML={{ __html: svg }}
    />
  );
}
