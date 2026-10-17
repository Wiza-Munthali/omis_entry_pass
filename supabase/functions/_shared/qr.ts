import QRCode from "qrcode";
import { colors } from "./tokens.ts";

/** QR code PNG (base64, no data: prefix) in the spec's ink on white, 560 px. */
export async function qrPngBase64(value: string): Promise<string> {
  const dataUrl = await QRCode.toDataURL(value, {
    errorCorrectionLevel: "M",
    margin: 2,
    width: 560,
    color: { dark: colors.ink, light: colors.surface },
  });
  return dataUrl.slice(dataUrl.indexOf(",") + 1);
}
